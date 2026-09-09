# Admin's Multi-Variant Batch Generation Was Structurally Broken on the Harness Side

**Date:** 2026-09-09
**Project:** HBEC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
Admin's `paper_count` batch feature (generate N variants of the same
official paper number) worked for the *first* variant of any batch and
deterministically failed for every variant after it — not a race condition,
a structural schema gap confirmed on two separate real batches.

## Symptoms
- In a batch of 5 or 10 papers requesting the same `paper_number`, the
  first variant always saved successfully; every subsequent one failed with
  `duplicate key value violates unique constraint "uq_paper_identity"`.

## Environment Details
- **Server/Host:** hbca-vps (staging)
- **Services Affected:** Agentic Harness (`Paper` model), Admin Backend (`GenerateAIPaperView`)
- **Time First Observed:** 2026-09-09, clearing a real stuck batch backlog

## Investigation Steps

### 1. Initial Diagnosis
Confirmed via harness logs: generation succeeded for the failing papers too
(`llm_call_success` with real token counts) — the failure was purely at
save time, on a database constraint.

### 2. Root Cause Analysis
The harness's `Paper` table's uniqueness was `(subject, level, paper_number,
year, session)` — no column at all for "which variant of this number".
Admin's own `ExamPaper` model (Django) already had a real `variant` field,
but `GenerateAIPaperView`'s batch loop hardcoded `variant="1"` for every
paper regardless of loop position, and the payload sent to the harness
never included `variant` at all — so even a correctly-variant-tagged
`ExamPaper` had no way to communicate that to the harness's save.

### 3. Key Findings
- This was a two-sided gap, not a single bug: Django never assigned real
  per-batch variants, and the harness had nowhere to put one even if it had.
- The same identity tuple is *also* used by the harness's own
  admin-content replication receiver (`replication_handlers.py`) when a
  reviewed/published paper syncs from Django into the harness's corpus —
  meaning this bug would have resurfaced at publish time even for a
  correctly-fixed generation path, if only fixed on one side.

## Root Cause
The harness's `Paper` table had no `variant` concept, and Django never
generated or transmitted a real one — two independent gaps that together
made any `paper_count > 1` request fail past its first variant, every time.

## Solution

### Immediate Fix
Manually corrected `variant` and re-triggered generation for the specific
papers caught by this bug across two real batches (5 and 10 papers).

### Long-term Fix
- Harness: added a real `variant` column to `Paper` (Alembic migration),
  folded into `uq_paper_identity` alongside the existing five fields.
  Default `"1"` keeps every already-published paper's identity unchanged.
- Harness: `AdminPaperGenerateRequest`, `PaperUploadRequest`, and
  `PaperManualEntry` all carry `variant` (default `"1"`, so PDF upload and
  single manual entry are unaffected); threaded through
  `generate_admin_paper` → `PaperManualEntry` → `store_paper` → `Paper`.
- Harness: the admin-content replication receiver now reads and sets
  `variant` too, on both its create and update paths.
- Django: `GenerateAIPaperView` assigns `variant=str(i+1)` instead of a
  hardcoded `"1"`, and includes it in the payload dispatched to the harness.
  The paper-published replication payload (`apps/replication/signals.py`)
  now includes `variant` too — it never had.
- 7 new tests across both services.

## Prevention
- [x] Real `variant` identity with test coverage on both sides
- [ ] Consider a cross-service contract test that fails if a field added to
      one side's identity tuple isn't mirrored on the other

## Related Issues
- Directly connected to the wrong-subject-resolution bug (same debugging
  session, same feature, discovered back to back on real batches)

## References
- `AGENTIC_HARNESS/alembic/versions/033_add_paper_variant.py`
- `AGENTIC_HARNESS/app/shared/models/papers.py`
- `AGENTIC_HARNESS/app/admin/replication_handlers.py`
- `ADMIN/adminBackend/apps/exam_papers/views.py`
- `ADMIN/adminBackend/apps/replication/signals.py`
- Commit `d5e53474`

---

**Resolved By:** Claude (Sonnet 5), pairing with Tinotenda Mupezeni
**Time to Resolution:** Same session
