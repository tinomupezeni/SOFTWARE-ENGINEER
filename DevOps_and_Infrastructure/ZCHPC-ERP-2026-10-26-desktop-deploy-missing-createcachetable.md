# Desktop/manual deployment path missing createcachetable for new DB-backed throttle cache

**Date:** 2026-10-26
**Project:** ZCHPC-ERP
**Environment:** Development/Production (desktop deployment path)
**Severity:** High
**Status:** Investigating (found during code review of open PR #120, not yet merged/fixed)

## Summary
PR #120 ("Use database cache for shared throttle state") switches Django's
default cache backend to `DatabaseCache` so login/recruitment throttle
counters are shared across workers instead of living in per-process memory.
The PR adds `python manage.py createcachetable` to `erp_project/entrypoint.sh`
(the Docker path) but not to `erp_project/desktop_entrypoint.py`, which only
runs `migrate --noinput`. `docs/DEPLOYMENT.md`'s manual setup steps (around
lines 166 and 599) also don't mention `createcachetable`.

## Symptoms
- Not yet observed in production — caught during review before merge.
- Expected symptom if merged as-is: any environment provisioned via
  `desktop_entrypoint.py` or the manual `docs/DEPLOYMENT.md` steps will 500
  on the first login attempt with "no such table: django_cache", since
  `DatabaseCache` requires the table to exist and nothing creates it outside
  the Docker entrypoint.

## Environment Details
- **Server/Host:** Desktop/local deployments and any manual install following
  `docs/DEPLOYMENT.md`, as opposed to the Docker Compose path.
- **Services Affected:** Login throttling (`LoginRateThrottle`), recruitment
  throttles (`RecruitmentApplyThrottle` etc.) — anything using Django's
  default cache.
- **Related Components:** `erp_project/desktop_entrypoint.py`,
  `erp_project/entrypoint.sh`, `docs/DEPLOYMENT.md`.
- **Time First Observed:** Found during PR review, 2026-10-26.

## Investigation Steps

### 1. Initial Diagnosis
Reviewing PR #120's diff showed `CACHES["default"]["BACKEND"]` changed to
`django.core.cache.backends.db.DatabaseCache`, and `createcachetable` was
added only to `entrypoint.sh`.

### 2. Root Cause Analysis
Checked every known startup/provisioning path for the table-creation step.

```bash
grep -rn "createcachetable" erp_project/
grep -n "migrate\|createcachetable" erp_project/desktop_entrypoint.py
grep -n "createcachetable\|migrate" docs/DEPLOYMENT.md
```

### 3. Key Findings
- `erp_project/desktop_entrypoint.py:15` runs only
  `execute_from_command_line([sys.argv[0], 'migrate', '--noinput'])` — no
  `createcachetable`.
- `docs/DEPLOYMENT.md` manual `migrate` steps (lines 166, 599) have no
  `createcachetable` step either.
- This was independently flagged by reviewer @richardmatsika-c on PR #120
  before this review pass; confirmed accurate via the greps above.

## Root Cause
The fix for shared throttle state (`DatabaseCache`) was wired into exactly
one of the project's startup paths (`entrypoint.sh`, Docker). Since Django's
`createcachetable` is a manual step with no migration-equivalent auto-run
mechanism, every other provisioning path (`desktop_entrypoint.py`, manual doc
steps) silently drifted out of sync with the new requirement.

## Prevention / Rule
**Guardrail:** Add an app-startup check (e.g., in Django's `AppConfig.ready()`
or a `system check` (`django.core.checks`)) that verifies the cache table
named in `CACHES["default"]["LOCATION"]` exists when the backend is
`DatabaseCache`, and fails fast with a clear message instead of surfacing a
500 on first throttled request. This closes the gap permanently, independent
of how many entrypoints/docs exist, because it validates the actual runtime
precondition rather than relying on every provisioning script being updated
in lockstep.

## Solution

### Immediate Fix
Not yet applied — PR #120 is open with CHANGES_REQUESTED. Recommended fix
posted as a PR comment: add `python manage.py createcachetable` to
`erp_project/desktop_entrypoint.py` alongside the existing `migrate` call,
and update `docs/DEPLOYMENT.md`'s manual steps to include it.

### Long-term Fix
Implement the system-check guardrail described above so any future
provisioning path automatically surfaces the missing-table condition at
startup instead of at first throttled login.

## Prevention
- [ ] Add `createcachetable` to `desktop_entrypoint.py`
- [ ] Update `docs/DEPLOYMENT.md` manual steps
- [x] Documentation to update (this entry)
- [ ] Add Django system check for DatabaseCache table existence

## Related Issues
- GitHub PR: https://github.com/tinomupezeni/ZCHPC-ERP/pull/120
- Prior reviewer comment (same finding): https://github.com/tinomupezeni/ZCHPC-ERP/pull/120#discussion_r4374574644

## References
- PR #120 diff, `erp_project/entrypoint.sh` vs `erp_project/desktop_entrypoint.py`

---

**Resolved By:** Found by Tinotendamupezeni (via Claude Code review) and reviewer richardmatsika-c
**Time to Resolution:** Not yet resolved — open PR, changes requested
