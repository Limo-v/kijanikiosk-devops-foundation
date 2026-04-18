# Security Analysis (Wednesday)

## Baseline and Improved Score

I could not put real VM numbers in this file yet, so these are the commands I planned to run and then fill output.

1. Baseline:

sudo systemd-analyze security kk-api.service

2. After adding hardening directives:

sudo systemd-analyze security kk-api.service

Final score target: below `3.0`.

## Two Additional Hardening Directives Added

### 1) `MemoryDenyWriteExecute=true`
- What I understood: it tries to stop memory being write + execute together.
- Why useful: makes code injection style attacks harder (like writing payload then running it).

### 2) `SystemCallFilter=@system-service`
- What I understood: this limits syscalls available to the service using seccomp list.
- Why useful: if process is compromised, attacker has less kernel actions available.

## Optional Additional Directives You Can Validate

- `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6`
- `LockPersonality=true`

These further reduce attack surface and usually lower score without breaking normal Node services.
I still need to confirm final score from real run, but this was the direction I used after some trial and error.
