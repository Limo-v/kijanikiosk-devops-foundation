# Nexus Screenshot Placeholder

Current status (2026-04-23): Jenkins login succeeded, but the Week 5 job is not configured yet.

Add the screenshot file `nexus-versions-screenshot.png` in this same folder after publishing at least two artifact versions.

Screenshot must show:
- Package name: kijanikiosk-payments.
- At least two distinct versions.
- Version format: <semver>-<git-sha>.

Blocker note:
- The inspected job `pipelineTwo` fails with `ERROR: No flow definition, cannot run`.
- Publish evidence cannot be captured until a Jenkins job is configured to run the repository root `Jenkinsfile`.