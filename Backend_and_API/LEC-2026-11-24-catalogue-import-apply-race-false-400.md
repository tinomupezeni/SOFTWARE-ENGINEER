# Catalogue CSV Import Can Fail Apply With a Misleading 400 Even When the Reviewed Plan Was Clean

**Date:** 2026-11-24
**Project:** LEC Biotec
**Environment:** Production (lecbiotec.com admin, `lec_api` on `chemglee-vps`).
**Severity:** High
**Status:** Resolved (message fixed; underlying race is accepted behavior, see Prevention/Rule)

## Summary

An admin reported "can't add the LEC catalogue CSV": the import screen's
"Check the file" step (dry-run plan) succeeded, but clicking Apply seconds
later on the same file returned a 400 with only "Some fields need
attention." `apply_import` deliberately re-plans from the submitted bytes
before committing (so a stale plan can never be applied), but if catalogue
state changes in the few seconds between review and Apply — most plausibly
a second photo coming to share a title the CSV names via the `images`
column — the re-plan can fail even though the plan the operator reviewed
was clean. The error message flatly said "That file has errors," which is
wrong in this case and gave the operator nothing to act on.

## Symptoms

- Admin's import screen: "Check the file" → plan looked applicable, counts
  shown, Apply enabled.
- Clicking Apply → 400, generic message, no indication anything had
  changed since the check.
- `lec_api` access log: `POST .../admin/catalogue/import` 200 (60168
  bytes) at 09:34:03, then 400 (181 bytes) at 09:34:10 — same endpoint, 7
  seconds apart, consistent with the same file being resent for Apply.

## Environment Details

- **Server/Host:** `chemglee-vps`, container `lec_api` (built 2026-11-19,
  i.e. running a build from before the first display fix below).
- **Services Affected:** `/api/v1/admin/catalogue/import`, admin
  Import/Export screen.
- **Related Components:** `apps/api/apps/catalogue/services.py`
  (`apply_import`), `apps/api/apps/catalogue/importing.py` (`plan`,
  `_photo_ids`), `apps/api/apps/catalogue/selectors.py`
  (`photos_named`), `apps/admin/src/features/catalogue/ImportScreen.tsx`.
- **Time First Observed:** 2026-11-24, reported by user; access-log entry
  is from 2026-11-24 09:34 UTC.

## Investigation Steps

### 1. Initial Diagnosis

SSH'd into `chemglee-vps`, confirmed all `lec_*` containers healthy, then
grepped `lec_api`'s access log for the import endpoint and found the
200-then-400 pair 7 seconds apart. The access log carries no response
body and the app logs no traceback for this path (it's a clean handled
400, not a crash), so the field-level reason wasn't recoverable from logs
alone.

### 2. Root Cause Analysis

Found a prior, already-committed-but-undeployed admin fix
(`54783e6`, 2026-11-20) that makes `ImportScreen.tsx` display the `fields`
dict of a structured `ApiError` instead of just its top-level `message`.
That fix alone doesn't address the underlying failure — it only makes it
visible. Deployed it (pushed to `main`, ran `./deploy.sh`) to restore
visibility in the admin, then read the backend import code:

- `apps/catalogue/services.py` `apply_import()` (L402-423): always calls
  `importing.plan(content=content)` again before committing, specifically
  so "a plan carried across a request" from a different upload can't be
  applied. If the fresh plan's `is_applicable` is False, raises
  `ValidationFailed("That file has errors...", code="IMPORT_NOT_APPLICABLE",
  fields={"rows": [...]})`
- `apps/catalogue/importing.py` `_photo_ids()`: raises if a name in the
  CSV's `images` column has no match, or more than one, in
  `selectors.photos_named()` — case-insensitive by title.
- Both the first plan (at "Check the file") and the second plan (inside
  `apply_import`) run `photos_named()` against current DB state at call
  time. Nothing pins the DB snapshot between the two HTTP requests.

### 3. Key Findings

- Reproduced directly: in
  `apps/api/apps/catalogue/tests/test_import_photos.py`, added
  `test_a_photo_renamed_to_collide_after_the_plan_fails_the_later_apply`.
  Plan a CSV naming photo "Bottle front" (dry-run) → 200,
  `is_applicable: True`. Then create a second `MediaAsset` also titled
  "Bottle front" (simulating a concurrent admin edit). Re-submit the same
  bytes with `dry_run=false` → 400 `IMPORT_NOT_APPLICABLE`, with
  `fields.rows[0]` containing "2 photos are called 'Bottle front'". Test
  passes, confirming the mechanism.
- The backend already included the actual row error in
  `fields.rows` on the 400 — the admin just wasn't displaying it before
  `54783e6`.
- SKU-code collision (case-insensitive) in the same window is the other
  plausible trigger via the same plan/re-plan pattern, not separately
  reproduced here.

## Root Cause

`apply_import`'s re-plan-before-commit (a correct defense against
applying a stale/mismatched plan) resolves photo titles (and SKU codes)
against live DB state at the moment of each HTTP call. Two sequential
calls — plan, then apply — are not atomic with each other, so any write
to `MediaAsset`/`Sku` by another admin or tab in that window can flip a
previously-clean plan into an apply-time error. The user-facing message
("That file has errors") assumed the only failure mode was a bad file,
which made a transient, state-driven failure look like a data-entry
mistake.

## Prevention / Rule

**Guardrail:** the apply-time `ValidationFailed` message now names both
possible causes (bad file *or* catalogue state changed since the check)
and tells the operator to check the file again rather than implying their
file is wrong; the admin already surfaces the specific row-level reason
(`fields.rows`) since `54783e6`. A regression test
(`test_a_photo_renamed_to_collide_after_the_plan_fails_the_later_apply`)
pins the race so a future refactor of `apply_import`/`_photo_ids` can't
silently regress the error shape.

The underlying TOCTOU (plan vs. apply against live DB state) is accepted,
not eliminated: making it atomic would mean holding a lock across two
separate HTTP requests and an operator's reading time, which is worse than
an occasional "check again." This matches how `csv_format.py`/the import
docstring already frame the re-plan as a deliberate, cheap safety check,
not a promise that nothing changes in between.

## Solution

### Immediate Fix

Deployed the already-written admin display fix (commit `54783e6`,
previously unmerged) to production: pushed `winston/LEC-fix-catalogue-
import-400` directly to `main` and ran `./deploy.sh` against
`chemglee-vps` (rebuilt `lec_api`, `lec_worker`, `lec_beat`,
`lec_biotech_ascend`; confirmed healthy post-deploy). This alone lets the
admin see the real field-level reason instead of a generic message.

### Long-term Fix

PR #66 (`winston/LEC-fix-import-apply-race-message`): reworded the
`IMPORT_NOT_APPLICABLE` message in `apply_import` and added the
regression test above. `npm run api:test` on the two catalogue-import test
files: 52/52 passed.

## Prevention

- [x] Code changes required
- [x] Regression test required
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues

- PR #66 (this fix)
- Prior unmerged admin display fix, commit `54783e6`, deployed to prod as
  part of this investigation.

## References

- `apps/api/apps/catalogue/services.py:402-423` (`apply_import`)
- `apps/api/apps/catalogue/importing.py` (`plan`, `_photo_ids`)
- `apps/api/apps/catalogue/selectors.py:175` (`photos_named`)
- `apps/admin/src/features/catalogue/ImportScreen.tsx`
- `apps/api/apps/catalogue/tests/test_import_photos.py`

---

**Resolved By:** Claude Code (session for tinotendamupezeni@thuthuka.tech)
**Time to Resolution:** ~1.5 hours across two sessions (visibility deploy + root cause + message fix)
