# Access Model Final (Friday)

I reused Tuesday model and updated it for Friday integration issues (health directory + logrotate behavior).

| Path | Owner:Group | Mode | Why this setting |
|---|---|---|---|
| `/opt/kijanikiosk/api/` | `kk-api:kk-api` | `750` | API files should stay private to API user/process |
| `/opt/kijanikiosk/payments/` | `kk-payments:kk-payments` | `750` | Payments workload isolated from other services |
| `/opt/kijanikiosk/logs/` | `kk-logs:kk-logs` | `750` | Keeps log service files scoped to log service |
| `/opt/kijanikiosk/config/` | `root:kijanikiosk` | dir `750`, files `640` | Secrets stay root-owned, selected readers through group/ACL |
| `/opt/kijanikiosk/shared/logs/` | `kk-logs:kk-logs` | `2770` | Shared log zone with SGID for stable group inheritance |
| `/opt/kijanikiosk/health/` | `kk-logs:kijanikiosk` | dir `750`, file `640` | Health JSON is writable by provisioning path and readable by monitoring/operator group |

## ACL Details Used

### shared/logs ACLs
- `u:kk-api:rwx` on directory, default `u:kk-api:rw-` for new files.
- `u:kk-payments:r-x` on directory, default `u:kk-payments:r--` for new files.
- `u:kk-logs:rwx` on directory, default `u:kk-logs:rw-` for new files.
- `g:kijanikiosk:r--` as default read baseline.
- ACL mask pinned with `m::rwx` to avoid effective-rights collapse.

### config ACLs
- Operator user gets read-only access for troubleshooting.
- No write ACL granted outside root ownership.

## Logrotate Interaction Notes

Big lesson: `create` in logrotate sets owner/mode but does not replace ACL inheritance logic. The directory default ACLs are what make new rotated files keep intended read/write behavior across services. Because of that, final verification includes:
1. forced rotation,
2. listing resulting files,
3. ACL check,
4. definitive write test:

```bash
sudo -u kk-api touch /opt/kijanikiosk/shared/logs/test-write.tmp \
  && echo "PASS: kk-api can write after logrotate" \
  || echo "FAIL: kk-api cannot write to shared/logs"
```

If that test fails, access model is not stable after rotation.
