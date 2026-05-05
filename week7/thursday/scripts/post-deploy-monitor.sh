#!/bin/bash

# KijaniKiosk Post-Deployment Health Monitor
# Monitors the active environment after a blue/green switch and triggers automatic rollback
# on health check failures
# Usage: sudo bash scripts/post-deploy-monitor.sh [confidence_window_seconds]
# Default confidence window: 120 seconds
# Exit codes: 0 on completion (rollback or success), 1 on error

CONFIDENCE_WINDOW="${1:-120}"
HEALTH_CHECK_URL="http://127.0.0.1:80/health"
HEALTH_CHECK_INTERVAL=5
ROLLBACK_THRESHOLD=3  # 3 consecutive failures trigger rollback
LATENCY_THRESHOLD_MS=2000  # 2 second latency threshold
ERROR_RATE_THRESHOLD=2  # 2 errors per window
ACTIVE_ENV_FILE="/opt/kijanikiosk/.active-env"
ROLLBACK_SCRIPT="$(dirname "$0")/rollback.sh"

# State variables
CONSECUTIVE_FAILURES=0
WINDOW_ERRORS=0
WINDOW_START_TIME=$(date +%s)
WINDOW_LATENCIES=()
T0_TIME=""  # Timestamp when monitoring started
T1_TIME=""  # Timestamp when first failure detected
T2_TIME=""  # Timestamp when rollback completed

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Helper functions
log() {
    local timestamp=$(date '+%H:%M:%S')
    echo "[${timestamp}] [MONITOR] $1"
}

log_warn() {
    local timestamp=$(date '+%H:%M:%S')
    echo -e "${YELLOW}[${timestamp}] [MONITOR WARN] $1${NC}"
}

log_fail() {
    local timestamp=$(date '+%H:%M:%S')
    echo -e "${RED}[${timestamp}] [MONITOR FAIL] $1${NC}"
}

log_success() {
    local timestamp=$(date '+%H:%M:%S')
    echo -e "${GREEN}[${timestamp}] [MONITOR SUCCESS] $1${NC}"
}

# Validation
if ! command -v curl &> /dev/null; then
    log_fail "curl not found. Cannot perform health checks."
    exit 1
fi

if [[ ! -f "${ROLLBACK_SCRIPT}" ]]; then
    log_fail "Rollback script not found: ${ROLLBACK_SCRIPT}"
    exit 1
fi

# Record T0 - when monitoring starts
T0_TIME=$(date '+%H:%M:%S')
log "=== Post-Deployment Monitor Starting ==="
log "Confidence window: ${CONFIDENCE_WINDOW} seconds"
log "Health check interval: ${HEALTH_CHECK_INTERVAL} seconds"
log "Rollback threshold: ${ROLLBACK_THRESHOLD} consecutive failures"
log "Latency threshold: ${LATENCY_THRESHOLD_MS}ms"
log "Error rate threshold: ${ERROR_RATE_THRESHOLD} errors per window"
log "T0 (Monitor start): ${T0_TIME}"
log ""

POLL_COUNT=0
START_TIME=$(date +%s)

while true; do
    POLL_COUNT=$((POLL_COUNT + 1))
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    # Check if we've exceeded the confidence window
    if [[ ${ELAPSED} -ge ${CONFIDENCE_WINDOW} ]] && [[ ${CONSECUTIVE_FAILURES} -eq 0 ]]; then
        log_success "Confidence window completed (${ELAPSED}s). Service is healthy."
        log "Final state: ${CONSECUTIVE_FAILURES} consecutive failures"
        exit 0
    fi
    
    # Perform health check
    RESPONSE=$(curl -s -w "\n%{http_code}\n%{time_total}" "${HEALTH_CHECK_URL}" 2>/dev/null || echo -e "\n000\n9.999")
    HTTP_CODE=$(echo "${RESPONSE}" | sed -n '2p')
    LATENCY=$(echo "${RESPONSE}" | sed -n '3p')
    BODY=$(echo "${RESPONSE}" | head -n1)
    LATENCY_MS=$(echo "${LATENCY} * 1000" | bc | cut -d'.' -f1)
    
    # Check for success
    if [[ "${HTTP_CODE}" == "200" ]] && [[ ${LATENCY_MS} -lt ${LATENCY_THRESHOLD_MS} ]]; then
        CONSECUTIVE_FAILURES=0
        WINDOW_LATENCIES+=("${LATENCY_MS}")
        
        # Extract version from response
        VERSION=$(echo "${BODY}" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        
        log "Poll $POLL_COUNT: HTTP 200 | ${LATENCY_MS}ms | elapsed: ${ELAPSED}s | version: ${VERSION}"
    else
        # Health check failed
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        WINDOW_ERRORS=$((WINDOW_ERRORS + 1))
        
        if [[ -z "${T1_TIME}" ]]; then
            T1_TIME=$(date '+%H:%M:%S')
            log_warn "T1 (First failure): ${T1_TIME}"
        fi
        
        REASON=""
        if [[ "${HTTP_CODE}" == "000" ]]; then
            REASON="Connection refused"
        elif [[ "${HTTP_CODE}" != "200" ]]; then
            REASON="HTTP ${HTTP_CODE}"
        elif [[ ${LATENCY_MS} -ge ${LATENCY_THRESHOLD_MS} ]]; then
            REASON="Latency ${LATENCY_MS}ms exceeds ${LATENCY_THRESHOLD_MS}ms threshold"
        fi
        
        log "Poll $POLL_COUNT: ${REASON} | elapsed: ${ELAPSED}s"
        log_warn "Health check failed (consecutive: ${CONSECUTIVE_FAILURES}, window errors: ${WINDOW_ERRORS})"
        
        # Check if rollback threshold reached
        if [[ ${CONSECUTIVE_FAILURES} -ge ${ROLLBACK_THRESHOLD} ]]; then
            log_fail "ROLLBACK TRIGGERED: ${CONSECUTIVE_FAILURES} consecutive health check failures"
            log_fail "Calling rollback.sh..."
            
            # Record T2 before rollback
            T2_TIME=$(date '+%H:%M:%S')
            
            # Execute rollback
            if sudo bash "${ROLLBACK_SCRIPT}"; then
                T2_TIMESTAMP=$(date '+%H:%M:%S')
                
                # Calculate duration from T0 to T2
                T0_EPOCH=$(date -d "${T0_TIME}" +%s 2>/dev/null || date +%s)
                T2_EPOCH=$(date -d "${T2_TIMESTAMP}" +%s 2>/dev/null || date +%s)
                TOTAL_DURATION=$((T2_EPOCH - T0_EPOCH))
                
                log_success "Rollback completed successfully."
                log "T2 (Rollback complete): ${T2_TIMESTAMP}"
                log "Total duration T0→T2: ${TOTAL_DURATION}s"
                
                # Verify rollback with one final health check
                sleep 2
                RESPONSE=$(curl -s -w "\n%{http_code}" "${HEALTH_CHECK_URL}" 2>/dev/null || echo -e "\n000")
                HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
                
                if [[ "${HTTP_CODE}" == "200" ]]; then
                    log_success "Post-rollback health check passed"
                    exit 0
                else
                    log_fail "Post-rollback health check FAILED (HTTP ${HTTP_CODE})"
                    exit 1
                fi
            else
                log_fail "Rollback script failed"
                exit 1
            fi
        fi
    fi
    
    # Wait before next poll
    sleep ${HEALTH_CHECK_INTERVAL}
done

exit 0
