# kk-payments Hardening Iteration Log

This file is written as my iterative notes. Replace placeholder score lines with your real VM outputs.

## Baseline
- Initial score before extra hardening: `<fill from systemd-analyze security kk-payments.service>`

## Changes I added (in order)

1. Added `NoNewPrivileges=true`
- Score after change: `<fill>`
- Reason: stop easy privilege gain paths.

2. Added `ProtectSystem=strict` + controlled write path
- Score after change: `<fill>`
- Reason: make filesystem mostly read-only for service process.

3. Added `MemoryDenyWriteExecute=true`
- Score after change: `<fill>`
- Reason: reduce executable payload style memory attacks.

4. Added `SystemCallFilter=@system-service`
- Score after change: `<fill>`
- Reason: reduce kernel syscall surface.

5. Added `ProtectProc=invisible` and `ProcSubset=pid`
- Score after change: `<fill>`
- Reason: reduce process visibility from compromised context.

6. Added `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6`
- Score after change: `<fill>`
- Reason: limit socket families to what service actually needs.

## Rejected directives (investigated but not applied)

1. `PrivateNetwork=true`
- Why rejected: breaks normal connectivity expectations for payments traffic and health checks in this setup.

2. `CapabilityBoundingSet=` fully empty
- Why rejected: looked attractive, but in this environment I preferred staged hardening while verifying startup behavior to avoid accidental runtime break.

## Final target
- Required final score: below 2.5
- Final measured score: `<fill>`
- Service startup check: `<pass/fail + notes>`

## Final kk-payments unit file (from provisioning script)

```ini
[Unit]
Description=KijaniKiosk Payments Service
After=network.target kk-api.service
Wants=kk-api.service

[Service]
Type=simple
User=kk-payments
Group=kk-payments
WorkingDirectory=/opt/kijanikiosk/payments
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env
ExecStart=/usr/bin/bash -c 'while true; do sleep 300; done'
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectControlGroups=true
ProtectKernelTunables=true
ProtectKernelModules=true
PrivateDevices=true
RestrictSUIDSGID=true
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
SystemCallArchitectures=native
SystemCallFilter=@system-service
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RemoveIPC=true
ProtectProc=invisible
ProcSubset=pid
ReadWritePaths=/opt/kijanikiosk/shared/logs

[Install]
WantedBy=multi-user.target
```
