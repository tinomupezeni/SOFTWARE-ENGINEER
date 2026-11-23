# MinIO's own Docker Hub images no longer exist

**Date:** 2026-11-23
**Project:** HBCA Classroom
**Environment:** Production (hbca-vps, first real deploy)
**Severity:** High
**Status:** Resolved

## Summary
The blue/green compose stack's `minio`/`minio-init` services failed to pull on the very first production deploy attempt: `pull access denied for minio/minio, repository does not exist or may require 'docker login'`.

## Symptoms
- `docker compose up` failed immediately on `minio` with a pull-access-denied error, before any container started.
- Manually confirmed via Docker Hub's own API: `GET https://hub.docker.com/v2/repositories/minio/minio/` returns `{"message":"object not found"}` — the repository is simply gone, not just a missing tag.
- `quay.io/minio/minio:latest` (the commonly-cited replacement) also failed: `401 UNAUTHORIZED` even for an anonymous pull.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** hbca-classroom-minio, hbca-classroom-minio-init (object storage for the LMS)
- **Related Components:** `ops/deploy/docker-compose.production.yml`
- **Time First Observed:** 2026-11-23, first `deploy-color.sh` run via GitHub Actions

## Investigation Steps

### 1. Initial Diagnosis
Workflow log showed the pull failure immediately after a clean backend+frontend build/push, isolating it to the `minio` service specifically.

### 2. Root Cause Analysis
```bash
curl -s "https://hub.docker.com/v2/repositories/minio/minio/"
# {"message":"object not found","errinfo":{}}
docker pull quay.io/minio/minio:latest
# 401 UNAUTHORIZED
curl -s "https://hub.docker.com/v2/repositories/bitnamilegacy/minio/"
# active, publicly pullable
```

### 3. Key Findings
- MinIO discontinued free Docker Hub distribution in 2025.
- `quay.io/minio/minio` is the official successor but gates pulls (including anonymous) behind authentication now — not a drop-in replacement for a public CI pipeline.
- `bitnamilegacy/minio` (Bitnami's frozen, no-longer-updated legacy catalog) is still publicly pullable and bundles the `mc` client in the same image.

## Root Cause
Upstream vendor discontinued the image distribution channel this project's compose file depended on. Not a bug in this codebase, but an external dependency going away with no warning at the exact path this project assumed was stable.

## Prevention / Rule
**Guardrail:** Pin every third-party base image used in a production compose file by digest, not a floating tag, and record the digest alongside a one-line note of where it's verified still pullable (a comment in the compose file itself, as done here). A digest pin doesn't prevent a vendor discontinuing a repo outright, but it does mean a routine `docker pull` never silently starts resolving to a different, unverified image if a tag gets reassigned or deleted and recreated by someone else.

This doesn't fully close the gap (a deleted repository breaks a digest pin too), so the deeper mitigation is to treat any external-registry image as a drift risk worth a periodic check, the same way `alembic check` catches schema drift — there is no automated check for this today; it was caught by hand.

## Solution

### Immediate Fix
Switched `ops/deploy/docker-compose.production.yml`'s `minio` service from `minio/minio:latest` to `bitnamilegacy/minio@sha256:451fe6858cb770cc9d0e77ba811ce287420f781c7c1b806a386f6896471a349c`, and removed the separate `minio-init` service (`minio/mc` is also gone from Docker Hub) in favor of `MINIO_DEFAULT_BUCKETS`, which Bitnami's image supports natively at startup.

### Long-term Fix
None planned beyond the digest pin — `bitnamilegacy` is explicitly a frozen snapshot that will not receive updates, which is acceptable for this project's current scale but should be revisited if MinIO's security patches become a real concern.

## Prevention
- [x] Configuration changes needed — digest pin applied
- [ ] Monitoring/alerts to add — none for registry availability
- [x] Documentation to update — `docs/deploy/RUNBOOK.md` "MinIO image" section
- [x] Code changes required — compose file + removal of `minio-init`

## Related Issues
- See `HBCA-2026-11-23-bitnami-minio-nonroot-permission-denied.md` (same deploy session, directly downstream of this fix).

## References
- `docs/deploy/RUNBOOK.md` in the hbcaClassroom repo, "MinIO image" section.

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~20 minutes
