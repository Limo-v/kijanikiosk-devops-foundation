# Security Analysis (Wednesday)

## Baseline and Improved Score

This deliverable is prepared in repository-only mode. Run these on the VM and paste real output:

1. Baseline:

sudo systemd-analyze security kk-api.service

2. After adding hardening directives:

sudo systemd-analyze security kk-api.service

Final score target: below `3.0`.

## Two Additional Hardening Directives Added

### 1) `MemoryDenyWriteExecute=true`
- Kernel-level effect: enforces W^X behavior on anonymous memory mappings by denying pages that are writable and executable at the same time.
- Attack class blocked: JIT spray / runtime shellcode staging where attacker-controlled bytes are written then executed from the same region.

### 2) `SystemCallFilter=@system-service`
- Kernel-level effect: limits the syscall surface by applying seccomp filters, so disallowed kernel entry points return an error instead of executing.
- Attack class blocked: syscall-based post-exploitation chains that rely on broad kernel interfaces (for example arbitrary namespace/mount/process-control operations from a compromised service process).

## Optional Additional Directives You Can Validate

- `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6`
- `LockPersonality=true`

These further reduce attack surface and usually lower the score without breaking standard Node-based services.
