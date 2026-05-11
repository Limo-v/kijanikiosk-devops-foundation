#!/usr/bin/env bash
set -Eeuo pipefail

# Expected dirty conditions found in the pre-provisioning audit:
# - service users and the shared group may be missing or partially created
# - /opt/kijanikiosk may not exist yet or may have drifted permissions
# - UFW may be inactive or reflect historical edits instead of intended policy
# - package holds may be absent or overridden
# - systemd units may be missing or only partially hardened
# - journal storage may already be consuming significant disk space

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_FILE="$SCRIPT_DIR/pre-provisioning-audit.txt"
BASE_DIR="/opt/kijanikiosk"
API_DIR="$BASE_DIR/api"
PAYMENTS_DIR="$BASE_DIR/payments"
LOGS_DIR="$BASE_DIR/logs"
CONFIG_DIR="$BASE_DIR/config"
SCRIPTS_DIR="$BASE_DIR/scripts"
SHARED_LOG_DIR="$BASE_DIR/shared/logs"
HEALTH_DIR="$BASE_DIR/health"
MONITORING_CIDR="${MONITORING_CIDR:-10.0.1.0/24}"
API_PORT="3000"
PAYMENTS_PORT="3001"
LOGS_PORT="5000"

LOG_TS() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(LOG_TS)] [INFO] $*"; }
success() { echo "[$(LOG_TS)] [PASS] $*"; }
warn() { echo "[$(LOG_TS)] [WARN] $*"; }
err() { echo "[$(LOG_TS)] [FAIL] $*" >&2; }

on_error() {
  err "Provisioning stopped at line $1"
}
trap 'on_error $LINENO' ERR

require_root_and_ubuntu() {
  [[ "${EUID}" -eq 0 ]] || { err "Run this script as root"; exit 1; }
  [[ -f /etc/os-release ]] || { err "Missing /etc/os-release"; exit 1; }
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || { err "This script supports Ubuntu only"; exit 1; }
}

write_audit() {
  log "=== Phase 1: Pre-Provisioning Audit Capture ==="
  mkdir -p "$SCRIPT_DIR"
  {
    echo "# Pre-Provisioning Audit"
    echo "# Generated: $(date -Is)"
    echo
    echo "## Raw command output"
    for cmd in \
      "getent passwd kk-api kk-payments kk-logs" \
      "getent group kijanikiosk" \
      "ls -la $BASE_DIR/" \
      "getfacl $SHARED_LOG_DIR/" \
      "getfacl $CONFIG_DIR/" \
      "ufw status numbered" \
      "apt-mark showhold" \
      "systemctl list-unit-files | grep kk-" \
      "systemd-analyze security kk-api.service | head -5" \
      "du -sh $SHARED_LOG_DIR/" \
      "journalctl --disk-usage"; do
      echo "$ $cmd"
      bash -lc "$cmd" 2>&1 || true
      echo
    done
    echo "## Interpretation comments"
    echo "- service users may already exist: handled in Phase 2 with idempotent checks"
    echo "- shared directories or ACLs may be missing or drifted: reconciled in Phase 3"
    echo "- firewall rules may reflect history instead of intent: reset in Phase 6"
    echo "- package holds may be absent: re-applied in Phase 2"
    echo "- systemd units may be missing or partially hardened: rewritten in Phase 5"
    echo "- journal storage may already be large: capped in Phase 7"
  } > "$AUDIT_FILE"
  log "Wrote audit output: $AUDIT_FILE"
}

resolve_candidate_version() {
  local pkg="$1"
  apt-cache policy "$pkg" | awk '/Candidate:/ {print $2; exit}'
}

install_packages() {
  log "=== Phase 2: Package Pinning and Drift Handling ==="
  apt-get update -y

  local nginx_ver nodejs_ver installed_nginx installed_nodejs
  nginx_ver="${PINNED_NGINX_VERSION:-$(resolve_candidate_version nginx)}"
  nodejs_ver="${PINNED_NODEJS_VERSION:-$(resolve_candidate_version nodejs)}"

  [[ -n "$nginx_ver" && -n "$nodejs_ver" ]] || { err "Could not resolve pinned package versions"; exit 1; }

  installed_nginx="$(dpkg-query -W -f='${Version}' nginx 2>/dev/null || true)"
  installed_nodejs="$(dpkg-query -W -f='${Version}' nodejs 2>/dev/null || true)"

  if [[ -n "$installed_nginx" && "$installed_nginx" != "$nginx_ver" ]]; then
    warn "nginx drift detected: installed=$installed_nginx target=$nginx_ver; converging to target"
  fi
  if [[ -n "$installed_nodejs" && "$installed_nodejs" != "$nodejs_ver" ]]; then
    warn "nodejs drift detected: installed=$installed_nodejs target=$nodejs_ver; converging to target"
  fi

  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    acl ufw logrotate curl ca-certificates netcat-openbsd \
    "nginx=${nginx_ver}" "nodejs=${nodejs_ver}"

  apt-mark hold nginx nodejs >/dev/null
  success "Pinned packages installed and held"
}

ensure_group() {
  local group="$1"
  if getent group "$group" >/dev/null 2>&1; then
    log "Already exists: group $group"
  else
    groupadd "$group"
    log "Created group: $group"
  fi
}

ensure_service_user() {
  local user="$1"
  local comment="$2"

  if id "$user" >/dev/null 2>&1; then
    log "Already exists: $user"
  else
    useradd --system --user-group --no-create-home --shell /usr/sbin/nologin --comment "$comment" "$user"
    log "Created service user: $user"
  fi
}

provision_identities() {
  log "=== Phase 3: Service Accounts and Groups ==="
  local ops_user
  ops_user="${SUDO_USER:-${USER:-root}}"

  ensure_group kijanikiosk
  ensure_service_user kk-api "KijaniKiosk API service"
  ensure_service_user kk-payments "KijaniKiosk payments service"
  ensure_service_user kk-logs "KijaniKiosk log service"

  usermod -aG kijanikiosk kk-api
  usermod -aG kijanikiosk kk-payments
  usermod -aG kijanikiosk kk-logs
  if id "$ops_user" >/dev/null 2>&1; then
    usermod -aG kijanikiosk "$ops_user"
  fi
}

write_placeholder_workloads() {
  cat > "$API_DIR/server.js" <<'EOF'
const http = require('http');
const port = parseInt(process.env.SERVICE_PORT || '3000', 10);
http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'application/json'});
  res.end(JSON.stringify({service: 'kk-api', status: 'ok'}));
}).listen(port, '127.0.0.1');
EOF

  cat > "$SCRIPTS_DIR/run-payments.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
trap ':' HUP
exec /usr/bin/python3 -m http.server "${SERVICE_PORT:-3001}" --bind 127.0.0.1 --directory /opt/kijanikiosk/payments
EOF

  cat > "$SCRIPTS_DIR/run-logs.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
trap ':' HUP
mkdir -p /opt/kijanikiosk/shared/logs
while true; do
  printf '%s kk-logs heartbeat\n' "$(date -Is)" >> /opt/kijanikiosk/shared/logs/logs.log
  sleep 30
done
EOF

  chmod 0750 "$SCRIPTS_DIR/run-payments.sh" "$SCRIPTS_DIR/run-logs.sh"
}

provision_layout_and_acls() {
  log "=== Phase 4: Directory Ownership, Modes, and ACLs ==="
  local ops_user
  ops_user="${SUDO_USER:-${USER:-root}}"

  mkdir -p "$API_DIR" "$PAYMENTS_DIR" "$LOGS_DIR" "$CONFIG_DIR" "$SCRIPTS_DIR" "$SHARED_LOG_DIR" "$HEALTH_DIR"
  touch "$SHARED_LOG_DIR/api.log" "$SHARED_LOG_DIR/payments.log" "$SHARED_LOG_DIR/logs.log"

  write_placeholder_workloads

  cat > "$CONFIG_DIR/db.env" <<EOF
SERVICE_NAME=kk-api
SERVICE_PORT=$API_PORT
APP_ENV=production
EOF

  cat > "$CONFIG_DIR/payments-api.env" <<EOF
SERVICE_NAME=kk-payments
SERVICE_PORT=$PAYMENTS_PORT
APP_ENV=production
PAYMENTS_API_KEY=replace-me
EOF

  cat > "$CONFIG_DIR/logs.env" <<EOF
SERVICE_NAME=kk-logs
SERVICE_PORT=$LOGS_PORT
APP_ENV=production
EOF

  chown -R kk-api:kk-api "$API_DIR"
  chown -R kk-payments:kk-payments "$PAYMENTS_DIR"
  chown -R kk-logs:kk-logs "$LOGS_DIR"
  chown -R root:kijanikiosk "$CONFIG_DIR"
  chown -R root:root "$SCRIPTS_DIR"
  chown -R kk-logs:kk-logs "$SHARED_LOG_DIR"
  chown -R kk-logs:kijanikiosk "$HEALTH_DIR"

  chmod 0750 "$API_DIR" "$PAYMENTS_DIR" "$LOGS_DIR" "$CONFIG_DIR" "$HEALTH_DIR"
  chmod 0755 "$SCRIPTS_DIR"
  chmod 0640 "$CONFIG_DIR"/*
  chmod 2770 "$SHARED_LOG_DIR"
  chmod 0640 "$SHARED_LOG_DIR"/*.log

  setfacl -bR "$SHARED_LOG_DIR" || true
  setfacl -m u:kk-api:rwx "$SHARED_LOG_DIR"
  setfacl -m u:kk-payments:r-x "$SHARED_LOG_DIR"
  setfacl -m u:kk-logs:rwx "$SHARED_LOG_DIR"
  setfacl -m g:kijanikiosk:r-x "$SHARED_LOG_DIR"
  setfacl -m m::rwx "$SHARED_LOG_DIR"
  setfacl -d -m u:kk-api:rwx "$SHARED_LOG_DIR"
  setfacl -d -m u:kk-payments:r-- "$SHARED_LOG_DIR"
  setfacl -d -m u:kk-logs:rwx "$SHARED_LOG_DIR"
  setfacl -d -m g:kijanikiosk:r-- "$SHARED_LOG_DIR"
  setfacl -d -m m::rwx "$SHARED_LOG_DIR"

  if id "$ops_user" >/dev/null 2>&1; then
    setfacl -m "u:${ops_user}:r-x" "$CONFIG_DIR" || true
    setfacl -m "u:${ops_user}:r-x" "$HEALTH_DIR" || true
    for cfg in "$CONFIG_DIR"/*; do
      [[ -f "$cfg" ]] && setfacl -m "u:${ops_user}:r--" "$cfg" || true
    done
  fi

  success "Filesystem layout and ACL model converged"
}

write_systemd_units() {
  log "=== Phase 5: Hardened systemd Units (All Services) ==="

  cat > /etc/systemd/system/kk-api.service <<EOF
[Unit]
Description=KijaniKiosk API Service
After=network.target

[Service]
Type=simple
User=kk-api
Group=kk-api
WorkingDirectory=$API_DIR
EnvironmentFile=$CONFIG_DIR/db.env
ExecStart=/usr/bin/node $API_DIR/server.js
Restart=on-failure
RestartSec=5
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
ReadWritePaths=$SHARED_LOG_DIR $HEALTH_DIR

[Install]
WantedBy=multi-user.target
EOF

  cat > /etc/systemd/system/kk-payments.service <<EOF
[Unit]
Description=KijaniKiosk Payments Service
After=network.target kk-api.service
Wants=kk-api.service

[Service]
Type=simple
User=kk-payments
Group=kk-payments
WorkingDirectory=$PAYMENTS_DIR
EnvironmentFile=$CONFIG_DIR/payments-api.env
ExecStart=$SCRIPTS_DIR/run-payments.sh
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
CapabilityBoundingSet=
AmbientCapabilities=
UMask=0077
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectControlGroups=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectClock=true
ProtectHostname=true
PrivateDevices=true
RestrictSUIDSGID=true
RestrictNamespaces=true
RestrictRealtime=true
LockPersonality=true
MemoryDenyWriteExecute=true
SystemCallArchitectures=native
SystemCallFilter=@system-service
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
IPAddressDeny=any
IPAddressAllow=127.0.0.0/8
IPAddressAllow=::1/128
RemoveIPC=true
ProtectProc=invisible
ProcSubset=pid
ReadWritePaths=$SHARED_LOG_DIR $HEALTH_DIR

[Install]
WantedBy=multi-user.target
EOF

  cat > /etc/systemd/system/kk-logs.service <<EOF
[Unit]
Description=KijaniKiosk Logs Service
After=network.target

[Service]
Type=simple
User=kk-logs
Group=kk-logs
WorkingDirectory=$LOGS_DIR
EnvironmentFile=$CONFIG_DIR/logs.env
ExecStart=$SCRIPTS_DIR/run-logs.sh
Restart=on-failure
RestartSec=5
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
ReadWritePaths=$SHARED_LOG_DIR $HEALTH_DIR

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  runuser -u kk-payments -- cat "$CONFIG_DIR/payments-api.env" >/dev/null

  systemctl enable --now kk-api.service
  systemctl enable --now kk-payments.service
  systemctl enable --now kk-logs.service

  success "All three hardened services are enabled"
}

configure_firewall() {
  log "=== Phase 6: Firewall Intent Reset ==="
  ufw --force reset >/dev/null
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null

  ufw allow 22/tcp comment 'Allow SSH management' >/dev/null
  ufw allow 80/tcp comment 'Allow HTTP web access' >/dev/null
  ufw allow from 127.0.0.1 to any port "$PAYMENTS_PORT" proto tcp comment 'Allow local reverse proxy to payments' >/dev/null
  ufw allow from "$MONITORING_CIDR" to any port "$PAYMENTS_PORT" proto tcp comment 'Allow monitoring subnet to payments health' >/dev/null
  ufw deny "$PAYMENTS_PORT"/tcp comment 'Block external direct access to payments' >/dev/null

  ufw --force enable >/dev/null
  success "Firewall policy reset and reapplied"
}

configure_logging() {
  log "=== Phase 7: Journal Persistence and Log Rotation ==="
  mkdir -p /etc/systemd/journald.conf.d /var/log/journal

  cat > /etc/systemd/journald.conf.d/kijanikiosk.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
RuntimeMaxUse=200M
EOF

  cat > /etc/logrotate.d/kijanikiosk <<EOF
$SHARED_LOG_DIR/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    create 0640 kk-logs kijanikiosk
    sharedscripts
    postrotate
        /bin/systemctl kill -s HUP kk-logs.service >/dev/null 2>&1 || true
    endscript
}
EOF

  systemctl restart systemd-journald
  logrotate --debug /etc/logrotate.d/kijanikiosk >/dev/null
  success "Persistent journald and logrotate configured"
}

write_health_check() {
  log "=== Phase 8: Monitoring Health Checks ==="
  local api_status payments_status logs_status

  api_status=$(timeout 2 bash -c "echo >/dev/tcp/127.0.0.1/$API_PORT" 2>/dev/null && echo '"ok"' || echo '"down"')
  payments_status=$(timeout 2 bash -c "echo >/dev/tcp/127.0.0.1/$PAYMENTS_PORT" 2>/dev/null && echo '"ok"' || echo '"down"')
  logs_status=$(timeout 2 bash -c "echo >/dev/tcp/127.0.0.1/$LOGS_PORT" 2>/dev/null && echo '"ok"' || echo '"down"')

  mkdir -p "$HEALTH_DIR"
  printf '{"timestamp":"%s","kk-api":%s,"kk-payments":%s,"kk-logs":%s}\n' \
    "$(date -Is)" "$api_status" "$payments_status" "$logs_status" \
    > "$HEALTH_DIR/last-provision.json"

  chown kk-logs:kijanikiosk "$HEALTH_DIR/last-provision.json"
  chmod 640 "$HEALTH_DIR/last-provision.json"

  success "Wrote health output: $HEALTH_DIR/last-provision.json"
}

final_verify() {
  log "=== Phase 9: Final Verification ==="
  local failed=0
  local ufw_status
  ufw_status="$(ufw status numbered 2>/dev/null || true)"

  check() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
      success "$description"
    else
      err "$description"
      failed=$((failed + 1))
    fi
  }

  check "kk-api user exists" id kk-api
  check "kk-payments user exists" id kk-payments
  check "kk-logs user exists" id kk-logs
  check "shared log ACL grants kk-api write access" grep -q 'user:kk-api:rwx' <(getfacl "$SHARED_LOG_DIR")
  check "shared log ACL grants kk-payments read access" grep -q 'user:kk-payments:r-x' <(getfacl "$SHARED_LOG_DIR")
  check "kk-api service is active" systemctl is-active --quiet kk-api.service
  check "kk-payments service is active" systemctl is-active --quiet kk-payments.service
  check "kk-logs service is active" systemctl is-active --quiet kk-logs.service
  check "nginx hold is present" grep -q '^nginx$' <(apt-mark showhold)
  check "nodejs hold is present" grep -q '^nodejs$' <(apt-mark showhold)
  check "SSH firewall rule exists" grep -q '22/tcp' <(printf '%s
' "$ufw_status")
  check "HTTP firewall rule exists" grep -q '80/tcp' <(printf '%s
' "$ufw_status")
  check "payments external deny exists" grep -q "$PAYMENTS_PORT/tcp.*DENY" <(printf '%s
' "$ufw_status")
  check "health JSON exists" test -f "$HEALTH_DIR/last-provision.json"
  check "logrotate debug passes" logrotate --debug /etc/logrotate.d/kijanikiosk
  check "payments loopback port responds" curl -fsS "http://127.0.0.1:$PAYMENTS_PORT/"

  logrotate --force /etc/logrotate.d/kijanikiosk >/dev/null 2>&1 || true
  if runuser -u kk-api -- touch "$SHARED_LOG_DIR/test-write.tmp"; then
    success "kk-api can write after logrotate"
  else
    err "kk-api cannot write after logrotate"
    failed=$((failed + 1))
  fi

  if [[ "$failed" -gt 0 ]]; then
    err "Verification failed with $failed check(s)"
    exit 1
  fi

  success "All verification checks passed"
}

main() {
  require_root_and_ubuntu
  write_audit
  install_packages
  provision_identities
  provision_layout_and_acls
  write_systemd_units
  configure_firewall
  configure_logging
  write_health_check
  final_verify
  log "Provisioning complete"
}

main "$@"
