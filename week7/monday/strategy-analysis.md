# Deployment Strategy Analysis — Week 7 Monday

## Scenario 1: The Overnight Batch Processor

**Strategy:** Rolling Update

This is a batch job on a single VM with no external traffic, so zero customer impact is already guaranteed. The 24-hour rollback window is generous — if v2.1.0 produces wrong output, we just re-run with the old version. There's no reason to spin up a second VM just to hold blue when the job doesn't even serve requests. Rolling update fits because the constraint is about output correctness, not request availability.

---

## Scenario 2: The User-Facing Authentication Service

**Strategy:** Blue/Green Deployment

The token change is backwards-incompatible, which means you can't have both versions running at the same time — a token issued by v1.x gets rejected by v2.0 and vice versa. That rules out canary and rolling update. Blue/green lets us keep v1.x active until we're ready, then flip all traffic at once. The 5-minute rollback constraint is also key: with blue/green you just switch back to blue, which is already running. No re-deployment needed.

---

## Scenario 3: The ML Recommendation Engine

**Strategy:** Canary Deployment

The team can't know if v3.0 actually improves click-through rates without real production traffic. They need data before committing. Canary lets them send a small percentage of traffic to the new model and compare click-through rate and latency against v2.8 side-by-side. The go/no-go signal is: does P99 latency stay within SLO and does click-through rate improve (or at least not drop) for each traffic percentage? If either metric regresses, they roll back that stage instead of the full deployment.

---

## Summary

| Scenario | Strategy | Key constraint driving the choice |
|----------|----------|-----------------------------------|
| Batch Processor | Rolling Update | No external traffic; rollback = re-run |
| Authentication Service | Blue/Green | Backwards-incompatible token; must flip atomically |
| Recommendation Engine | Canary | Need measured data before committing |
