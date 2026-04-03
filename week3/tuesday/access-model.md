# Tuesday Access Model

This access model enforces least privilege while still allowing service interoperability where required.

| Path | Owner:Group | Mode | Access Intent | Why This Choice |
|---|---|---|---|---|
| `/opt/kijanikiosk/api/` | `kk-api:kk-api` | `750` | API service full access, no cross-service read | API code should not be readable or writable by unrelated services |
| `/opt/kijanikiosk/payments/` | `kk-payments:kk-payments` | `750` | Payments service full access, isolated from API/logs | Payments runtime and artifacts should stay private to payments |
| `/opt/kijanikiosk/logs/` | `kk-logs:kk-logs` | `750` | Log aggregator full access only | Prevents accidental reads of internal log pipeline state |
| `/opt/kijanikiosk/config/` (dir) | `root:kijanikiosk` | `750` | Controlled traversal for trusted service identities | Root owns secrets; group traversal allows intended readers |
| `/opt/kijanikiosk/config/*.env` | `root:kijanikiosk` | `640` | Read-only secrets for approved services | Blocks write tampering and world-readable credential leakage |
| `/opt/kijanikiosk/shared/logs/` | `kk-logs:kk-logs` | `2770` | Shared operational log handoff with SGID inheritance | SGID keeps group-consistent file ownership for collaborative access |

## ACL Decisions

### `/opt/kijanikiosk/shared/logs/`
- `u:kk-api:rwx`: API must write application logs.
- `u:kk-payments:rx`: Payments must read shared logs for correlation/audit.
- `u:kibet:rx`: Operator account can inspect logs without root shell.
- Default ACLs should mirror these entries to preserve access after new file creation.

### `/opt/kijanikiosk/config/`
- `u:kibet:rx` on directory and `u:kibet:r--` for files.
- Rationale: operations/user troubleshooting can read configuration values when needed, but cannot alter them.

## Why ACLs Instead of Modes Alone

Traditional UNIX mode bits only give one owner and one group path for access decisions. We have multiple distinct principals that need different rights on the same path (`kk-api` write, `kk-payments` read, operator read), so ACLs are used to express that matrix without over-broad group write access.
