#!/bin/bash

# KijaniKiosk Rollback Script
# Reverts traffic to the previous environment in case of deployment failure
# Usage: sudo bash scripts/rollback.sh
# Reads from .previous-env file to determine rollback target

PREVIOUS_ENV_FILE="/opt/kijanikiosk/.previous-env"
ACTIVE_ENV_FILE="/opt/kijanikiosk/.active-env"

# Helper functions
log() {
    echo "[ROLLBACK] [$(date '+%H:%M:%S')] $1"
}

# Check if previous environment file exists
if [[ ! -f "${PREVIOUS_ENV_FILE}" ]]; then
    log "Error: Previous environment file not found: ${PREVIOUS_ENV_FILE}"
    exit 1
fi

# Get the previous environment
ROLLBACK_TARGET=$(cat "${PREVIOUS_ENV_FILE}" | tr -d ' \n')

if [[ -z "${ROLLBACK_TARGET}" ]]; then
    log "Error: Previous environment file is empty"
    exit 1
fi

log "Rolling back to previous environment: ${ROLLBACK_TARGET}"

# Call switch-env.sh to perform the rollback
if bash $(dirname "$0")/switch-env.sh "${ROLLBACK_TARGET}"; then
    log "Rollback completed successfully."
    log "Active environment: $(cat ${ACTIVE_ENV_FILE})"
    log "Previous environment: $(cat ${PREVIOUS_ENV_FILE})"
    exit 0
else
    log "Rollback FAILED"
    exit 1
fi
