# Post-Incident Review: Week 5 Monday Production Config Incident

**Incident Date:** May 5, 2026, ~09:15 UTC  
**Review Date:** May 5, 2026 (Week 7 Friday)  
**Duration:** ~8 minutes | **Severity:** High  
**Reviewed by:** Amina, Tendo, Nia

---

## Summary

During a live investor demo, Amina ran `make configure ENV=production` from her local terminal. The Makefile pushed local staging credentials to the production server. kk-api and kk-payments restarted with the wrong database connection strings and started rejecting transactions. 15 payments failed, the demo was interrupted. Manual recovery took ~4.5 minutes.

This review is being written in Week 7 with the benefit of what we've now built: an automated rollback system that would have caught this in ~30 seconds instead of 4.5 minutes.

---

## Timeline

| Time (UTC) | Event | Category |
|---|---|---|
| 09:12:00 | Nia starts investor walkthrough | Context |
| 09:13:00 | Amina opens terminal "to check something" | User action |
| 09:13:15 | Amina runs `make configure ENV=production` | Root cause |
| 09:13:30 | `~/.kijanikiosk.env` (staging creds) written to `/etc/kijanikiosk/production.env` | Propagation |
| 09:13:45 | Jenkins restarts kk-api + kk-payments with wrong DB credentials | Amplification |
| 09:14:00 | First "Database connection refused" error appears in logs | T1 Detection |
| 09:14:15 | Alert fires: Payment Error Rate > 1% | Confirmation |
| 09:14:30 | Nia notices confusion; Tendo starts investigating | Escalation |
| 09:15:00 | Tendo finds staging host in production env file | Root cause confirmed |
| 09:15:30 | Amina stops services, restarts with previous container | Mitigation |
| 09:16:00 | Health checks pass; error rate 0% | Recovery signal |
| 09:16:45 | Correct creds restored, services restarted | T2 Recovery |
| 09:17:15 | 5 test payments succeed; incident closed | Verified |

**T1→T2:** 4 minutes 45 seconds  
**Total impact:** 15 failed payments, 1 interrupted investor demo, 2.5 hours follow-up

---

## Root Cause

The `make configure` target reads from the shell environment and blindly applies it to whichever ENV is passed. Amina's shell had `~/.kijanikiosk.env` loaded (staging credentials), and she ran `make configure ENV=production` by habit — the same syntax she uses for staging.

There was no guard, no validation, and no credential check in Ansible. GitHub Actions does this correctly using GitHub Secrets, but the Makefile had no such protection. Developers with shell access were one command away from pushing the wrong credentials to production.

Once services restarted with wrong credentials, there was nothing automated to catch it. Tendo had to manually read logs, identify the mismatch, restore credentials, and restart services. That's why recovery took 4+ minutes instead of ~30 seconds.

### Contributing Factors

- Makefile treats all ENV values the same — no production guard
- Developers load `~/.kijanikiosk.env` into shell for local dev; that env is one `make` command away from production
- Ansible writes credentials without validating they match the target environment
- No automated rollback for configuration failures
- Demo timing added pressure to work fast

---

## Prevention Mechanisms

**1. Makefile guard** — `make configure ENV=production` now exits with an error and points to GitHub Actions. This is the single most important fix.

**2. GitHub Secrets for production creds** — Production credentials come from GitHub Secrets, not from a developer's local shell. Even if the Makefile guard is bypassed somehow, CI uses the right creds.

**3. Credential validation in Ansible** — Playbook asserts that DB_HOST matches known production patterns before writing to files. Fails loudly if staging values are detected.

**4. Automated rollback on failed config** — Post-deploy health checks in the GitHub Actions pipeline would trigger rollback within 30 seconds of a bad configuration deployment. This is what the Week 7 monitor is for.

**5. Confirmation prompt** — `make configure ENV=production` now prompts for "confirm-production" before proceeding. Belt-and-suspenders measure for the case where we intentionally want to run this.

---

## Action Items

| Action | Owner | Target | Criteria |
|--------|-------|--------|----------|
| Makefile guard for `ENV=production` | Amina | Week 6 Mon | `make configure ENV=production` fails with clear message |
| GitHub Secrets + Ansible credential check | Tendo | Week 6 Tue-Wed | Production deploys read from Secrets; Ansible validates before write |
| Production deployment runbook | Nia | Week 6 Thu | One-page doc, team acknowledgement via Slack |

---

## Incident Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Time to detect | 47 seconds | < 1 minute | ✓ |
| Time to resolve | 4 min 45 sec | < 5 minutes | ✓ |
| Transactions failed | ~15 | 0 | ✗ |
| Investor impact | High (demo interrupted) | None | ✗ |
| SLO violation | Yes (error rate > 0.05%) | No | ✗ |

---

## Lessons

- What works safely on a dev machine (loading credentials from shell env) becomes a risk vector if there's no guard at the production boundary.
- The GitHub Actions pipeline was fine — it used Secrets correctly. The problem was developers had a secondary path (Makefile) that bypassed those protections.
- If we'd had Week 7's monitor running in production, this would have rolled back automatically in about 30 seconds instead of 4.5 minutes.

4. **Team mental model matters.** Tendo and Nia had assumed all production changes go through GitHub Actions; Amina (new to team) didn't know this was the expectation. Explicit runbook would have prevented confusion.

---

## Follow-Up Items

- [x] Post-incident review completed (Week 7 Friday)
- [ ] Amina implements Makefile guard (due Week 6 Monday)
- [ ] Tendo completes GitHub Secrets + Ansible validation (due Week 6 Wednesday)
- [ ] Nia publishes production runbook (due Week 6 Thursday)
- [ ] Team reviews this document in standup (Week 6 Friday)
- [ ] Monthly metrics review: confirm prevention mechanisms are working (Week 8+)
