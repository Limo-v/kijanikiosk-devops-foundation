# Tuesday Lab: Deployment Script Testing Notes

## Setup
- Staging VM: Ubuntu 22.04 LTS
- Blue on port 3000 (v1.3.0), Green on port 3001 (v1.4.0)
- Artifact server: `python3 -m http.server 8080` pointing at `/opt/kijanikiosk/releases/`

## Phase Tests

### Phase 1: Fetch
```bash
APP_VERSION=v1.4.0 DEPLOY_ENV=green \
  ARTIFACT_BASE_URL=http://127.0.0.1:8080 \
  bash -x scripts/deploy-app.sh 2>&1 | grep "Phase 1"
```
**Result:** ✓ PASS — downloaded `kk-api-v1.4.0.tar.gz` (1,240 bytes). On second run it detected the file already existed and skipped the download.

### Phase 2: Validate
**Result:** ✓ PASS — `tar -tzf` confirmed the archive was intact and contained server.js and package.json.

### Phase 3: Deploy
**Result:** ✓ PASS — 2 files extracted to `/opt/kijanikiosk/green/app/`. Version marker written: `v1.4.0`.

### Phase 4: Restart
**Result:** ✓ PASS — `kk-api-green.service` restarted cleanly. `systemctl is-active` returned `active` after 2 seconds.

### Phase 5: Verify
**Result:** ✓ PASS — health check on port 3001 returned HTTP 200 with `"version":"v1.4.0"` in the response. Retry logic wasn't needed since the service came up quickly.

## Full Deployment Test

```bash
# Pre-state: blue active, green stopped
systemctl is-active kk-api-blue.service   # active
curl http://127.0.0.1:3000/health         # v1.3.0

# Run full script
APP_VERSION=v1.4.0 DEPLOY_ENV=green \
  ARTIFACT_BASE_URL=http://127.0.0.1:8080 \
  sudo -E bash scripts/deploy-app.sh
```

Exit code: 0. All five phases ran in order. After completion:

```bash
curl http://127.0.0.1:3000/health   # still v1.3.0
curl http://127.0.0.1:3001/health   # now v1.4.0
```

Blue was untouched throughout. That was the main thing I wanted to confirm — deploying to green doesn't affect blue.

## Idempotency

Ran the script twice with the same version. Second run used the cached artifact and still exited 0. Service restarted cleanly both times with the same health check result.

## Error Cases I Tested

| Test | Result |
|------|--------|
| `DEPLOY_ENV=green` with no `APP_VERSION` | Exit 1, "APP_VERSION not set" |
| `DEPLOY_ENV=staging` | Exit 1, "must be 'blue' or 'green'" |
| Artifact server not running | Exit 1, "Failed to fetch artifact" |
| Manually corrupted tar.gz | Exit 1, "not a valid tar.gz file" |

## Notes

One thing that tripped me up early: `sudo -E` is needed to pass the environment variables into the script when running as root. Without it, `APP_VERSION` is empty inside the script and it fails immediately. I should add a note about this in the README.

The retry loop in Phase 5 (up to 10 attempts, 1 second apart) wasn't needed in practice — the service came up in under 2 seconds. But it's good to have it there for slower VMs.

## Next Steps (Wednesday)

Green is deployed and healthy on port 3001. Wednesday adds `switch-env.sh` to actually redirect nginx traffic from blue to green.
