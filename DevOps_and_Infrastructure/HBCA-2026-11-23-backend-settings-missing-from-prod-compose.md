# Production compose file never set several required backend settings

**Date:** 2026-11-23
**Project:** HBCA Classroom
**Environment:** Production (hbca-vps, first real deploy)
**Severity:** High
**Status:** Partially resolved (app boots; two values are documented placeholders)

## Summary
The backend container crash-looped on startup with a `pydantic` validation error: `S3_PUBLIC_URL`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET`, and `LIVEKIT_PUBLIC_URL` were all required by `app/config.py`'s `Settings` with no default, but the production compose file never set any of them.

## Symptoms
- Backend container exited immediately with a `pydantic_core.ValidationError: 5 validation errors for Settings`.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** hbca-classroom-backend
- **Related Components:** `backend/app/config.py`, `ops/deploy/docker-compose.production.yml`
- **Time First Observed:** 2026-11-23, manual verification pass

## Investigation Steps

### 1. Initial Diagnosis
`docker logs` printed the full pydantic validation error naming every missing field directly — no guesswork needed.

### 2. Root Cause Analysis
The production compose file was written from the dev `docker-compose.yml`'s backend environment block from memory/pattern-matching rather than cross-checked field-by-field against the actual `Settings` class, and missed the S3-aliasing convention (`S3_ACCESS_KEY`/`S3_SECRET_KEY`/`S3_BUCKET` sourced from the same `MINIO_*` values, not duplicated as new secrets) and the LiveKit public-URL field entirely.

### 3. Key Findings
- The dev compose file already has the correct aliasing pattern (`S3_ACCESS_KEY: ${MINIO_ROOT_USER}` etc.) — it should have been copied directly rather than re-derived.
- `S3_PUBLIC_URL` and `LIVEKIT_PUBLIC_URL` have no real answer yet in production: MinIO has no public Caddy route, and LiveKit isn't started. Both are set to a placeholder (`https://lms.hbca.tech` / `wss://lms.hbca.tech`) purely so the app can boot — file upload/download and realtime classroom are not yet verified working in production.

## Root Cause
A new compose file copied the shape of an existing one without verifying its environment variables against the actual settings schema it configures.

## Prevention / Rule
**Guardrail:** Before trusting a new or copied compose file's environment block, grep the actual `Settings`/config class for every field with no default and confirm each one is set somewhere in the compose file (or deliberately and visibly left as a documented placeholder). This is a 30-second check that would have caught all five missing fields at once, rather than one `pydantic` crash loop at a time.

## Solution

### Immediate Fix
Added all five fields to `ops/deploy/docker-compose.production.yml`'s backend environment block, aliasing the S3 ones from the existing `MINIO_*` values per the dev compose file's own pattern.

### Long-term Fix
`S3_PUBLIC_URL` and `LIVEKIT_PUBLIC_URL` need real Caddy routes + DNS before file storage and realtime classroom features can be trusted in production — tracked in `docs/deploy/RUNBOOK.md`'s "Known gaps" section, not solved here.

## Prevention
- [x] Configuration changes needed — all five fields added
- [ ] Monitoring/alerts to add
- [x] Documentation to update — RUNBOOK "Known gaps"
- [ ] Code changes required — the two placeholder values need real infrastructure work, not code

## Related Issues
- None directly, but see the LiveKit/webhook routing work in the same deploy effort (`ops/deploy/docker-compose.production.yml`'s livekit service comments).

## References
- `backend/app/config.py`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~15 minutes (app boots); placeholders still open
