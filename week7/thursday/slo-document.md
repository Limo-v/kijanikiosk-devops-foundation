# KijaniKiosk Service Level Objectives

## kk-api (API Service)

### SLIs

1. **Availability SLI** — percentage of `/health` polls that return HTTP 200 within the measurement window. Collected by the monitoring script every 5 seconds; results stored in logs and aggregated over 30 days.

2. **Latency SLI (P99)** — 99th percentile response time across all API endpoints. Timestamps recorded in nginx access logs; P99 computed hourly and rolled up monthly.

3. **Error Rate SLI** — percentage of requests returning HTTP 5xx, scoped to `/payments` and `/transactions`. Calculated from nginx logs as `(5xx count / total requests) * 100` per hour, then aggregated monthly.

### SLOs

| SLI | Target | Window | Error Budget |
|-----|--------|--------|--------------|
| Availability | 99.9% | 30 days | 43.2 minutes |
| Latency P99 | ≤500ms | 30 days | 1% of requests can exceed 500ms |
| Error Rate | ≤0.1% | 30 days | 50 errors/hour at peak (50k req/hr) |

Budget math: 30 days = 43,200 minutes. 43,200 × 0.001 = 43.2 minutes downtime allowed.

### How the monitor thresholds relate to these SLOs

The `post-deploy-monitor.sh` thresholds are stricter than the production SLOs intentionally.

- **2000ms latency threshold in monitor vs. 500ms P99 SLO**: The monitor is 4x stricter. If the new version is this slow right after deployment, it's a clear regression and worth rolling back immediately rather than waiting for the SLO to be violated over time.

- **3 consecutive failures**: At 5-second intervals this is about 15 seconds of continuous failure. The production SLO allows 43.2 minutes of downtime per month, but post-deployment we want to catch problems in seconds not minutes.

The idea is: be aggressive immediately after the switch, then relax to production thresholds once the confidence window passes.

### What we don't commit to

- **Third-party processor failures** — if Stripe or M-Pesa is down, those errors aren't on us. Logs distinguish "upstream 502" from "internal 500."
- **Planned maintenance** — announced ≥7 days ahead, limited to 1 hour/month, excluded from availability.
- **DDoS traffic** — if attack volume causes errors, those don't count if the security team confirms and documents it.

---

## kk-payments (Payments Service)

### SLIs

1. **Availability SLI** — percentage of payment transaction requests that complete with HTTP 200 and a valid transaction confirmation. Excludes user cancellations and card declines (those are expected application outcomes, not service failures).

2. **Latency SLI (P95)** — 95th percentile end-to-end latency of payment processing, measured at the kk-payments service boundary before reaching any third-party processor. Recorded per transaction in application logs.

3. **Payment Error Rate SLI** — percentage of transactions that fail due to service errors (5xx, timeout, DB connection failure). Explicitly excludes processor errors and user-initiated failures, which are classified separately in logs.

### SLOs

| SLI | Target | Window | Error Budget |
|-----|--------|--------|--------------|
| Availability | 99.95% | 30 days | 21.6 minutes |
| Latency P95 | ≤1000ms | 30 days | 5% of transactions can exceed 1s |
| Payment Error Rate | ≤0.05% | 30 days | ~2 errors/day at steady state |

Stricter than kk-api because a failed payment is directly visible to the customer as lost money. Error budget: 43,200 × 0.0005 = 21.6 minutes allowed downtime.

### What we don't commit to

- **Processor unavailability** — kk-payments being up but Stripe being down is not an SLO failure.
- **Customer-initiated failures** — insufficient funds, card expired, user cancelled — these are not service errors.
- **Database replication lag** — brief inconsistency (< 2 seconds) during replication is not counted, provided the transaction eventually commits correctly.

---

## Monitor Thresholds vs. Production SLOs

The monitor's 2000ms threshold and 3-failure trigger are both more conservative than production SLOs. That's on purpose — immediately after a deployment switch, the risk of a bad version being live is highest, so it makes sense to be strict. Once the confidence window completes, normal SLO monitoring takes over.
