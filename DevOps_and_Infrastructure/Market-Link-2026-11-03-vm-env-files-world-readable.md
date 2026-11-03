# VM Email Credential Files Were World Readable

**Date:** 2026-11-03
**Project:** Market-Link
**Environment:** Production VM redeployment preflight
**Severity:** High
**Status:** Resolved in deployed release 34274f0

## Summary
The VM's backend `.env` and `.env.bak-20261006` files had mode `664`. Both contain deployment credentials, so other local users could read them.

## Symptoms
- Credential files were readable by users outside the owner account.

## Environment Details
- **Server/Host:** `agromarket-vm`
- **Services Affected:** Backend environment and email credentials
- **Related Components:** `backend/.env`, `backend/.env.bak-20261006`
- **Time First Observed:** 2026-11-03 redeployment preflight

## Investigation Steps

### 1. Initial Diagnosis
Read file permission metadata with `stat`; did not print credential values.

### 2. Root Cause Analysis
The files were created with group and other read permission.

### 3. Key Findings
- Both files were owned by the VM deployment user.
- Docker Compose can read a mode `600` environment file as that user.

## Root Cause
Secret files were left with default shared file permissions.

## Prevention / Rule
**Guardrail:** Use mode `600` for deployment environment and backup files.

This limits local credential access to the owner.

## Solution

### Immediate Fix
Set the original and backup files to mode `600` on the VM. Preserve their values without printing or copying them off-host.

### Long-term Fix
Create future backups with a restrictive umask and keep them outside the build context.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- `DevOps_and_Infrastructure/Market-Link-2026-11-03-env-backup-in-docker-build-context.md`

## References
- VM `backend/.env`
- VM `backend/.env.bak-20261006`

---

**Resolved By:** Codex
**Time to Resolution:** Same work session

## Verification

- File mode recheck pending.

## Production deployment update (2026-11-03)

Release `34274f0` is running on `agromarket-vm`. The backend suite passed 7 tests, the frontend suite passed 3 tests, and the frontend production build succeeded. An isolated candidate run exercised buyer location signup, verification mail acceptance, farmer registration/login, product creation with image retrieval, and a password-reset mail request; its temporary database was removed. After promotion, the public homepage, API, product listing, and an existing product image returned HTTP 200. The live backend authenticated to Gmail. Inbox receipt of the test emails and the live admin journey were not independently observed.
