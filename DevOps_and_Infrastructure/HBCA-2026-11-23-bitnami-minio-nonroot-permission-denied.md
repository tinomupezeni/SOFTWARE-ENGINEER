# Bitnami MinIO image runs as non-root, bind mount wasn't writable

**Date:** 2026-11-23
**Project:** HBCA Classroom
**Environment:** Production (hbca-vps)
**Severity:** Medium
**Status:** Resolved

## Summary
After switching to `bitnamilegacy/minio` (see `HBCA-2026-11-23-minio-images-gone-from-docker-hub.md`), the container restart-looped: `/opt/bitnami/scripts/libminio.sh: line 370: /bitnami/minio/data/.root_user: Permission denied`.

## Symptoms
- `docker inspect` showed the container `unhealthy`, continuously restarting.
- Logs showed the same permission-denied line on every restart attempt.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** hbca-classroom-minio
- **Related Components:** `/sdb-disk/projects/hbca-classroom/data/minio` bind mount
- **Time First Observed:** 2026-11-23, manual verification pass after the image switch

## Investigation Steps

### 1. Initial Diagnosis
`docker image inspect bitnamilegacy/minio:latest --format '{{.Config.User}}'` → `1001`. The official `minio/minio` image runs as root and handles its own data-dir ownership; Bitnami's does not.

### 2. Root Cause Analysis
The bind-mounted host directory was owned by the deploy user (`winstontino`), not UID 1001, so the container's non-root process had no write access to its own data directory.

### 3. Key Findings
- This is standard Bitnami-image behavior (documented pattern across their whole catalog), not specific to MinIO.
- Official vs. Bitnami images in the same "role" can have entirely different privilege-drop behavior — a drop-in image swap is not safe to assume is actually drop-in.

## Root Cause
Host directory ownership didn't match the non-root UID the new image runs as.

## Prevention / Rule
**Guardrail:** Before swapping any container image in a production compose file for a replacement from a different vendor/maintainer, check `docker image inspect <image> --format '{{.Config.User}}'` for both the old and new image and diff them — a change from root to non-root (or vice versa) means every bind-mounted volume's host ownership needs to be re-verified, not assumed to carry over.

## Solution

### Immediate Fix
```bash
sudo chown -R 1001:1001 /sdb-disk/projects/hbca-classroom/data/minio
```

### Long-term Fix
Documented as a required step in `docs/deploy/RUNBOOK.md`'s directory-setup section, with the reasoning inline so a future host rebuild doesn't silently drop it.

## Prevention
- [x] Configuration changes needed — chown applied, documented in runbook
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- `HBCA-2026-11-23-minio-images-gone-from-docker-hub.md`

## References
- `docs/deploy/RUNBOOK.md`, step 1 (directory setup).

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~10 minutes
