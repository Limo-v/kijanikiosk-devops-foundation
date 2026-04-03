# Tuesday Access Model

I tried to keep this least privilege, but still make services work together where needed. Not perfect, but this was my best attempt.

| Path | Owner:Group | Mode | Access Intent | Why This Choice |
|---|---|---|---|---|
| `/opt/kijanikiosk/api/` | `kk-api:kk-api` | `750` | API can use own folder | stop other services browsing it |
| `/opt/kijanikiosk/payments/` | `kk-payments:kk-payments` | `750` | Payments isolated | payment files should not be open to all |
| `/opt/kijanikiosk/logs/` | `kk-logs:kk-logs` | `750` | logs service owns this | keep log pipeline separate |
| `/opt/kijanikiosk/config/` (dir) | `root:kijanikiosk` | `750` | allow allowed users to traverse | root still owns secrets |
| `/opt/kijanikiosk/config/*.env` | `root:kijanikiosk` | `640` | read only for right accounts | avoid everyone reading passwords |
| `/opt/kijanikiosk/shared/logs/` | `kk-logs:kk-logs` | `2770` | shared logs place | SGID helps group inheritance |

## ACL Decisions

### `/opt/kijanikiosk/shared/logs/`
- `u:kk-api:rwx` so api can write logs
- `u:kk-payments:rx` so payments can read for checks
- `u:kibet:rx` so I can inspect without sudo all the time
- default ACL same idea so new files are not broken later

### `/opt/kijanikiosk/config/`
- `u:kibet:rx` on dir and `u:kibet:r--` on files
- this is for troubleshooting mostly, but no writing

## Why ACLs Instead of Modes Alone

Normal chmod bits were not enough for me because we needed mixed access on same folder (one user write, another read, plus operator read). ACL felt easier for that part even if it took me some retries and mistakes first.
