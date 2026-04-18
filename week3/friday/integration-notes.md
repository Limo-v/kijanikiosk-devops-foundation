# Integration Notes (Friday)

These notes describe where requirements conflicted and what choice I made.

## Challenge A: ProtectSystem=strict vs Environment File Readability

### Conflict
Tighter filesystem protection can break service startup if runtime configuration files are not reachable/readable by the service account.

### Options considered
1. Move config to another place with weaker restrictions.
2. Keep strict protection and use explicit readable config path + ownership/mode controls.

### Decision
I kept strict filesystem protection and standardized config under `/opt/kijanikiosk/config/` with controlled ownership (`root:kijanikiosk`) and read rights for required service users.

### Why
This keeps hardening benefits while avoiding hidden startup failures caused by unreadable environment files.

## Challenge B: Health JSON Ownership and Monitoring Access

### Conflict
Health JSON is created by provisioning path but must be readable by monitoring and ops without full root access.

### Options considered
1. Leave root ownership and rely on sudo for reads.
2. Introduce a dedicated health directory ownership model with group-readable file.

### Decision
I added `/opt/kijanikiosk/health/` to access model with `kk-logs:kijanikiosk`, directory mode `750`, and file mode `640`.

### Why
This keeps write control tight while still enabling normal read access for monitoring/ops workflows.

## Challenge C: logrotate Postrotate with Service Hardening

### Conflict
A traditional reload action can fail if the service does not expose a reload action.

### Options considered
1. Use reload directly and accept failures.
2. Use a signal-based approach that does not rely on explicit reload support.

### Decision
I used a postrotate signal call to request handle refresh from the log service process.

### Why
It is safer for mixed service implementations and avoids hard-failing rotation when reload is unsupported.

## Challenge D: Dirty VM Package Drift vs Pinning

### Conflict
Pinned installs on an already-used VM can trigger downgrades or unpredictable state changes.

### Options considered
1. Auto-downgrade silently to target version.
2. Fail loudly on detected version drift and require manual review.

### Decision
I chose fail-loud behavior on version drift for pinned packages.

### Why
This prevents silent package churn on a production-like node and forces explicit operator decision when reality differs from intended baseline.
