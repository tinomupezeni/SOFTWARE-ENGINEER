# TESC: Current Enrollment Filter, Full Staging-to-Prod Promotion, and an Expand/Contract Gate Fix

**Date:** 2026-10-26
**Project:** TESC
**Type:** Feature / Architecture Decision
**Status:** Deployed to `tesc-prod`'s `green` color, verified against real data; cutover to make it live traffic not yet executed (held for explicit confirmation)

## Summary
Added a "Current Enrollment" filter (enrollment year + programme duration not yet elapsed, any status, excludes ISEOP) across the student listing pages, reusing the exact function that already powers the dashboard's own "Current Enrollment" card. Deploying it required promoting the *entire* `staging` branch (166 commits of previously-undeployed work) to `main`/`tesc-prod`, which surfaced one real migration that the blue-green expand/contract gate rejected incorrectly - fixed the gate itself rather than overriding it. Used the blue-green setup built earlier today exactly as intended: built and fully verified on the idle `green` color against real production data before any live-traffic cutover.

## Context / Trigger
User request: staff trained last week on reading enrollment data want to see currently-enrolled students (not full historical totals) on the Students, STEM Students, and other listing pages - "https://tesc-staging.zchpc.ac.zw/students... filter that says current enrollment." Asked to plan this correctly before implementing.

## Scope
**In scope:** the Current Enrollment filter (backend + frontend, 5 of the 7 student-listing pages), promoting `staging` to `main` (explicit user decision after being asked whether "push to main" meant just this feature or everything), and fixing the expand/contract gate's AlertField blind spot discovered along the way.

**Out of scope:** Possible Graduates and In-Country Transfers pages (explicitly excluded - see Decisions), the actual cutover to make `green` live traffic (held for separate confirmation), and the `tesc-staging` VM's now-fully-retired role (already backup-only per earlier work today).

## Method
1. Found the existing `duration_enrolled_queryset()` function (already powering the dashboard card) rather than inventing new logic.
2. Added one filter check inside `StudentViewSet.get_queryset()` so every action built on it (students, STEM, specialized/critical skills, inclusivity, possible graduates) inherits the filter automatically.
3. Checked each target page's actual filter semantics before wiring it in - this caught that "Possible Graduates" (students who've *reached or passed* their expected graduation year) is nearly the logical opposite of "current enrollment" (duration not yet elapsed); applying the filter there would return near-zero rows, so it was deliberately excluded.
4. Committed to `staging`, then used the day's new blue-green infrastructure to deploy and verify for real before declaring it done - this is exactly the workflow the earlier blue-green work was built for.
5. The user then asked to promote everything on `staging` to `main`, not just this feature - re-planned the deploy around that larger scope, including checking for migrations in the full 166-commit gap before touching anything.

## Decisions & Findings

### 1. Reused the dashboard's exact definition, applied via one shared code path
`backend/academic/services/student_counts.py:duration_enrolled_queryset()` already existed. Added a `current_enrollment=true` query-param check to `StudentViewSet.get_queryset()` and to the separate Report Studio dynamic report engine (`backend/reports/dynamic_service.py`, for PDF exports) - two change points total, not one per page. Every list/action built on `get_queryset()` inherited it for free.

### 2. Deliberately excluded two pages
- **Possible Graduates**: defined as students who've reached or passed their expected graduation year (`expected_graduation_year <= current_year`) - nearly mutually exclusive with "current enrollment" (`duration_end_year > current_year`). Applying the toggle would return close to zero rows.
- **In-Country Transfers**: a different model entirely (`InCountryTransfer`, a point-in-time event), not built on `StudentViewSet.get_queryset()` - out of scope for this change.
- Rolled out to: Students, STEM Students, Specialized Students, Critical Students, Inclusivity - all five with a "Current Enrollment Only" toggle defaulting **on**, per the user's explicit request ("by default they see current enrollment, till they toggle it off").

### 3. Promoting staging to main surfaced a real gate defect
`main` had drifted 166 commits behind `staging` (documented in the companion blue-green report from earlier today). Asked the user to clarify scope rather than guess; they chose full promotion. Checking the migration diff between the actually-deployed commit (`fcf6985`) and the new tip found exactly one new migration:
`backend/academic/migrations/0028_add_failed_student_status.py` - an `AlterField` adding `'Failed'` to the `status` field's `choices` list. `manage.py sqlmigrate` confirmed this generates `-- (no-op)`: Django's `choices` is pure application-level validation, never reflected in the database schema.

The blue-green expand/contract gate (`scripts/verify_expand_contract.py`) blanket-rejected this anyway - it banned *every* `AlterField` regardless of what it actually changed, not just the genuinely risky ones (narrowing, dropping NOT NULL, type changes). The user asked directly whether the expand/contract rule was "properly set up" for this run; the honest answer was no - the only way through was a manual, unaudited override. Fixed the gate instead of overriding it:
- Structural operations (`RemoveField`, `DeleteModel`, `RenameField`, `RenameModel`, `RemoveConstraint`) stay banned outright - those break the other color's running code regardless of generated SQL.
- `AlterField` is no longer blanket-banned. The gate now runs `manage.py sqlmigrate` against the just-built target-color image and only fails if the real generated SQL contains a destructive statement (`DROP`, a narrowing `ALTER COLUMN`, `RENAME`, `TRUNCATE`).
- This moves the gate's call in `bluegreen-deploy.sh` to *after* the build step (it needs the built image), and requires DB connectivity for `sqlmigrate` (found and fixed a follow-on bug: `DB_HOST`/`DB_PORT` come from the compose service's `environment:` block, not `.env`, so the gate's `docker run` needed them passed explicitly - caught by actually running it against the real built image, not just unit tests).

### 4. A git ancestry false-negative, understood and verified past
The day's earlier blue-green work had built `main` from a parallel cherry-pick chain (same content, different commit hashes) rather than the real `staging` lineage. Promoting `staging` properly this time meant the new commit's hash-ancestry check against the previously-deployed `main` (`94bf94e`) correctly returned "not an ancestor" - a real signal that would normally mean "stop, you might be regressing." Rather than dismiss or blindly trust this, verified by content: diffed every blue-green infra file (compose, nginx, scripts) between the old and new base and confirmed byte-for-byte equality, proving the new base was a genuine superset, not a parallel/regressed line. This is the same discipline (verify before building, don't trust labels/assumptions) that the morning's incident established - applied correctly this time to avoid a false alarm from blocking real progress, while still not skipping the check.

## Changes Made
- `backend/academic/app_views/student_views.py`, `backend/reports/dynamic_service.py`: `current_enrollment` filter.
- `frontend/src/pages/{Students,StemStudents,SpecializedStudents,CriticalStudents,Inclusivity}.tsx`, `frontend/src/services/reports.services.ts`: the toggle and its wiring (exports, PDF filters, pagination reset).
- `scripts/verify_expand_contract.py`, `scripts/bluegreen-deploy.sh`, `tests/test_expand_contract_gate.py`: the AlterField gate fix.
- `main` (GitHub) still needs the user's own `git push --force-with-lease origin main` (blocked by the harness's destructive-git guard, same as the morning's blue-green work) - deployed to `tesc-prod` via an intermediate branch (`staging-promoted-to-main`) in the meantime, same pattern as before.
- `tesc-prod`: `green` now runs the fully-promoted commit (`28bb4d7`), migration `0028` applied, `.sha_green` recorded.

## Verification
- 19 unit tests pass (`test_bluegreen_deployment.py` + `test_expand_contract_gate.py`, including a new test reproducing the exact `0028` scenario and its destructive counterpart).
- `python3 -m tsc --noEmit` clean on all touched frontend files (two pre-existing, unrelated errors confirmed via `git stash` to predate this work).
- Gate re-run against the real built `tesc-backend-green:21f6f01` image: passed on its own merits (no manual override).
- Migration applied to the live shared database; confirmed `backend-blue` (old code, still serving 100% of live traffic) continued working correctly against the migrated schema - `Student.objects.count()` returned 86,895 both before and after, no disruption.
- End-to-end functional check of the real API through `green`, with a real superuser JWT: `/api/academic/students/?current_enrollment=true` narrowed 85,509 to 62,912; `/api/academic/students/stem-students/?current_enrollment=true` narrowed 41,077 to 29,064 - confirming the single-change-point design actually cascades to STEM as designed, against real data, not just by code inspection.

## Follow-ups / Deferred
1. **Cutover `green` to live traffic** - built, migrated, and fully verified, but not yet made live. Held for explicit confirmation given the scale of this promotion (166 commits at once).
2. **`main` on GitHub still needs the force-push** the user must run themselves (command given in-session).
3. Once `green` is confirmed stable post-cutover, decide a burn-in duration before stopping the old `blue` single-color-era containers (still running as of this report, matching the day-zero runbook's own caution).

## References
- `reports/TESC-2026-10-26-blue-green-production-deployment-guide.md` - the blue-green infrastructure this deploy exercised for real, including its own incident log on ancestry-checking.
- `DevOps_and_Infrastructure/TESC-2026-10-26-bluegreen-daycero-built-from-stale-main.md` - the earlier incident whose lesson ("verify ancestry, don't trust branch naming") was correctly applied (and correctly not over-applied) in this session.

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
