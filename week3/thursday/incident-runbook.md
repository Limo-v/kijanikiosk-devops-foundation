# Thursday Incident Runbook

## Incident Summary
- Service impact: intermittent `502` responses on payments endpoint.
- Affected layer(s): performance, service process ownership on port `3001`, and firewall policy.
- Investigation start time: `YYYY-MM-DD HH:MM:SS` (replace with actual).
- Constraint: treat host as black box, validate with evidence before remediation.

## Phase 1: Performance Findings

### Commands executed
- `top`
- `vmstat 2 5`
- `iostat -xh 2 5`
- `df -h`
- `du -sh /opt/kijanikiosk/shared/logs/`
- `sudo iotop -o`

### Evidence captured
- PID/user/state with highest pressure: `<fill>`
- `wa` (I/O wait) trend from `vmstat`: `<fill>`
- `b` column trend: `<fill>`
- `%util` and `await` from `iostat`: `<fill>`
- Log directory size: `<fill>`

### Initial hypothesis (timestamped)
`[YYYY-MM-DD HH:MM:SS]` High write I/O and elevated wait suggest degraded request handling due to oversized unrotated logs saturating disk.

## Phase 2: Log Findings

### Commands executed
- `journalctl -u kk-payments -p err --since "60 minutes ago" -r -n 50`
- `sudo tail -50 /var/log/nginx/error.log`
- `sudo grep -i "ata\|scsi\|ioerr\|I/O error" /var/log/kern.log | tail -20`
- `cat /etc/logrotate.d/kijanikiosk 2>/dev/null || echo "no logrotate config found"`
- `du -sh /opt/kijanikiosk/shared/logs/*`

### Evidence captured
- Payments service errors: `<fill>`
- Nginx upstream failures to `3001`: `<fill>`
- Kernel disk-related messages: `<fill>`
- Logrotate cadence/retention: `<fill>`

### Revised hypothesis (timestamped)
`[YYYY-MM-DD HH:MM:SS]` Incident is multi-causal: disk pressure from log accumulation plus traffic instability on port `3001` likely due to process/network misconfiguration.

## Phase 3: Network Findings

### Commands executed
- `ss -tlnp`
- `ps -p <PID> -o pid,ppid,user,lstart,cmd`
- `curl -sv --max-time 3 http://localhost:3001/`
- `curl -sv --max-time 3 http://<external-ip>:3001/`
- `sudo ufw status numbered`
- `ip addr show`

### Evidence captured
- Port `3001` listeners: `<fill>`
- Suspicious process details: `<fill>`
- Localhost `3001` response body: `<fill>`
- External `3001` reachability: `<fill>`
- UFW deny rule anomaly: `<fill>`

## Root Causes
1. Disk I/O saturation from oversized, unrotated logs under shared log path.
2. Rogue process bound to `127.0.0.1:3001`, creating conflict with intended payments listener behavior.
3. Erroneous firewall deny rule for `3001/tcp`, blocking intended health/network path.

## Phase 4: Remediation Steps (Exact Order)

### Fix 1: Port conflict
1. Identify rogue PID from `ss -tlnp` and `ps`.
2. Check state with `ps -p <PID> -o stat`.
3. If state is `S` or `R`, use `kill -TERM <PID>` first, wait 5-10 seconds.
4. Escalate to `kill -KILL <PID>` only if process does not exit.
5. Verify single expected listener on `3001`.

Signal decision used:
- Chosen signal: `<TERM/KILL>`
- Reason: `<state-based rationale>`

### Fix 2: Firewall rule
1. Remove erroneous deny rule from `ufw status numbered`.
2. Verify with `sudo ufw status verbose`.
3. Update provisioning script comment to explicitly prevent reintroducing deny `3001` rule.

### Fix 3: Logs and rotation
1. Capture baseline disk usage: `df -h /` and `du -sh /opt/kijanikiosk/shared/logs/`.
2. Force rotate: `sudo logrotate --force /etc/logrotate.d/kijanikiosk`.
3. Re-check disk usage.
4. Ensure `daily` rotation and `rotate 14` retention in logrotate policy.
5. Update provisioning script to manage this idempotently.

## Fix-Order Rationale
Port conflict is fixed first to stop immediate wrong-responder behavior on critical service port. Firewall is second to restore intended traffic visibility. Log rotation is third to resolve sustained I/O degradation. If firewall is fixed before port conflict, health checks can report a false positive while requests still hit rogue behavior, causing resumed routing to a degraded node.

## Phase 5: Post-Remediation Verification

### Commands
- `vmstat 2 5`
- `df -h /`
- `du -sh /opt/kijanikiosk/shared/logs/`
- `ss -tlnp | grep 3001`
- `sudo ufw status numbered`
- `curl -s http://localhost:3001/ | head -3`
- `journalctl -u kk-payments -p err --since "5 minutes ago"`

### Expected verification outcomes
- `wa < 10%` and blocked processes return to normal.
- Shared log size reduced after rotation.
- Exactly one listener on `3001`.
- No deny rule for `3001` remains.
- Payments endpoint responds as intended (not rogue 500 payload).
- No new payment errors in recent journal window.

## Prevention Updates
- Provisioning script includes explicit logrotate management (`daily`, `rotate 14`).
- Firewall phase documents and avoids incident-introducing deny rule.
- Operational runbook now codifies evidence-first triage order (performance -> logs -> network).
