# Post-Incident Review: Week 5 Monday Production Config Incident

**Date:** May 5, 2026, ~09:15 UTC  
**Duration:** ~8 minutes  
**Severity:** High — production affected during investor demo  
**Prepared by:** Amina & Tendo | Reviewed by: Nia

---

## Summary

During a live investor walkthrough, Amina ran `make configure ENV=production` from her local machine. This pushed local staging credentials to the production server. kk-payments restarted with the wrong database connection strings and started failing transactions. Monitoring detected it, manual recovery took ~4.5 minutes. About 15 transactions failed.

The core problem was that the Makefile didn't distinguish between local dev work and production deployments.

---

## Timeline

| Time (UTC) | Event | Type |
|---|---|---|
| 09:12 | Nia begins investor walkthrough | Context |
| 09:13 | Amina opens terminal to "quickly check" something | User action |
| 09:13:15 | Amina runs `make configure ENV=production` | Root cause trigger |
| 09:13:30 | `~/.kijanikiosk.env` (staging creds) written to `/etc/kijanikiosk/production.env` | Error propagation |
| 09:13:45 | Jenkins restarts kk-api + kk-payments with wrong creds | Amplification |
| 09:14:00 | First failure: "Database connection refused" in logs | T1 Detection |
| 09:14:15 | Alert fires: Payment Error Rate > 1% | Confirmation |
| 09:14:30 | Nia notices investor confusion; Tendo investigates | Escalation |
| 09:15:00 | Tendo identifies staging creds in production env file | Root cause found |
| 09:15:30 | Amina rolls back kk-payments to previous container | Mitigation |
| 09:16:00 | Health checks pass; error rate 0% | Recovery starts |
| 09:16:45 | Correct creds restored; services restarted | T2 Recovery complete |
| 09:17:15 | End-to-end payment test passes | Verified |

---

## Root Cause

**Why it happened:** Amina opened a terminal mid-demo and muscle-memory triggered `make configure ENV=production`. She'd run `make configure ENV=staging` dozens of times — same syntax, different target.

**Why there was no guard:** The Makefile treats all ENV values the same. The `configure` target reads from the shell env, so staging credentials were right there waiting to be exported.

**Why the impact was amplified:** GitHub Actions correctly uses GitHub Secrets for production — it never touches `~/.kijanikiosk.env`. But the Makefile doesn't have that protection. So CI was fine; local wasn't.

**Why recovery was slow:** No automated rollback for configuration changes. Tendo had to manually read logs, identify the wrong credentials, restore them, and restart services. If we'd had the monitoring script from Week 7 running, it would have triggered rollback automatically within ~30 seconds.

### Contributing Factors

- `make configure` applies identically to staging and production — no ENV validation
- Developers load `~/.kijanikiosk.env` into their shell for local testing, which makes it easy to accidentally export those local creds to production
- No credential validation in Ansible before writing to files
- No automated rollback for config failures
- Demo timing created pressure to move fast

---

## Prevention Mechanisms

**1. Makefile guard** — `make configure ENV=production` exits with an error and tells you to use GitHub Actions instead. Zero friction to staging workflows. This is the single most important fix.

**2. GitHub Secrets for production creds** — Production credentials come from GitHub Secrets, never from the developer's shell. Even if the Makefile check is bypassed, CI still uses the right creds.

**3. Credential validation in Ansible** — Before writing creds to production, the playbook asserts that DB_HOST matches a production pattern. Fails loudly if staging values are detected.

**4. Automated rollback in GitHub Actions** — If health checks fail within 30 seconds of a config deployment, the pipeline rolls back automatically. This is what Week 7 was building toward.

**5. Confirmation prompt for destructive targets** — As a belt-and-suspenders measure, require developers to type "confirm-production" to proceed past a Makefile prompt, adding friction to accidental production changes.

---

## Action Items

| Action | Owner | Target | Criteria |
|--------|-------|--------|----------|
| Add Makefile guard for production ENV | Amina | Week 6 Mon | `make configure ENV=production` fails with error message |
| GitHub Secrets + Ansible credential validation | Tendo | Week 6 Tue-Wed | CI reads from Secrets; Ansible validates before writing |
| Production deployment runbook | Nia | Week 6 Wed-Thu | One-page doc; team sign-off via Slack |

---

## Metrics

| Metric | Value | Target |
|--------|-------|--------|
| Time to detect | 47 seconds | < 1 minute |
| Time to recover | 4.5 minutes | < 5 minutes |
| Transactions failed | ~15 | 0 |
| Investor impact | High (demo interrupted) | None |

---

## Lessons Learned

1. **Automation boundaries are security boundaries**: What works on developer machines can become a security issue at scale. The same `make configure` that works locally is dangerous in production.

2. **Credentials should follow environment, not shell**: Storing credentials in shell environment variables (`~/.kijanikiosk.env`) makes it too easy to accidentally export them. GitHub Secrets for production, config files for local development.

3. **Demo timing is risk timing**: Demonstrating to investors during the same week as infrastructure work created time pressure. Amina felt rushed and made a habit-driven mistake.

---

## Follow-Up

- [ ] Amina implements Makefile guard (due Week 6 Monday)
- [ ] Tendo validates GitHub Secrets integration (due Week 6 Tuesday)
- [ ] Nia reviews and signs off on deployment runbook (due Week 6 Wednesday)
- [ ] Team reviews this post-incident review in standup (Week 6 Thursday)
