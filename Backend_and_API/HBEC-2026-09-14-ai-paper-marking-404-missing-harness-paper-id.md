# AI-Generated Paper Marking 404'd Because the Detail Endpoint Never Sent `harnessPaperId`

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved — both the paper-id bug and a second, deeper
question-id bug behind the same symptom, verified live on production. A
third, unrelated gap (Artifact-backed papers) found and left open — see
below.

## Update (same day): the fix above wasn't sufficient — a second id
mismatch, one level down
After deploying the fix below, the user reported the marking 404 was
**still happening on production**. Re-investigation (log review, direct
confirmation the deployed container's source genuinely had the fix,
then a fresh audit of every endpoint that hands the frontend a paper id)
found the first fix was necessary but not sufficient: it fixed the
*paper*-id mismatch, but an independent, structurally identical mismatch
existed one level down, at the *question* id.

**The second root cause:** AI-generated papers get their `Question` rows
created **natively** in the harness's own database
(`paper_generator.py`) — the harness never needs to "adopt" a paper it
already generated itself (adoption in `paper_adoption.py` only runs when
`db.get(Paper, paper_id)` finds nothing locally, which is never true for
one the harness created). When that paper is synced to the student
backend (`_sync_to_student` → `PaperForAdoptionView`'s sibling sync
endpoint, `apps/internal/views.py`'s `SyncPaperView`), the sync payload
never included the harness's own per-question id — `PaperQuestion.objects.create()`
always assigned a fresh, unrelated UUID. `PracticeSetDetailView` then
serialized that unrelated local id as `"id"`, the frontend submitted it
as `questionId`, and the harness's `submit_answer`
(`select(Question.id).where(Question.id == question_id, Question.paper_id
== paper_id)`) never found a match — 404, for the exact same class of
paper the first fix targeted, on a different field.

**Fix:** threaded the harness's native question id through the same
sync channel already carrying `harness_paper_id`:
- `AGENTIC_HARNESS/app/exam_practice/services/paper_generator.py` —
  `_sync_to_student`'s `questions_payload` now includes
  `"harness_question_id": str(q.id)` per question.
- `STUDENT/hbec_backend/apps/practice/models.py` — new
  `PaperQuestion.harness_question_id` field (migration `0016`).
- `STUDENT/hbec_backend/apps/internal/views.py` — `SyncPaperView`
  stores it: `harness_question_id=q_data.get("harness_question_id")`.
- `STUDENT/hbec_backend/apps/practice/views.py` — `PracticeSetDetailView`
  now serializes `"harnessQuestionId": q.harness_question_id`.
- Frontend (`STUDENT/Frontend/src/features/exam-practice/`) — `Question`
  type, `examApi.ts`'s `fetchQuestions` mapping, and
  `useExamPractice.ts:310`'s submission call all thread
  `harnessQuestionId || id` through, mirroring the exact
  `harnessPaperId || paperId` pattern the first fix already established.

5 new regression tests (`test_ai_papers.py`'s `QuestionHarnessIdTests`,
`test_sync_paper.py`'s `TestSyncPaperHarnessQuestionId`) plus the full
`apps/practice` + `apps/internal` suite (109 tests) all pass. Verified
live on staging by re-running the sync for a real, already-generated
22-question AI paper and confirming (a) the stored
`harness_question_id` genuinely differs from the local `id`, (b) the
detail endpoint now serializes `harnessQuestionId` correctly, and (c) a
row with that exact id exists in the harness's own `questions` table for
that paper — the precise condition `submit_answer`'s query needs, which
the old local id could never satisfy. Deployed to production the same
way as the first fix (`sha-3f002af`, `--force-recreate` on
`student-backend`/`student-worker`/`student-beat`/`student-frontend`/
`harness`); migration applied cleanly; full host health sweep post-deploy
showed zero unhealthy or restarting containers.

## Original write-up

## Summary
User reported: submitting an answer for marking mid-paper (before
finishing every question) returned a 404, but marking worked once every
question in the paper had been answered. Traced to a real, deterministic
backend bug: `PracticeSetDetailView` (`GET /api/practice/papers/{id}/`,
what the exam-practice UI actually loads questions from) never
serialized `harnessPaperId` in its response — only the sibling list view
(`PracticeSetListView`) did. The frontend's marking call
(`useExamPractice.ts:310`, `harnessPaperId || paperId`) therefore always
fell back to this backend's own `paper.id`, which is silently wrong for
any AI-generated paper (where the harness's real id for that content
genuinely differs from this backend's wrapper id) — every structured-
question marking submission for such a paper 404'd, unconditionally,
not selectively by question position.

## Symptoms
- Submitting a structured answer for marking on an AI-generated practice
  paper returns a 404 from the harness ("Paper not found").
- The same paper, once fully answered, appeared to "work" — see Root
  Cause for why this is coincidental, not a real fix.

## Environment Details
- **Server/Host:** `STUDENT/hbec_backend`, `AGENTIC_HARNESS`
- **Services Affected:** exam-practice marking, specifically AI-generated
  papers (`Paper.session == "AI"`, or any paper with `harness_paper_id`
  genuinely different from its own `id`)
- **Related Components:** `STUDENT/Frontend/src/features/exam-practice/hooks/useExamPractice.ts`,
  `AGENTIC_HARNESS/app/exam_practice/services/paper_adoption.py`,
  `STUDENT/hbec_backend/apps/internal/views.py` (`PaperForAdoptionView`)
- **Time First Observed:** 2026-09-14 (reported by the user; root cause is
  older — present since `harnessPaperId` was added to the list view
  without the same change to the detail view)

## Investigation Steps

### 1. Initial Diagnosis
Traced the frontend's marking call chain: `submitAnswer()`
(`STUDENT/Frontend/src/lib/examPracticeApi.ts:254`) posts to
`/api/v1/exam-practice/papers/{paperId}/questions/{questionId}/submit`
on the harness, using `targetHarnessId = questions.find(q => q.id ===
questionId)?.harnessPaperId || paperId` (`useExamPractice.ts:310`) —
one call site, used identically for every question regardless of
position in the paper.

### 2. Root Cause Analysis
```bash
grep -n "harnessPaperId" STUDENT/hbec_backend/apps/practice/views.py
# 566:  "harnessPaperId": paper.harness_paper_id,   (PracticeSetListView — has it)
# (nothing in PracticeSetDetailView's paper_info dict — doesn't)
```
Confirmed `harness_paper_id` is a real, meaningful field
(`apps/practice/models.py:183`, nullable) set in two places —
`apps/ai_gateway/views.py:381` when an AI paper is generated, and
`apps/internal/views.py:743` via the harness's own push-sync — and is
genuinely different from `paper.id` for any paper it's set on. Since
`fetchQuestions()` (frontend) reads this from a single `paper` object
per response and spreads it onto every `Question` uniformly, the field
is either present for the whole paper or absent for the whole paper
within one page load — never present for some questions and missing for
others in the same session. Confirmed via `PaperForAdoptionView`
(`apps/internal/views.py:1385-1425`) that the harness's adoption lookup
only ever queries this backend's own `Paper` table by whatever id it's
given — an id that doesn't match any row there (the wrong,
student-backend-only id) can never resolve, producing a 404 that
propagates: Django 404 → `httpx.raise_for_status()` →
`CircuitBreaker` re-raise → `adopt_paper`'s broad `except Exception:
return None` → `submit_answer`'s `raise HTTPException(404, "Paper not
found")` (`AGENTIC_HARNESS/app/exam_practice/router.py:549-551`).

### 3. Key Findings
- The bug is **paper-type-dependent, not question-position-dependent**.
  The "works after finishing all questions" observation is most likely
  explained by the student's two test runs actually being on different
  papers — a coincidence, not a real difference in behavior by question
  order.
- A second, deeper, structurally separate gap was found alongside this:
  `PracticeSetDetailView` also serves a completely different paper format
  (`Artifact`-backed practice sets, the older PDF/admin-uploaded format,
  tried first in that view) whose `paper.id` is an `Artifact.id` that
  `PaperForAdoptionView` can **never** resolve, since it only ever
  queries `practice.Paper`. Fixing the missing `harnessPaperId`
  serialization does not help this class of paper — they have no
  `harness_paper_id` concept at all. Left this open; see Long-term Fix.

## Root Cause
`PracticeSetDetailView`'s `paper_info` dict (the `practice.Paper`
branch, `apps/practice/views.py:986-1004` before this fix) was written
independently of `PracticeSetListView`'s equivalent dict and simply
never included `harnessPaperId`, even though the underlying model field
and its purpose (letting the frontend send the harness's real id instead
of this backend's own wrapper id) were already correctly implemented
everywhere else in the system.

## Prevention / Rule
**Guardrail:** Wherever the same conceptual "paper" gets serialized from
more than one view (list vs. detail, or any future addition), extract a
single shared serializer/helper function rather than hand-writing two
independent field dicts — the list/detail divergence here is exactly the
kind of drift that a shared serializer makes structurally impossible,
since there would only be one dict to add a field to.

This closes the gap because the actual failure mode was two
independently-maintained representations of the same data silently
diverging, not a logic bug in either one individually.

## Solution

### Immediate Fix
Added `"harnessPaperId": paper.harness_paper_id` to
`PracticeSetDetailView`'s `practice.Paper` branch, matching
`PracticeSetListView` exactly. Three new regression tests in
`apps/practice/tests/test_ai_papers.py` confirm: (1) an AI-generated
paper's detail response now carries the correct, genuinely-different
`harnessPaperId`; (2) a plain admin-replicated paper (no
`harness_paper_id` set) serializes it as an explicit `null` rather than
omitting the key, so the frontend can tell "genuinely none, fall back to
paper.id correctly" apart from "backend forgot to send it"; (3) the
existing detail-view test suite (19 tests across
`test_ai_papers.py`/`test_paper_views.py`) and the full `apps/practice`
suite (43 tests) all pass.

**Deployed to production**, same session: tagged the staging-verified
image `sha-e0451cc` (matching the fix commit) and recreated
`student-backend`, `student-worker`, and `student-beat` with
`--force-recreate` — no compose changes needed (a pure code fix, no new
env vars or migrations). Verified against a real production paper
(`01a00aac-2e2e-7947-91ea-aacd87bb4139`): `harnessPaperId` now returns
`837ff96a-352e-48e9-b41a-105ea0512863`, genuinely different from the
paper's own id, exactly the previously-missing signal. Full host health
sweep post-deploy: zero unhealthy or restarting containers anywhere.

### Long-term Fix
The `Artifact`-backed paper class still cannot be marked by the harness
at all — `PaperForAdoptionView` would need to also resolve `Artifact`
rows (mirroring `PracticeSetDetailView`'s own "try Artifact, then
Paper" pattern) and `adopt_paper()` would need to accept that format's
question/rubric shape. Not attempted this session: it's a materially
larger, higher-risk change (feeding a different content schema into the
harness's adoption/mark-scheme-generation pipeline) than the confirmed,
narrowly-scoped bug above, and deserves its own scoped pass rather than
being bundled into a same-day production hotfix.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — an alert on the harness's `submit_answer`
      404 rate (`ProviderModelRetired`/`ProviderAllKeysDead`-style
      per-provider signal doesn't cover this; a dedicated
      `harness_llm_calls_total`-adjacent counter for adoption failures
      would have caught this class of bug proactively)
- [ ] Documentation to update — none yet
- [x] Code changes required — done, for the confirmed bug; the
      Artifact-adoption gap remains open

## Related Issues
- None yet — first time this bug was traced.

## References
- `STUDENT/hbec_backend/apps/practice/views.py` — `PracticeSetDetailView`,
  `PracticeSetListView`
- `STUDENT/hbec_backend/apps/internal/views.py` — `PaperForAdoptionView`
- `AGENTIC_HARNESS/app/exam_practice/services/paper_adoption.py`
- `AGENTIC_HARNESS/app/exam_practice/router.py` — `submit_answer`
- `STUDENT/Frontend/src/features/exam-practice/hooks/useExamPractice.ts:310`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery, in two passes — the
first fix (paper-id) shipped, was reported as not fully resolving the
issue, and the second, deeper fix (question-id) shipped the same day.
