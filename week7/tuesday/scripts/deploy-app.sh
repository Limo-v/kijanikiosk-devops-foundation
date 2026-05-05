#!/bin/bash

# KijaniKiosk Blue/Green Deployment Script
# Usage: APP_VERSION=v1.4.0 DEPLOY_ENV=green ARTIFACT_BASE_URL=http://127.0.0.1:8080 sudo -E bash scripts/deploy-app.sh
# Exit codes: 0 on success, 1 on any phase failure

set -e

# Configuration
APP_VERSION="${APP_VERSION:-}"
DEPLOY_ENV="${DEPLOY_ENV:-}"
ARTIFACT_BASE_URL="${ARTIFACT_BASE_URL:-http://127.0.0.1:8080}"
ARTIFACT_PATH="/opt/kijanikiosk/releases"
APP_ROOT="/opt/kijanikiosk/${DEPLOY_ENV}/app"
LOG_FILE="/opt/kijanikiosk/deployment-${DEPLOY_ENV}-$(date +%s).log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log() {
    local timestamp=$(date '+%H:%M:%S')
    echo "[${timestamp}] $1" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓ $1${NC}" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ✗ $1${NC}" | tee -a "${LOG_FILE}"
}

# Validation
if [[ -z "${APP_VERSION}" ]]; then
    log_error "APP_VERSION not set. Usage: APP_VERSION=v1.4.0 DEPLOY_ENV=green bash $0"
    exit 1
fi

if [[ -z "${DEPLOY_ENV}" ]]; then
    log_error "DEPLOY_ENV not set. Use 'blue' or 'green'."
    exit 1
fi

if [[ "${DEPLOY_ENV}" != "blue" && "${DEPLOY_ENV}" != "green" ]]; then
    log_error "DEPLOY_ENV must be 'blue' or 'green', got '${DEPLOY_ENV}'"
    exit 1
fi

log "=== Starting deployment of ${APP_VERSION} to ${DEPLOY_ENV} environment ==="
log "Artifact base URL: ${ARTIFACT_BASE_URL}"
log "Log file: ${LOG_FILE}"

# Phase 1: Fetch
log ""
log "Phase 1: Fetching artifact ${APP_VERSION}..."
ARTIFACT_FILE="kk-api-${APP_VERSION}.tar.gz"
ARTIFACT_URL="${ARTIFACT_BASE_URL}/${ARTIFACT_FILE}"
ARTIFACT_LOCAL="${ARTIFACT_PATH}/${ARTIFACT_FILE}"

if [[ -f "${ARTIFACT_LOCAL}" ]]; then
    log "Artifact already present locally: ${ARTIFACT_LOCAL}"
else
    log "Downloading from ${ARTIFACT_URL}..."
    if ! curl -f -o "${ARTIFACT_LOCAL}" "${ARTIFACT_URL}"; then
        log_error "Failed to fetch artifact from ${ARTIFACT_URL}"
        exit 1
    fi
    log_success "Artifact fetched and saved to ${ARTIFACT_LOCAL}"
fi

# Phase 2: Validate
log ""
log "Phase 2: Validating artifact..."
if [[ ! -f "${ARTIFACT_LOCAL}" ]]; then
    log_error "Artifact file not found after fetch: ${ARTIFACT_LOCAL}"
    exit 1
fi

ARTIFACT_SIZE=$(stat -f%z "${ARTIFACT_LOCAL}" 2>/dev/null || stat -c%s "${ARTIFACT_LOCAL}" 2>/dev/null || echo "0")
if [[ "${ARTIFACT_SIZE}" -lt 100 ]]; then
    log_error "Artifact appears corrupted or empty (size: ${ARTIFACT_SIZE} bytes)"
    exit 1
fi

if ! tar -tzf "${ARTIFACT_LOCAL}" > /dev/null 2>&1; then
    log_error "Artifact is not a valid tar.gz file"
    exit 1
fi

log_success "Artifact validation passed (size: ${ARTIFACT_SIZE} bytes)"

# Phase 3: Deploy
log ""
log "Phase 3: Deploying to ${APP_ROOT}..."
mkdir -p "${APP_ROOT}"
rm -rf "${APP_ROOT}"/*

if ! tar -xzf "${ARTIFACT_LOCAL}" -C "${APP_ROOT}" --strip-components=1; then
    log_error "Failed to extract artifact to ${APP_ROOT}"
    exit 1
fi

# Verify files were deployed
DEPLOYED_FILES=$(find "${APP_ROOT}" -type f | wc -l)
if [[ "${DEPLOYED_FILES}" -lt 1 ]]; then
    log_error "No files were deployed to ${APP_ROOT}"
    exit 1
fi

log_success "Deployed ${DEPLOYED_FILES} files to ${APP_ROOT}"

# Write version marker
echo "${APP_VERSION}" > "${APP_ROOT}/.version"
log "Version marker written: $(cat ${APP_ROOT}/.version)"

# Phase 4: Restart
log ""
log "Phase 4: Restarting kk-api-${DEPLOY_ENV}.service..."

SERVICE_NAME="kk-api-${DEPLOY_ENV}.service"
if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
    log "Service ${SERVICE_NAME} is not currently active, starting it..."
fi

if ! systemctl restart "${SERVICE_NAME}"; then
    log_error "Failed to restart ${SERVICE_NAME}"
    exit 1
fi

# Wait for service to be ready
log "Waiting for service to stabilize..."
sleep 2

if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
    log_error "Service ${SERVICE_NAME} failed to start or became inactive"
    exit 1
fi

log_success "Service ${SERVICE_NAME} restarted successfully"

# Phase 5: Verify
log ""
log "Phase 5: Verifying deployment..."

# Determine the port based on the environment
if [[ "${DEPLOY_ENV}" == "blue" ]]; then
    SERVICE_PORT=3000
else
    SERVICE_PORT=3001
fi

# Health check with retries
MAX_RETRIES=10
RETRY_COUNT=0
HEALTH_CHECK_PASSED=false

while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; do
    RESPONSE=$(curl -s -w "\n%{http_code}" "http://127.0.0.1:${SERVICE_PORT}/health" 2>/dev/null || echo -e "\n000")
    HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
    BODY=$(echo "${RESPONSE}" | head -n-1)
    
    if [[ "${HTTP_CODE}" == "200" ]]; then
        RESPONSE_VERSION=$(echo "${BODY}" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        
        if [[ "${RESPONSE_VERSION}" == "${APP_VERSION}" ]]; then
            log_success "Health check passed: ${SERVICE_PORT} returning ${APP_VERSION}"
            log "Full response: ${BODY}"
            HEALTH_CHECK_PASSED=true
            break
        else
            log "Version mismatch: expected ${APP_VERSION}, got ${RESPONSE_VERSION}. Retrying..."
        fi
    else
        log "Health check attempt $((RETRY_COUNT + 1))/${MAX_RETRIES} failed (HTTP ${HTTP_CODE}). Retrying..."
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 1
done

if [[ "${HEALTH_CHECK_PASSED}" != "true" ]]; then
    log_error "Health check failed after ${MAX_RETRIES} retries"
    exit 1
fi

# Final verification
log ""
log_success "=== Deployment of ${APP_VERSION} to ${DEPLOY_ENV} completed successfully ==="
log "Summary:"
log "  - Version: ${APP_VERSION}"
log "  - Environment: ${DEPLOY_ENV}"
log "  - Service: kk-api-${DEPLOY_ENV}.service"
log "  - Port: ${SERVICE_PORT}"
log "  - Files deployed: ${DEPLOYED_FILES}"

exit 0
