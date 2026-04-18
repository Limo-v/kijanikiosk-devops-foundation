#!/usr/bin/env bash
set -euo pipefail

LOG_TS() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(LOG_TS)] [INFO] $*"; }
err() { echo "[$(LOG_TS)] [ERROR] $*" >&2; }

require_root_and_ubuntu() {
  [[ "${EUID}" -eq 0 ]] || { err "Run as root"; exit 1; }
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || { err "Ubuntu required"; exit 1; }
}

resolve_pin_version() {
  apt-cache policy "$1" | awk '/Candidate:/ {print $2; exit}'
}

provision_packages() {
  log "=== Phase 1: Packages and holds ==="
  apt-get update -y
  local nginx_ver nodejs_ver
  nginx_ver="${PINNED_NGINX_VERSION:-$(resolve_pin_version nginx)}"
  nodejs_ver="${PINNED_NODEJS_VERSION:-$(resolve_pin_version nodejs)}"
  apt-get install -y acl ufw "nginx=${nginx_ver}" "nodejs=${nodejs_ver}"
  apt-mark hold nginx nodejs
}

provision_identities() {
  log "=== Phase 2: Service identities ==="
  getent group kijanikiosk >/dev/null || groupadd kijanikiosk
  id kk-api >/dev/null 2>&1 || useradd --system --shell /usr/sbin/nologin --comment "Kijani API" kk-api
  id kk-payments >/dev/null 2>&1 || useradd --system --shell /usr/sbin/nologin --comment "Kijani payments" kk-payments
  id kk-logs >/dev/null 2>&1 || useradd --system --shell /usr/sbin/nologin --comment "Kijani logs" kk-logs
  usermod -aG kijanikiosk kk-api
  usermod -aG kijanikiosk kk-payments
  usermod -aG kijanikiosk kk-logs
}

provision_layout_and_acls() {
  log "=== Phase 3: Layout + ACLs ==="
  mkdir -p /opt/kijanikiosk/{api,payments,logs,config,shared/logs}
  [[ -f /opt/kijanikiosk/api/server.js ]] || echo "console.log('api placeholder')" >/opt/kijanikiosk/api/server.js
  [[ -f /opt/kijanikiosk/payments/processor.py ]] || echo "print('payments placeholder')" >/opt/kijanikiosk/payments/processor.py
  [[ -f /opt/kijanikiosk/config/payments-api.env ]] || echo "PAYMENTS_API_KEY=replace-me" >/opt/kijanikiosk/config/payments-api.env

  chown -R kk-api:kk-api /opt/kijanikiosk/api
  chown -R kk-payments:kk-payments /opt/kijanikiosk/payments
  chown -R kk-logs:kk-logs /opt/kijanikiosk/logs /opt/kijanikiosk/shared/logs
  chown root:kijanikiosk /opt/kijanikiosk/config

  chmod 750 /opt/kijanikiosk/api /opt/kijanikiosk/payments /opt/kijanikiosk/logs /opt/kijanikiosk/config
  chmod 640 /opt/kijanikiosk/config/*
  chmod 2770 /opt/kijanikiosk/shared/logs

  setfacl -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
  setfacl -m u:kk-payments:r-x /opt/kijanikiosk/shared/logs
  setfacl -d -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
  setfacl -d -m u:kk-payments:r-x /opt/kijanikiosk/shared/logs
}

provision_unit_kk_api() {
  log "=== Phase 4: kk-api systemd unit ==="
  cat >/etc/systemd/system/kk-api.service <<'EOF'
[Unit]
Description=KijaniKiosk API
After=network.target

[Service]
Type=simple
User=kk-api
Group=kk-api
WorkingDirectory=/opt/kijanikiosk/api
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env
ExecStart=/usr/bin/node /opt/kijanikiosk/api/server.js
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true
SystemCallFilter=@system-service
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
ReadWritePaths=/opt/kijanikiosk/shared/logs

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable kk-api.service
}

provision_firewall() {
  log "=== Phase 5: Firewall intent ==="
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing

  # Critical ordering: allow SSH before enable to avoid lockout.
  ufw allow 22/tcp comment 'Allow SSH management'
  ufw allow 80/tcp comment 'Allow HTTP ingress'

  # Do not add deny 3001 here during provisioning for Thursday remediation context.
  # That deny rule was the injected incident fault and must not be reintroduced.

  ufw --force enable
}

provision_logrotate() {
  log "=== Phase 6: Logrotate policy (daily, 14 days) ==="
  cat >/etc/logrotate.d/kijanikiosk <<'EOF'
/opt/kijanikiosk/shared/logs/*.log {
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

  # Validate syntax/plan without applying destructive changes.
  logrotate --debug /etc/logrotate.d/kijanikiosk >/dev/null
}

verify() {
  log "=== Phase 7: Verification ==="
  local failures=0
  systemctl is-enabled kk-api.service >/dev/null 2>&1 || failures=$((failures+1))
  apt-mark showhold | grep -q '^nginx$' || failures=$((failures+1))
  apt-mark showhold | grep -q '^nodejs$' || failures=$((failures+1))
  ufw status | grep -q '22/tcp' || failures=$((failures+1))
  ufw status | grep -q '80/tcp' || failures=$((failures+1))
  [[ -f /etc/logrotate.d/kijanikiosk ]] || failures=$((failures+1))

  if [[ "$failures" -gt 0 ]]; then
    err "Verification failed with ${failures} check(s)"
    exit 1
  fi
  log "Verification passed"
}

main() {
  require_root_and_ubuntu
  provision_packages
  provision_identities
  provision_layout_and_acls
  provision_unit_kk_api
  provision_firewall
  provision_logrotate
  verify
}

main "$@"
