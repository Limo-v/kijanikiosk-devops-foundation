#!/usr/bin/env bash
set -euo pipefail

LOG_TS() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(LOG_TS)] [INFO] $*"; }
warn() { echo "[$(LOG_TS)] [WARN] $*"; }
err() { echo "[$(LOG_TS)] [ERROR] $*" >&2; }

require_root_and_ubuntu() {
  [[ "${EUID}" -eq 0 ]] || { err "Run as root"; exit 1; }
  [[ -f /etc/os-release ]] || { err "Missing /etc/os-release"; exit 1; }
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || { err "Only Ubuntu is supported"; exit 1; }
}

resolve_pin_version() {
  local pkg="$1"
  apt-cache policy "$pkg" | awk '/Candidate:/ {print $2; exit}'
}

install_pinned_packages() {
  log "=== Phase 1: Pinned package install ==="
  apt-get update -y

  local nginx_ver nodejs_ver
  nginx_ver="${PINNED_NGINX_VERSION:-$(resolve_pin_version nginx)}"
  nodejs_ver="${PINNED_NODEJS_VERSION:-$(resolve_pin_version nodejs)}"

  [[ -n "$nginx_ver" && -n "$nodejs_ver" ]] || { err "Failed to resolve package versions"; exit 1; }
  log "Pinning nginx=${nginx_ver} nodejs=${nodejs_ver}"

  apt-get install -y acl ufw "nginx=${nginx_ver}" "nodejs=${nodejs_ver}"
  apt-mark hold nginx nodejs
}

ensure_group() {
  local group="$1"
  if getent group "$group" >/dev/null; then
    log "Already exists: group ${group}"
  else
    groupadd "$group"
    log "Created group: ${group}"
  fi
}

ensure_system_user() {
  local user="$1"
  local comment="$2"

  if id "$user" >/dev/null 2>&1; then
    log "Already exists: ${user}"
  else
    useradd --system --create-home false --shell /usr/sbin/nologin --comment "$comment" "$user"
    log "Created system user: ${user}"
  fi
}

provision_identities() {
  log "=== Phase 2: Service identities ==="
  local ops_user
  ops_user="${SUDO_USER:-${USER:-root}}"

  ensure_group kijanikiosk
  ensure_system_user kk-api "KijaniKiosk API service"
  ensure_system_user kk-payments "KijaniKiosk payments service"
  ensure_system_user kk-logs "KijaniKiosk logs service"

  usermod -aG kijanikiosk kk-api
  usermod -aG kijanikiosk kk-payments
  usermod -aG kijanikiosk kk-logs

  if id "$ops_user" >/dev/null 2>&1; then
    usermod -aG kijanikiosk "$ops_user"
  else
    warn "Ops user not found: ${ops_user}"
  fi
}

provision_layout_and_acls() {
  log "=== Phase 3: Filesystem + ACL model ==="

  mkdir -p /opt/kijanikiosk/{api,payments,logs,config,scripts,shared/logs}

  [[ -f /opt/kijanikiosk/api/server.js ]] || echo "console.log('kk-api placeholder');" >/opt/kijanikiosk/api/server.js
  [[ -f /opt/kijanikiosk/payments/processor.py ]] || echo "print('kk-payments placeholder')" >/opt/kijanikiosk/payments/processor.py
  [[ -f /opt/kijanikiosk/config/db.env ]] || cat >/opt/kijanikiosk/config/db.env <<'EOF'
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=kijanikiosk
DB_USER=kk_app
DB_PASSWORD=change-me
EOF

  chown -R kk-api:kk-api /opt/kijanikiosk/api
  chown -R kk-payments:kk-payments /opt/kijanikiosk/payments
  chown -R kk-logs:kk-logs /opt/kijanikiosk/logs
  chown root:kijanikiosk /opt/kijanikiosk/config
  chown kk-logs:kk-logs /opt/kijanikiosk/shared/logs

  chmod 750 /opt/kijanikiosk/api /opt/kijanikiosk/payments /opt/kijanikiosk/logs /opt/kijanikiosk/config
  chmod 640 /opt/kijanikiosk/config/*
  chmod 2770 /opt/kijanikiosk/shared/logs

  local ops_user
  ops_user="${SUDO_USER:-${USER:-root}}"

  setfacl -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
  setfacl -m u:kk-payments:r-x /opt/kijanikiosk/shared/logs
  id "$ops_user" >/dev/null 2>&1 && setfacl -m "u:${ops_user}:r-x" /opt/kijanikiosk/shared/logs || true

  setfacl -d -m u:kk-api:rwx /opt/kijanikiosk/shared/logs
  setfacl -d -m u:kk-payments:r-x /opt/kijanikiosk/shared/logs
  id "$ops_user" >/dev/null 2>&1 && setfacl -d -m "u:${ops_user}:r-x" /opt/kijanikiosk/shared/logs || true

  id "$ops_user" >/dev/null 2>&1 && setfacl -m "u:${ops_user}:r-x" /opt/kijanikiosk/config || true
  for cfg in /opt/kijanikiosk/config/*; do
    [[ -f "$cfg" ]] && id "$ops_user" >/dev/null 2>&1 && setfacl -m "u:${ops_user}:r--" "$cfg" || true
  done
}

provision_service_unit() {
  log "=== Phase 4: systemd hardened service ==="

  cat >/etc/systemd/system/kk-api.service <<'EOF'
[Unit]
Description=KijaniKiosk API Service
After=network.target

[Service]
Type=simple
User=kk-api
Group=kk-api
WorkingDirectory=/opt/kijanikiosk/api
EnvironmentFile=/opt/kijanikiosk/config/db.env
ExecStart=/usr/bin/node /opt/kijanikiosk/api/server.js
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictSUIDSGID=true
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
SystemCallArchitectures=native
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
  log "=== Phase 5: Firewall configuration ==="
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing

  # Always allow SSH before enabling ufw to avoid remote lockout.
  ufw allow 22/tcp comment 'Allow SSH management'
  ufw allow 80/tcp comment 'Allow HTTP ingress'

  ufw --force enable
  ufw status verbose
}

verify_all() {
  log "=== Phase 6: Verification ==="
  local failed=0

  id kk-api >/dev/null 2>&1 || { err "FAIL: kk-api missing"; failed=$((failed+1)); }
  id kk-payments >/dev/null 2>&1 || { err "FAIL: kk-payments missing"; failed=$((failed+1)); }
  id kk-logs >/dev/null 2>&1 || { err "FAIL: kk-logs missing"; failed=$((failed+1)); }

  [[ "$(stat -c '%a' /opt/kijanikiosk/api)" == "750" ]] || { err "FAIL: /api mode"; failed=$((failed+1)); }
  [[ "$(stat -c '%a' /opt/kijanikiosk/payments)" == "750" ]] || { err "FAIL: /payments mode"; failed=$((failed+1)); }
  [[ "$(stat -c '%a' /opt/kijanikiosk/logs)" == "750" ]] || { err "FAIL: /logs mode"; failed=$((failed+1)); }
  [[ "$(stat -c '%a' /opt/kijanikiosk/config)" == "750" ]] || { err "FAIL: /config mode"; failed=$((failed+1)); }

  getfacl /opt/kijanikiosk/shared/logs | grep -q "user:kk-api:rwx" || { err "FAIL: kk-api ACL missing"; failed=$((failed+1)); }
  getfacl /opt/kijanikiosk/shared/logs | grep -q "user:kk-payments:r-x" || { err "FAIL: kk-payments ACL missing"; failed=$((failed+1)); }

  systemctl is-enabled kk-api.service >/dev/null 2>&1 || { err "FAIL: kk-api not enabled"; failed=$((failed+1)); }

  apt-mark showhold | grep -q '^nginx$' || { err "FAIL: nginx not held"; failed=$((failed+1)); }
  apt-mark showhold | grep -q '^nodejs$' || { err "FAIL: nodejs not held"; failed=$((failed+1)); }

  local ufw_status
  ufw_status="$(ufw status)"
  echo "$ufw_status" | grep -q "22/tcp" || { err "FAIL: SSH rule missing"; failed=$((failed+1)); }
  echo "$ufw_status" | grep -q "80/tcp" || { err "FAIL: HTTP rule missing"; failed=$((failed+1)); }

  if [[ "$failed" -gt 0 ]]; then
    err "Verification failed with ${failed} check(s)"
    exit 1
  fi

  log "All verification checks passed"
}

main() {
  require_root_and_ubuntu
  install_pinned_packages
  provision_identities
  provision_layout_and_acls
  provision_service_unit
  provision_firewall
  verify_all
  log "Provisioning complete"
}

main "$@"
