# Week 5 Friday Fault Injection Log

Complete this table from real Jenkins runs. Fault one stage at a time, restore green, then move to the next stage.

| Stage faulted | Fault introduced | Expected behaviour | Observed (build #) | Design rationale |
| --- | --- | --- | --- | --- |
| Lint | Break formatting or add lint violation. | Pipeline fails in Lint. Build, Verify, Archive, and Publish skip. | Blocked - Week 5 job not configured | Fast failure protects CI minutes and blocks low-quality code quickly. |
| Build | Break build command or force missing output directory. | Lint passes, Build fails, remaining stages skip. | Blocked - Week 5 job not configured | No verification or publishing should occur without a valid build artifact. |
| Test | Add a deliberate failing assertion. | Build succeeds, Verify fails due to Test branch, Archive and Publish skip. | Blocked - Week 5 job not configured | Release is blocked when functional checks fail even if build output exists. |
| Security Audit | Force a high-severity dependency vulnerability. | Test may pass, Verify still fails due to audit branch, Archive and Publish skip. | Blocked - Week 5 job not configured | Dependency risk is a release gate equal to test quality for a payments service. |
| Publish | Use wrong credential ID or invalid Nexus auth. | Archive succeeds, Publish fails, artifact stays in Jenkins but not Nexus. | Blocked - Week 5 job not configured | Internal artifact traceability remains while external publication is safely blocked. |

Notes:
- Jenkins UI access is confirmed, and existing jobs were inspected on 2026-04-23.
- Existing `pipelineTwo` job fails with `No flow definition`, so fault injection cannot be executed yet against the Week 5 pipeline.
- Replace each blocked entry with real build numbers after the Week 5 job is configured to use the root `Jenkinsfile`.