# Backend Environment Backup Was Included in Docker Build Context

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Production VM redeployment preflight
**Severity:** High
**Status:** Resolved in deployed release 34274f0

## Summary
The backend Docker ignore file excluded `.env` but not `.env.bak-20261006`, an untracked backup present on the VM. Dockerfile `COPY . .` could include that credential backup in a newly built image.

## Symptoms
- A production image built from the VM checkout could contain a credential backup.

## Environment Details
- **Server/Host:** `agromarket-vm`
- **Services Affected:** Backend Docker image and secrets
- **Related Components:** `backend/.dockerignore`, `backend/.gitignore`, `backend/Dockerfile`
- **Time First Observed:** 2026-11-03 redeployment preflight

## Investigation Steps

### 1. Initial Diagnosis
Inspected the VM backend directory and Docker build ignore patterns without printing environment values.

### 2. Root Cause Analysis
`backend/.dockerignore` matched the exact filename `.env`; the VM backup had a different filename and Dockerfile copied the whole context.

### 3. Key Findings
- The VM backup was untracked by Git but present in the Docker build directory.
- Uploaded files were also included in the build context.

## Root Cause
Ignore patterns covered only the primary environment filename.

## Prevention / Rule
**Guardrail:** Exclude all `.env*` files and mutable uploads from backend Docker build context; keep credential backups outside source directories.

This prevents credentials from entering images and reduces build context size.

## Solution

### Immediate Fix
Changed backend Docker ignore to `.env*`, `uploads/`, and `private-uploads/`. Updated Git ignore to cover environment backups. The backup remains on the VM but is excluded from the release image.

### Long-term Fix
Store encrypted backups outside the application source tree and verify image contents during release.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- `DevOps_and_Infrastructure/Market-Link-2026-11-03-vm-mail-url-settings-missing.md`

## References
- `backend/.dockerignore`
- `backend/.gitignore`
- `backend/Dockerfile`

---

**Resolved By:** Codex (local configuration)
**Time to Resolution:** Same work session; deployment pending

## Verification

- Release image build and exclusion check pending.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
