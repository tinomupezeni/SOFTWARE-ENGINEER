# schools_backend never actually synced imported students — missing `requests` dependency

**Date:** 2026-11-16
**Project:** HBEC
**Environment:** Development source review (confirmed by running the test
suite in a throwaway venv built from the service's own `Dockerfile`)
**Severity:** Critical
**Status:** Resolved

## Summary
`SCHOOLS/schools_backend/institutions/views.py`'s student-import path pushed
every newly created student to the student backend
(`POST /api/internal/sync-student/`) via a local `import requests as req`
inside a broad `try/except Exception: logger.exception(...)`. The
`schools_backend` `Dockerfile` never installs the `requests` package — only
`django djangorestframework django-cors-headers openpyxl Pillow
psycopg2-binary`. Every sync attempt in every environment that ran this
image raised `ModuleNotFoundError: No module named 'requests'`, which the
surrounding `except Exception` swallowed and logged. The import endpoint
always reported success (`"Successfully imported N students"`) while **no
student created through this path ever reached the student backend** — this
is the actual root cause behind what a prior pass of this audit flagged
only as "sync failures are silently logged, not surfaced."

## Symptoms
- No user-visible symptom in this session (caught during source review +
  local test execution), but the expected real-world symptom is: a school
  bulk-imports a roster, the dashboard reports every student "onboarded,"
  and none of those students can sign in on the actual student-facing
  platform, with nothing in the response indicating why.
- Confirmed directly: installing the service's own declared dependencies
  into a clean venv and importing the view module raised
  `ModuleNotFoundError: No module named 'requests'` before any test could
  even run (`manage.py test institutions` failed to import the URLconf).

## Environment Details
- **Server/Host:** Local checkout; reproduced in an isolated venv built per
  `SCHOOLS/schools_backend/Dockerfile`'s own `pip install` line — i.e. the
  same dependency set the production image would have.
- **Services Affected:** DevOps/Infrastructure (container dependency
  manifest) and, as a consequence, cross-service sync
  (`schools_backend` → `hbec-student-backend`).
- **Related Components:** `SCHOOLS/schools_backend/Dockerfile`,
  `SCHOOLS/schools_backend/institutions/views.py` (former inline import
  logic), now `SCHOOLS/schools_backend/institutions/services/
  import_service.py`.
- **Time First Observed:** 2026-11-16, while standing up a test venv to
  verify a refactor of this same import code.

## Investigation Steps

### 1. Initial Diagnosis
Ran `manage.py test institutions` in a venv with only the packages the
project's own `Dockerfile` installs, to validate test coverage for an
unrelated refactor (extracting the import logic into a shared service
module). The app failed to even import, at
`institutions/services/import_service.py:21: import requests as req`.

### 2. Root Cause Analysis
Diffed the `Dockerfile`'s `pip install` line against every top-level import
in the `institutions` app. `requests` was used (previously as a *local*
import inside the view's try block, not visible at module load) but never
declared as a dependency anywhere — not the `Dockerfile`, not any
`requirements.txt` (none exists for this service).

### 3. Key Findings
- Because the original `import requests as req` was *inside* the function,
  inside the `try`, the `ModuleNotFoundError` it always raised was caught
  by the same `except Exception as sync_err: logger.exception(...)` meant
  to catch a genuine network/HTTP failure — so the app never crashed, it
  just silently never synced, ever, in any environment running that image.
- This fully explains the "silent sync failure" behavior flagged separately
  during this session's audit: the failure wasn't occasional, it was
  guaranteed, every time, everywhere this image ran.

## Root Cause
`requests` was used by the codebase without ever being added to the one
place this service declares its dependencies (`Dockerfile`), and the
`ModuleNotFoundError` this produced was masked by a broad exception handler
written to catch network errors, not import errors.

## Prevention / Rule
**Guardrail:** Pin the dependency where it's used — `requests` is now listed
in `Dockerfile`'s `pip install` line, next to the rest of this service's
declared deps. More structurally: this service has no `requirements.txt`
and no CI job that builds its image and runs its test suite against it, so
nothing would have caught this short of the exact venv exercise done here.
Flagging as a follow-up: add a CI job for `schools_backend` equivalent to
the harness's and admin backend's test jobs, so a missing dependency fails
the build instead of surfacing as silent runtime behavior.

## Solution

### Immediate Fix
Added `requests` to `SCHOOLS/schools_backend/Dockerfile`'s `pip install`
line. The refactored `import_service.py` now imports `requests` at module
level (making an undeclared dependency loud — an import error — rather than
reachable only via a code path wrapped in `except Exception`).

### Long-term Fix
Add a CI job that builds the `schools_backend` image (or installs from a
proper `requirements.txt`) and runs `manage.py test`, so this class of gap
is caught before merge rather than by chance during an unrelated audit.

## Prevention
- [x] Dependency added to `Dockerfile`.
- [ ] Add a `schools_backend` CI job (lint + test) — does not currently
      exist in `ci.yml` for this service.
- [ ] Consider a `requirements.txt` for `schools_backend` instead of an
      inline `Dockerfile` pip-install line, for easier dependency auditing.

## Related Issues
- `HBEC-2026-11-16-school-import-job-state-machine-dead.md`
- `HBEC-2026-11-16-school-import-predictable-passwords.md`

## References
- `SCHOOLS/schools_backend/Dockerfile`
- `SCHOOLS/schools_backend/institutions/services/import_service.py`

---

**Resolved By:** Local code fix, 2026-11-16
**Time to Resolution:** Same session as discovery
