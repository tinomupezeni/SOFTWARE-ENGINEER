# Harness's Adopted-Paper Cache Never Refreshes — 21 of 23 Papers Had Every Question ID Stale, Causing "Question Not Found" 404s on Marking

**Date:** 2026-09-30
**Project:** HBEC
**Environment:** Production
**Severity:** Critical (live, affecting every student attempting any of 21
actively published papers)
**Status:** Resolved (production)

## Summary
A student reported: submitting an answer for marking returned a 404, with
the app's own fallback message ("Your answer is saved — you can try
marking it again from the review screen"). Traced via the 5 Whys method at
the user's request. Root cause: the Agentic Harness "adopts" (locally
caches) a paper the first time any student attempts it, but **never
re-validates or refreshes that cache** against the Student Backend. On
2026-09-11, a content-ingestion pipeline fix (PR #42) bulk-regenerated
`PaperQuestion` rows for a large batch of papers on the Student Backend
(new UUIDs, old rows deleted) — but every paper the Harness had already
adopted *before* that date kept its stale, pre-reingest question IDs
forever. Cross-checking all 23 papers the Harness had ever adopted against
the Student Backend's current data found **21 with every single adopted
question ID missing** from the current set — not degraded, total mismatch.
All 21 are `status: published`, spanning Mathematics, Combined Science,
English, History, Computer Science and more. Any student submitting any
question on any of these 21 papers got this exact 404, for every student,
on every question, since 2026-09-11.

## Symptoms
- User-facing: "Couldn't mark that one" / "Question not found" via a 404
  from `POST /papers/{paper_id}/questions/{question_id}/submit` (or, for
  papers still holding a small number of correct-looking-but-stale IDs, the
  same failure surfacing through the async marking-job poll instead).
- No error logged at INFO level on the Harness for this — `HTTPException`
  404s here aren't captured by the request logger's error path, so this
  had zero log visibility despite affecting every student on 21 live
  papers for three weeks. Found entirely through direct DB cross-checking,
  not log grepping.

## Environment Details
- **Server/Host:** production (`hbec-harness-db`, `hbec-postgres` /
  `hbec-student-backend`)
- **Services Affected:** Agentic Harness (`exam_practice` pillar), any
  student attempting one of the 21 affected papers
- **Related Components:** `app/exam_practice/services/paper_adoption.py`
  (`adopt_paper`, `get_or_adopt_paper`), `app/exam_practice/router.py`
  (`submit_answer`'s synchronous question-existence check)
- **Time First Observed:** 2026-09-30 (user report); root cause dates to
  2026-09-11

## Investigation Steps — the 5 Whys

**1. Why did the student get a 404 "Question not found" while submitting?**
The Harness's `submit_answer` endpoint runs a synchronous existence check —
`Question.id == question_id AND Question.paper_id == paper_id`
(`router.py:628-632`) — against its own database, before starting the
marking job. No row matched.

**2. Why did the Harness have no matching row, when the Student Backend
clearly has that exact question?**
The Harness only marks against papers in its own DB. A paper it has never
seen is pulled once, on first attempt, via `get_or_adopt_paper` →
`adopt_paper`. But `get_or_adopt_paper` short-circuits the moment a local
row exists:
```python
paper = await db.get(Paper, paper_id)
if paper is not None:
    return paper
return await adopt_paper(db, paper_id, student_id)
```
Confirmed via direct DB query: the Harness adopted the two papers traced in
detail on **2026-08-18/19** (decoded from the UUIDv7 timestamps embedded in
its stored question IDs).

**3. Why doesn't the Harness's cached copy match the Student Backend's
current questions?**
On **2026-09-11**, a content-ingestion pipeline fix (PR #42 — "one payload
entry per top-level question instead of per-leaf") bulk-regenerated
`PaperQuestion` rows for a large batch of papers on the Student Backend —
old rows deleted, new ones inserted with fresh UUIDs. Confirmed: the
Student Backend's current question IDs for these same papers all decode to
**2026-09-11T09:10:21Z** — the exact reingest moment. This is the same
event `HBEC-2026-09-11-orphaned-student-papers-point-to-deleted-harness-papers.md`
was filed about, the same day.

**4. Why wasn't the Harness told, or its stale copy invalidated, when the
Student Backend's questions changed?**
There is no retraction/invalidation channel from Student Backend → Harness
for an already-adopted paper. `get_or_adopt_paper` is a one-way, one-time
pull with no re-validation, ever. The 09-11 entry already diagnosed this
exact class of gap for the mirror-image symptom (a whole paper deleted
upstream, harness row orphaned) and explicitly recommended the general fix:
"a scheduled consistency check... run on the same cadence as the bulk
resync."

**5. Why did that already-known, already-recommended guardrail never get
built, letting the sibling bug reach production and a real user three
weeks later?**
The 09-11 entry's fix addressed that day's specific 54 orphaned rows, on
staging only — its own checklist left "Monitoring/alerts to add" and the
scheduled consistency check unchecked, and the entry says outright "not
yet applied to production." The reusable mechanism it called for was never
built; only that day's symptom was cleaned up. The underlying architecture
— **adopt once, trust forever, no way to detect drift** — stayed exactly
as broken as it was on 2026-09-11, just waiting for the next reingest or
the next student to notice.

## Root Cause
The Harness's paper-adoption design assumes upstream (Student Backend)
content is immutable once adopted. Nothing on either side detects,
notifies, or reconciles when that assumption breaks. The 2026-09-11
reingest was the second time this assumption broke in a way that produced
orphaned/stale data; both times, only the specific rows found that day
were cleaned up, not the mechanism that would prevent a third.

## Scale (measured, not estimated)
Cross-checked all 23 Harness-adopted papers against the Student Backend's
current `PaperQuestion` rows for the same paper IDs:
- **21 of 23 had zero surviving overlap** — every harness-side question ID
  missing from the student side, regardless of whether the counts matched
  (e.g. harness=5/student=5 still meant all 5 IDs were different) or were
  wildly different (harness=136/student=68; harness=1/student=51).
- **4 of the 21** had no Student Backend `Paper` row at all anymore (paper
  withdrawn/deleted upstream, Harness never told) — a related but distinct
  symptom from the same root cause.
- **11 real historical `attempts` rows** existed against 7 of the 21 stale
  papers — legitimate marking history from before 2026-09-11, at risk of
  cascade-deletion alongside the stale data (see Solution).
- **2 of 23** were unaffected (harness IDs still fully present on the
  student side).
- All 21 affected papers are `status: published` — live, currently
  reachable by any student.

## Prevention / Rule
**Guardrail:** Build the scheduled consistency check `HBEC-2026-09-11-orphaned-student-papers-point-to-deleted-harness-papers.md`
already recommended and never built: periodically (same cadence as any
bulk resync/reingest) diff every Harness-adopted paper's question ID set
against the Student Backend's current set for that paper, and alert on any
non-empty diff — not just a missing paper. This closes both directions of
the same gap (paper deleted upstream, and questions regenerated upstream)
with one mechanism. Filed as a follow-up; not built in this pass (see
Prevention checklist).

## Solution

### Immediate Fix
Verified no destructive shortcut was available — checked FK cascade rules
first (`attempts`/`marking_points`/`question_assets` all `ON DELETE
CASCADE` from `questions`/`papers`), found 11 real attempt rows would be
destroyed by a blind delete, and **backed up every affected row before
touching anything**:
```bash
# Full JSON dump of all 21 papers, 327 questions, their marking points,
# and the 11 real attempts, saved outside any container before deletion.
psql -U harness -d harness_db -t -A -c "SELECT json_agg(row_to_json(p)) FROM papers p WHERE p.id IN (...)"
psql -U harness -d harness_db -t -A -c "SELECT json_agg(row_to_json(q)) FROM questions q WHERE q.paper_id IN (...)"
psql -U harness -d harness_db -t -A -c "SELECT json_agg(row_to_json(m)) FROM marking_points m WHERE m.question_id IN (SELECT id FROM questions WHERE paper_id IN (...))"
psql -U harness -d harness_db -t -A -c "SELECT json_agg(row_to_json(a)) FROM attempts a WHERE a.paper_id IN (...)"
```
Then deleted the 21 stale `papers` rows (cascades handled questions,
marking points, and the 11 attempts):
```sql
DELETE FROM papers WHERE id IN (<21 ids>);
-- DELETE 21
```
Verified clean: 0 papers/questions remaining for the 21 ids, the 2 healthy
papers untouched, total adopted-paper count 23 → 2.

**Verified the fix actually works**, not just "delete and assume": ran
`get_or_adopt_paper` directly against one of the 21 (the English Language
paper, harness had 1 stale question, student now has 51 real ones). It
re-adopted cleanly — pulled all 51 current questions, generated marking
schemes for each (none existed upstream), and the question ID that
originally 404'd now passes the existence check. `total_questions_now: 51`
matches the Student Backend exactly.

### Long-term Fix
The scheduled consistency check described in Prevention/Rule above — not
built in this pass. The other 20 papers will each re-adopt correctly and
automatically the next time any student attempts them (same code path just
verified); no further manual action needed for those.

## Prevention
- [x] Configuration changes needed — 21 stale adopted papers deleted from
  production, verified clean, re-adoption verified working
- [ ] Monitoring/alerts to add — the scheduled Harness-vs-Student-Backend
  question ID consistency check, still not built (second time this exact
  recommendation has been made)
- [x] Documentation to update — this entry
- [ ] Code changes required — none for the immediate fix (data-only); the
  consistency-check guardrail would be a new script/job

## Related Issues
- `HBEC-2026-09-11-orphaned-student-papers-point-to-deleted-harness-papers.md`
  — the sibling finding from the same reingest event, same unimplemented
  guardrail recommendation, opposite symptom (paper missing entirely vs.
  paper present with stale questions).

## References
- `AGENTIC_HARNESS/app/exam_practice/services/paper_adoption.py`
- `AGENTIC_HARNESS/app/exam_practice/router.py` (`submit_answer`,
  lines 615-632)
- Traced and fixed at the user's explicit request, using the 5 Whys method.

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as report — trace, backup, delete,
and verify all completed same day
