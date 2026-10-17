# TESC startup logs duplicate-admin traceback during production recreation

**Date:** 2026-10-17
**Project:** TESC
**Environment:** Production
**Severity:** Medium
**Status:** Investigating

## Summary
During production recreation of the verified staging backend image, the
container started successfully and did not enter a restart loop, but
`startup.sh` logged a Django `IntegrityError` while attempting to create the
seed admin. The script checks only whether `admin@tesc.ac.zw` exists, then
tries to create `username="admin"`. Production already has username `admin`
with a different email, so the unique username constraint rejects the insert.
The error is currently suppressed by `|| true`, allowing Gunicorn to start.

## Symptoms
- Production backend startup logs contain a traceback ending in:
  `psycopg2.errors.UniqueViolation: duplicate key value violates unique
  constraint "users_customuser_username_key"`.
- The backend and worker remain running with restart count `0`.
- API pagination smoke verification and the public frontend remained healthy.

## Environment Details
- **Server/Host:** Production TESC VM, `10.50.200.35`
- **Services Affected:** `tesc-main-backend-1` startup initialization
- **Related Components:** `/app/startup.sh`, `users_customuser.username`
- **Time First Observed:** 2026-10-17 during pagination image promotion

## Investigation Steps

### 1. Initial Diagnosis
Scanned the deployment-window backend logs after recreating the backend from
the verified staging image.

### 2. Root Cause Analysis
Inspected the running startup script and existing admin record:

```bash
nl -ba /app/startup.sh
# if not User.objects.filter(email="admin@tesc.ac.zw").exists():
#     User.objects.create_superuser(..., username="admin")

CustomUser.objects.filter(username="admin").values(
    "id", "email", "is_active", "is_superuser"
)
# [{'id': 33, 'email': 'admin@scalareye.com', ...}]
```

The email-based existence test does not cover the unique username already
present in the database. The heredoc is followed by `|| true`, so the
integrity error is hidden and startup proceeds.

### 3. Key Findings
- This is an initialization/logging defect, not a crash loop in the current
  deployment.
- The production student pagination API and frontend remained healthy after
  the traceback.
- The same startup logic is present in the exact staging image that was
  promoted; correcting it requires a separate image change and staging
  verification.

## Root Cause
The seed-admin bootstrap condition checks only the configured email but creates
a fixed unique username. Existing production data contains that username under
a different email, causing a duplicate-key error. `|| true` masks the failure.

## Prevention / Rule
**Guardrail:** make startup admin bootstrap idempotent by resolving the existing
user by both configured email and configured username before creation, and add a
container-start test that runs against a database containing an existing
different-email `admin` username and asserts no traceback.

## Solution

### Immediate Fix
No startup-script change was made during this deployment. The service remains
healthy, and the current image is retained because it is the verified staging
artifact for the requested pagination fix.

### Long-term Fix
Update the bootstrap logic to:
- treat an existing username as an existing seed-admin identity;
- avoid attempting a conflicting insert;
- remove the `|| true` suppression from the bootstrap command;
- add a regression test for email/username mismatch.

## Prevention
- [ ] Configuration changes needed — none.
- [ ] Monitoring/alerts to add — fail deployment verification on unexpected
      startup tracebacks.
- [ ] Documentation to update — record seed-admin identity assumptions.
- [ ] Code changes required — make bootstrap idempotent and test it.

## Related Issues
- Earlier production startup/bootstrap investigation associated with commit
  `13b5ebc`.

## References
- `/app/startup.sh` in `tinotenda762/tesc-backend:latest`
- `backend/core/settings.py`
- `users_customuser.username` unique constraint

---

**Resolved By:** Copilot
**Time to Resolution:** Observed during deployment; corrective work deferred
