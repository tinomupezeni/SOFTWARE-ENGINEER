# System Errors Page 404'd on Every Request — Never Actually Reachable

**Date:** 2026-09-23 (found and fixed, same session)
**Project:** HBEC
**Environment:** Master branch, pre-deploy — found while extending the
System Errors feature (already-shipped, uncommitted since) to report
errors from Student Backend and the Agentic Harness, not just Admin
Backend
**Severity:** High — a whole admin feature (exception logging, resolve
workflow) had never worked once since it was added
**Status:** Resolved

## Summary
The System Errors feature (`SystemErrorLog` model,
`core.exceptions.custom_exception_handler`, `SystemErrorLogsView`,
`SystemErrorLogResolveView`, `SystemErrorsPage.tsx`) shipped in a prior
part of this session's work but was broken at every layer of the actual
request path:

1. `SystemErrorLogsView` and `SystemErrorLogResolveView` were defined in
   `apps/system_settings/views.py` but never added to
   `apps/system_settings/urls.py` — every request from the frontend
   404'd.
2. `REST_FRAMEWORK["EXCEPTION_HANDLER"]` (the setting that actually wires
   `custom_exception_handler` into DRF) existed only as an **uncommitted**
   local change — nothing that reached `origin/master` before this fix
   ever logged a single error, regardless of #1.
3. The frontend called `/system-settings/system-errors/...`, but the app
   is mounted at `/api/settings/` (see `config/urls.py`:
   `path("api/settings/", include("apps.system_settings.urls"))`) — wrong
   even if #1 and #2 had been fixed.

## Symptoms
Not yet reported by an end user — found while reading through the
already-pushed "Technical" nav section commits before extending the
feature cross-service, per the user's "check this out" / "read updates
that have been done" request.

## Investigation Steps

### 1. Initial Diagnosis
Traced `SystemErrorsPage.tsx`'s two `apiFetch` calls
(`/system-settings/system-errors/...`) against `config/urls.py`'s actual
mount point (`api/settings/`) — an immediate mismatch.

### 2. Root Cause Analysis
`grep -rn "SystemErrorLog\|system-errors" apps/system_settings/urls.py
config/urls.py` returned nothing for the two view names at all — they
were reachable from Python (correctly importable, correctly written) but
from no URL whatsoever.

Separately, `git diff config/settings/base.py` showed
`"EXCEPTION_HANDLER": "core.exceptions.custom_exception_handler"` as a
pending, uncommitted addition — meaning the exception handler that writes
`SystemErrorLog` rows had never actually been active on any deployed
build.

### 3. Key Findings
- Three independent gaps, each individually sufficient to make the
  feature non-functional — fixing only one would not have surfaced any
  visible errors, since the other two would still silently no-op.
- `SystemHealthView` and `AuditLogsView` (built alongside this in the
  same nav section) were correctly wired in `urls.py` — this wasn't a
  systemic pattern miss, just this one feature's views.

## Root Cause
The views, the model, and the frontend page were all written and each
individually correct, but the three pieces that connect them end-to-end
(URL registration, the DRF setting that activates the handler, and the
frontend's base path) were never actually wired together or committed.

## Prevention / Rule
**Guardrail:** a new admin API view is not "done" until a request against
the actual running dev server returns something other than 404 — writing
the view and its test is necessary but not sufficient. For a
settings-activated hook specifically (like `EXCEPTION_HANDLER`), the
setting change belongs in the *same commit* as the code it activates,
never as a separate local-only step — `git status` before every commit in
this repo should already catch an uncommitted settings change like this
one, which is exactly what caught it here.

## Solution

### Immediate Fix
- `apps/system_settings/urls.py`: added `system-errors/`,
  `system-errors/ingest/`, `system-errors/<uuid:pk>/resolve/`.
- `config/settings/base.py`: committed the `EXCEPTION_HANDLER` line.
- `SystemErrorsPage.tsx`: both `apiFetch` calls corrected to
  `/settings/system-errors/...`.

### Long-term Fix
None beyond the guardrail above — the underlying views, model, and
frontend page were already correct once actually connected.

## Verification
- Ran the full `apps/system_settings/` suite (23 tests, including 8 new
  ones added alongside a `service` field for cross-service reporting)
  against a throwaway Postgres — all passing.
- `npm run typecheck` on the admin frontend: clean.
- Full admin backend suite: 798 passed, same 4 pre-existing unrelated
  failures as the rest of this session, unchanged.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [x] Documentation to update — this entry
- [x] Code changes required — done, see Immediate Fix

## Related Issues
Found in the same investigation as
`HBEC-2026-09-23-admin-frontend-typecheck-broken-on-master.md` (separate
root cause: a missing component import and duplicated import lines in
`Sidebar.tsx`/`MobileSidebar.tsx`, unrelated to this feature specifically
but discovered in the same pass).

## References
- `ADMIN/adminBackend/apps/system_settings/urls.py`
- `ADMIN/adminBackend/apps/system_settings/views.py`
  (`SystemErrorLogsView`, `SystemErrorLogResolveView`)
- `ADMIN/adminBackend/config/settings/base.py`
- `ADMIN/adminFrontend/src/features/technical/pages/SystemErrorsPage.tsx`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Found and fixed same session, 2026-09-23.
