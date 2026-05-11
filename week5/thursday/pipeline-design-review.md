# Week 5 Thursday Pipeline Design Review

## Scope

This review evaluates the production pipeline defined in `week5/thursday/Jenkinsfile` against the five design principles called out in the lab prompt. The code review is complete from the repository side. Runtime claims that depend on Jenkins and Nexus still need to be confirmed with a live build log.

## 1. Environment Isolation

The pipeline uses a pinned Docker agent, `node:18-alpine`, instead of `latest` or a host-level runtime. That gives the pipeline a repeatable Node execution environment and avoids drift between runs caused by package changes on the Jenkins VM.

## 2. Fail-Fast Ordering

`Lint` runs before `Build`, which means formatting or syntax defects stop the pipeline before time is spent building and verifying artifacts. This is the most cost-effective place to reject obviously bad code.

## 3. Parallel Verification

The `Verify` stage runs `Test` and `Security Audit` in parallel. That keeps functional quality checks and dependency risk checks independent while shortening total pipeline duration compared with a serial design.

## 4. Artifact Integrity and Traceability

The pipeline archives the build output with fingerprinting and computes a version string in `<semver>-<git-sha>` format before publication. That pairing supports both traceability back to source and retrieval from Jenkins even if Nexus publication later fails.

## 5. Credential Hygiene

The `Publish` stage scopes Nexus secrets to `withCredentials`, creates `.npmrc` inside the same shell step, and removes it with `trap` on exit. That limits credential exposure to the narrowest part of the pipeline that requires it.

## Improvement Implemented

The design explicitly stashes `dist`, `package.json`, and `package-lock.json` after the build. That closes the most likely handoff failure from the project brief: the publish stage needing package metadata that is not present when work is split across later stages.

## Live Validation Still Required

Use the final Jenkins run to verify three runtime-only claims:

- The Docker container can reach Nexus at the configured host URL.
- `npm test` emits JUnit XML at one of the configured report paths.
- The published tarball in Nexus uses the exact computed artifact version shown in the Jenkins log.