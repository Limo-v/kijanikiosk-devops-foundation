# kk-payments Service Level Objectives

## SLIs

**1. Availability** — percentage of payment transaction requests that return HTTP 200 with a successful transaction result. Logs record each transaction attempt, HTTP code, and outcome (success, processor decline, service error). User cancellations and client-side failures are excluded.

**2. Latency (P95)** — 95th percentile end-to-end latency measured at the kk-payments service boundary. Each transaction log includes receipt and completion timestamps. Monthly SLO uses daily P95 values.

**3. Payment Error Rate** — percentage of transactions that fail due to service-level errors (5xx, timeout, DB connection failure). Excludes processor failures and user-initiated outcomes. Error rate = service errors / total attempts × 100.

## SLO Table

| SLI | Target | Window | Error Budget |
|-----|--------|--------|--------------|
| Availability | 99.95% | 30 days | 21.6 minutes downtime |
| Latency P95 | ≤1000ms | 30 days | 5% of transactions can exceed 1s |
| Payment Error Rate | ≤0.05% | 30 days | ~2 errors/day at steady state |

Stricter than kk-api (99.9% availability, 0.1% error rate) because a payment failure is directly visible to the customer as money not going through.

## Rollback Threshold vs. Production SLO

The monitor uses 2000ms latency and 3 consecutive failures as rollback triggers — both stricter than the production SLOs. During deployment, we want to catch problems in seconds, not let them accumulate across the month's error budget. Once the confidence window completes, normal production SLO thresholds take over.

## Exclusions

1. **Processor failures** — if Stripe or M-Pesa is down, those aren't counted against kk-payments SLOs. Logs distinguish "internal 500" from "processor 502."

2. **Planned maintenance** — windows announced ≥7 days ahead, max 4 hours/month, are excluded from availability.

3. **DDoS/attack traffic** — errors caused by adversarial volume aren't counted, provided the security team confirms and documents the attack.

4. **Client-side failures** — card declines, insufficient funds, user cancellations. These are correct application behavior, not service failures.

5. **Database replication lag** — brief inconsistency (< 2 seconds) during replication, provided the transaction eventually commits correctly, is not counted as a service error.
3. Automation catches problems before manual escalation is needed
