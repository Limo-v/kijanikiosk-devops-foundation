#!/bin/bash

# KijaniKiosk Blue/Green Traffic Switch Script
# Switches nginx proxy traffic from one environment to another with health check
# Usage: sudo bash scripts/switch-env.sh blue|green
# Exit codes: 0 on success, 1 on failure

set -e

TARGET_ENV="${1:-}"
ACTIVE_ENV_FILE="/opt/kijanikiosk/.active-env"
PREVIOUS_ENV_FILE="/opt/kijanikiosk/.previous-env"
NGINX_CONFIG_DIR="/etc/nginx"
NGINX_ACTIVE_CONFIG="${NGINX_CONFIG_DIR}/kijanikiosk-active-env.conf"
HEALTH_CHECK_TIMEOUT=10
HEALTH_CHECK_RETRIES=5

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Helper functions
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓ $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ✗ $1${NC}"
}

log_info() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ℹ $1${NC}"
}

# Validation
if [[ -z "${TARGET_ENV}" ]]; then
    log_error "Usage: $0 blue|green"
    exit 1
fi

if [[ "${TARGET_ENV}" != "blue" && "${TARGET_ENV}" != "green" ]]; then
    log_error "Invalid target environment: '${TARGET_ENV}'. Must be 'blue' or 'green'."
    exit 1
fi

# Get current environment
if [[ -f "${ACTIVE_ENV_FILE}" ]]; then
    CURRENT_ENV=$(cat "${ACTIVE_ENV_FILE}" | tr -d ' \n')
else
    log_error "Active environment file not found: ${ACTIVE_ENV_FILE}"
    exit 1
fi

log "Current environment: ${CURRENT_ENV}"
log "Target environment:  ${TARGET_ENV}"

# Check if already on target environment
if [[ "${CURRENT_ENV}" == "${TARGET_ENV}" ]]; then
    log_info "Already on target environment, skipping switch"
    exit 0
fi

# Determine port for target environment
if [[ "${TARGET_ENV}" == "blue" ]]; then
    TARGET_PORT=3000
else
    TARGET_PORT=3001
fi

# Step 1: Pre-switch health check
log ""
log "Step 1: Verifying ${TARGET_ENV} is healthy on port ${TARGET_PORT}..."

HEALTH_CHECK_SUCCESS=false
for i in $(seq 1 ${HEALTH_CHECK_RETRIES}); do
    RESPONSE=$(curl -s -w "\n%{http_code}" "http://127.0.0.1:${TARGET_PORT}/health" 2>/dev/null || echo -e "\n000")
    HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
    BODY=$(echo "${RESPONSE}" | head -n-1)
    
    if [[ "${HTTP_CODE}" == "200" ]]; then
        log_success "Pre-switch health check passed: ${TARGET_ENV} is healthy"
        HEALTH_CHECK_SUCCESS=true
        break
    else
        if [[ ${i} -lt ${HEALTH_CHECK_RETRIES} ]]; then
            log "Health check attempt $i/${HEALTH_CHECK_RETRIES} failed (HTTP ${HTTP_CODE}). Retrying in 1s..."
            sleep 1
        fi
    fi
done

if [[ "${HEALTH_CHECK_SUCCESS}" != "true" ]]; then
    log_error "Pre-switch health check FAILED: ${TARGET_ENV} (port ${TARGET_PORT}) is not responding"
    log_error "Refusing to switch. Run the deployment script first."
    exit 1
fi

# Step 2: Write new nginx configuration
log ""
log "Step 2: Writing new nginx active-env configuration..."

if ! mkdir -p "${NGINX_CONFIG_DIR}"; then
    log_error "Failed to create nginx config directory"
    exit 1
fi

# Generate the nginx config that points to the target environment
if [[ "${TARGET_ENV}" == "blue" ]]; then
    UPSTREAM_PORT=3000
else
    UPSTREAM_PORT=3001
fi

NGINX_CONFIG_CONTENT="# Auto-generated blue/green traffic routing config
# Generated: $(date)
# Target environment: ${TARGET_ENV} (port ${UPSTREAM_PORT})

upstream kijanikiosk_api {
    server 127.0.0.1:${UPSTREAM_PORT};
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://kijanikiosk_api;
        proxy_http_version 1.1;
        proxy_set_header Connection \"\"
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout 10s;
    }
}
"

if ! echo "${NGINX_CONFIG_CONTENT}" > "${NGINX_ACTIVE_CONFIG}"; then
    log_error "Failed to write nginx configuration to ${NGINX_ACTIVE_CONFIG}"
    exit 1
fi

log_success "Nginx configuration written"

# Step 3: Validate nginx configuration
log ""
log "Step 3: Validating nginx configuration..."

if ! nginx -t 2>&1 | grep -q "successful\|OK"; then
    log_error "Nginx configuration validation failed:"
    nginx -t 2>&1
    exit 1
fi

log_success "Nginx configuration is valid"

# Step 4: Reload nginx
log ""
log "Step 4: Reloading nginx..."

if ! systemctl reload nginx; then
    log_error "Failed to reload nginx"
    exit 1
fi

sleep 1

log_success "nginx reloaded. Traffic now routing to ${TARGET_ENV}."

# Step 5: Post-switch confirmation via proxy
log ""
log "Step 5: Confirming switch via proxy health check..."

PROXY_CHECK_SUCCESS=false
for i in $(seq 1 ${HEALTH_CHECK_RETRIES}); do
    RESPONSE=$(curl -s -w "\n%{http_code}" "http://127.0.0.1:80/health" 2>/dev/null || echo -e "\n000")
    HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
    BODY=$(echo "${RESPONSE}" | head -n-1)
    
    if [[ "${HTTP_CODE}" == "200" ]]; then
        # Extract version from JSON response
        RESPONSE_ENV=$(echo "${BODY}" | grep -o '"port":[0-9]*' | cut -d':' -f2)
        
        if [[ "${RESPONSE_ENV}" == "${UPSTREAM_PORT}" ]]; then
            log_success "Post-switch confirmation passed: proxy is routing to ${TARGET_ENV} (port ${UPSTREAM_PORT})"
            PROXY_CHECK_SUCCESS=true
            break
        else
            log "Port mismatch in response. Expected ${UPSTREAM_PORT}, got ${RESPONSE_ENV}. Retrying..."
        fi
    else
        log "Proxy health check attempt $i/${HEALTH_CHECK_RETRIES} failed (HTTP ${HTTP_CODE}). Retrying..."
        if [[ ${i} -lt ${HEALTH_CHECK_RETRIES} ]]; then
            sleep 1
        fi
    fi
done

if [[ "${PROXY_CHECK_SUCCESS}" != "true" ]]; then
    log_error "Post-switch confirmation FAILED: proxy is not routing correctly"
    exit 1
fi

# Update state files
log ""
log "Updating state files..."

echo "${TARGET_ENV}" | tee "${ACTIVE_ENV_FILE}" > /dev/null
echo "${CURRENT_ENV}" | tee "${PREVIOUS_ENV_FILE}" > /dev/null

log_success "State files updated:"
log "  ${ACTIVE_ENV_FILE}: $(cat ${ACTIVE_ENV_FILE})"
log "  ${PREVIOUS_ENV_FILE}: $(cat ${PREVIOUS_ENV_FILE})"

# Final summary
log ""
log_success "=== Switch to ${TARGET_ENV} complete ==="
log "Summary:"
log "  - Traffic now routing to: ${TARGET_ENV}"
log "  - Upstream port: ${UPSTREAM_PORT}"
log "  - Previous environment: ${CURRENT_ENV}"
log "  - nginx config: ${NGINX_ACTIVE_CONFIG}"

exit 0
