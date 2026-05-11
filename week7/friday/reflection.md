# Week 7 Project Reflection

**Author:** Amina | **Date:** May 5, 2026

---

## Q1: Translation Challenge

*Where in the demo script did the plain language overclaim what the system actually does?*

The clearest overclaim is "the system heals itself." After the rollback demo, Nia says it like it's completely automatic and foolproof. But there's a hidden assumption: blue has to be healthy for the rollback to work. The monitor detected that green was down, called rollback.sh, and rollback.sh called switch-env.sh with a pre-switch health check on blue. If blue had also been unhealthy — say, a bad config pushed to both environments — rollback.sh would have exited with an error and traffic would have stayed broken.

A more honest version: "When the new version has a problem, we automatically switch back to the old one — but only if the old one is still healthy. We tested that scenario today. If both versions were broken at once, we'd need a human."

That's still simple enough for the board, and it doesn't hide the assumption.

---

## Q2: Highest-Value Action Item

*For the Week 5 Monday incident, what's the single highest-value prevention?*

The Makefile guard:

```makefile
ifeq ($(ENV),production)
$(error "configure target cannot be run locally against production. Use GitHub Actions instead.")
endif
```

This prevents exactly what happened — a habit-driven `make configure ENV=production` from a developer machine. It's a one-line fix with high confidence (~95%) because it removes the direct path that caused the incident.

The remaining 5% uncertainty is about edge cases I'd need to verify:
- Can developers SSH directly into production and run scripts without the Makefile? If yes, the guard doesn't help.
- Are there other Makefile targets that accept `ENV=production`? I'd need to audit all of them.
- Are GitHub Secrets actually locked down? If someone can modify the Actions workflow and read secrets, there's still a risk.

Without auditing those three things, I can't be fully certain. But the Makefile guard is still the right first step — it removes the most obvious failure path.

---

## Q3: What Carries Forward to Kubernetes

*Which parts of this week's rollback system carry forward into Kubernetes? Which become redundant?*

**Concepts that carry forward:**
- **Health-check-based rollback logic** — the idea of polling an endpoint, counting failures, and making a rollback decision. In Kubernetes this becomes liveness/readiness probes with `failureThreshold`, but the logic is the same.
- **Verify health before trusting with traffic** — switch-env.sh checks blue before switching to it. Kubernetes readiness probes do the same before adding pods to the load balancer.
- **Keep the previous version available** — blue stays running while green is active, ready for instant switch-back. Kubernetes maintains old ReplicaSets during rollouts for the same reason.

**Things that become redundant:**
- `.active-env` and `.previous-env` state files — Kubernetes Deployment objects are the source of truth. `kubectl get deployment` tells you everything those files told us.
- `switch-env.sh` and `rollback.sh` — replaced by `kubectl rollout undo deployment/kk-api`.
- nginx config files manually rewritten on switch — replaced by Kubernetes Service objects that route traffic dynamically.
- systemd unit files and `systemctl restart` — replaced by Kubernetes Pods and `kubectl rollout restart`.

The health check endpoint (`/health` returning JSON with version and status) carries forward exactly as-is. That's the one artifact from this week that Kubernetes won't replace — it'll just use it differently.

---

## Week 7 Takeaway

Reliability isn't one mechanism. It's layers: health checks catch problems, gradual switch limits blast radius, automatic rollback recovers fast, monitoring provides confidence. Each layer has its own assumptions. Week 8 replaces the bash implementation, but the layers stay.


