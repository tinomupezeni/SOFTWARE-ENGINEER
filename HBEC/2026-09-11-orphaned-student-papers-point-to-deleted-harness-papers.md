# 54 Student Papers Point at Harness Papers That No Longer Exist — Bulk Resync Cannot Reach Them

**Date:** 2026-09-11
**Project:** HBEC
**Environment:** Staging (verified against production-mirrored data volume)
**Severity:** Medium
**Status:** Identified, not fixed (data cleanup — deferred to user decision)

## Summary
After merging PR #42 (content ingestion pipeline fix — one payload entry per
top-level question instead of per-leaf) and bulk re-syncing all 582 harness
papers to student successfully (`582 ok / 0 failed`), a user spot-check on a
specific staging paper
(`https://staging-student.hbca.tech/practice/01a04e97-3b65-7b13-a4a3-b1851da553b0`,
"Combined Science Paper 1 June 2020") found it still showing the old broken
pattern: 38 `PaperQuestion` rows, only 5 distinct `question_number` values,
string-lexicographic order, zero `sub_questions`, zero non-default
`order_index`.

Root cause: this paper's `harness_paper_id`
(`bb0d703e-5578-4561-a36a-c130ed6e5c4b`) does not exist in the harness's own
`papers` table — a `SELECT ... WHERE id = ...` against harness returns no
row. The bulk resync iterates *existing* harness papers and pushes each to
student; it has no way to reach a student paper whose harness source is
already gone. This is not a gap in the resync script — it is data on the
student side left over from before the harness-side paper was deleted (or
never migrated during some earlier harness data operation).

## Scale
Queried every student `Paper` row with a non-empty `harness_paper_id`
(596 of 748 total; the other 152 have no `harness_paper_id` at all — these
are `SourceType.STUDENT_GENERATED` AI papers, correctly out of scope for
this investigation) and checked each id against harness's live `papers`
table directly:

- **596 checked**
- **542 have a live harness source** (successfully covered by today's bulk
  resync)
- **54 are orphaned** — harness-side row is gone, so the fix can never reach
  them via resync

All 54 orphans have `updated_at` between 2026-08-28 and 2026-09-03 — i.e.
none were touched by today's resync (2026-09-11), confirming the mechanism:
resync only updates papers it can find a harness source for.

## Investigation Steps
1. Confirmed the flagged paper's harness-side row was missing via direct
   `asyncpg` query inside `hbec-harness-staging` (`SELECT id FROM papers
   WHERE id = 'bb0d703e-...'` → no row).
2. Searched harness `papers` by filename/subject pattern ("Combined Science
   June 2020") for a live duplicate under a different id — none found; the
   closest matches were genuinely different papers (different paper
   numbers/sessions).
3. Pulled all 596 student-side `harness_paper_id` values, wrote them to a
   temp file, copied into the harness container, and checked each against
   harness's `papers` table in one query (`WHERE id = ANY(:ids)`).
4. Cross-checked the flagged paper's id is in the resulting orphan set:
   confirmed `True`.
5. Sampled the 54 orphaned rows' titles/dates/question-counts on the
   student side — no pattern pointing to a single bad migration event; they
   span several subjects (Mathematics, Combined Science) and several dates
   in the 2026-08-28 to 2026-09-03 window.

## Root Cause
Student-side `Paper` rows carry a `harness_paper_id` FK-by-value (not an
enforced foreign key) to the harness's `papers.id`. Nothing on either side
retracts or nulls this reference when the harness-side row is deleted —
matching the same class of gap already logged in
`2026-09-10-exam-paper-delete-unpublish-never-retracts-downstream.md`, but
in the opposite direction: that entry is about admin deletions never
retracting downstream copies; this is about a downstream copy surviving
after its harness source is already gone, with no mechanism to detect or
clean it up.

## Solution

### Immediate Fix
None applied. This is stale data, not a live bug in the resync or the
ingestion pipeline — flagged for the user to decide how to handle (delete
the 54 orphaned student papers, or investigate whether the missing harness
papers should be re-uploaded/restored instead).

### Long-term Fix
- Add a periodic or on-demand consistency check: student `Paper` rows whose
  `harness_paper_id` has no matching harness `papers.id` row, surfaced in
  admin or a monitoring alert, rather than discovered ad hoc via a user
  spot-check.
- Consider whether `harness_paper_id` should become a real retraction-aware
  reference (tie into the same retraction mechanism proposed in the
  2026-09-10 `ExamPaper` entry) so a harness-side delete either cleans up or
  clearly flags the downstream orphan going forward.

## Prevention
- [ ] Monitoring/alerts to add — a scheduled check counting student papers
      with a dangling `harness_paper_id`, so this doesn't require a manual
      cross-reference query to detect again
- [ ] Documentation to update — note in the ingestion pipeline docs that
      the resync/backfill mechanism can only ever reach papers with a live
      harness source; orphaned rows need a separate remediation path
- [ ] Code changes required — none decided yet; pending user direction on
      whether to delete, restore, or otherwise resolve the 54 orphaned rows

## Related Issues
- `2026-09-10-exam-paper-delete-unpublish-never-retracts-downstream.md` —
  same underlying gap (no retraction path between admin/harness and
  student), opposite symptom (survives instead of never being removed).
- Found immediately after PR #42 (content ingestion pipeline fix, see
  `logs/tino_look_at_this.md` in the main repo) was merged, deployed to
  staging, and verified via a full 582-paper bulk resync — this issue is
  unrelated to that PR's correctness; it is a pre-existing data gap the
  bulk resync exercise happened to surface at scale.

## References
- `STUDENT/hbec_backend/apps/practice/models.py` — `Paper.harness_paper_id`
- Harness `papers` table (`AGENTIC_HARNESS`, SQLAlchemy `Paper` model)
- Flagged paper: student id `01a04e97-3b65-7b13-a4a3-b1851da553b0`, harness
  id `bb0d703e-5578-4561-a36a-c130ed6e5c4b` (missing)

---

**Resolved By:** Claude (Sonnet 5), investigation only — not yet fixed
**Time to Resolution:** N/A (identified only, awaiting user decision on cleanup)
