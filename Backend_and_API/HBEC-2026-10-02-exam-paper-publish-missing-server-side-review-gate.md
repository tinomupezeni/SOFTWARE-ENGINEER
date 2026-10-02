# Paper Publish Endpoint Never Checks "All Questions Reviewed" — Only a Disabled Button Does

**Date:** 2026-10-02
**Project:** HBEC
**Environment:** Found reviewing PR #51 (`experimental` → `master`), which
adds the admin "review-held ingestion" flow
**Severity:** Medium (the feature's own stated motivation — "a measured
upload went live with 30 unkeyed MCQs and nothing reviewed" — is only
addressed client-side)
**Status:** Investigating (flagged in PR review; may be an accepted
trade-off rather than an oversight — flagging for a product decision)

## Summary
PR #51's review-hold flow stops `finalise_paper_ingestion` from
auto-publishing a paper; it now rests at `status=REVIEW` until a human calls
`ExamPaperStatusView.post` (`ADMIN/adminBackend/apps/exam_papers/views.py:217`).
That endpoint's only publish-time gate is `question_problems()` (structural:
duplicate labels, marks-sum mismatch, empty paper) plus a total-marks check
— it never reads `review_flags()`'s warnings, `reviewed_count`, or
`questions_count`. The only place "all questions reviewed" is enforced is
client-side: `ADMIN/adminFrontend/.../PaperTable.tsx`'s
`canPublish = paper.status === 'review' && paper.questionsCount > 0 &&
paper.reviewedQuestionsCount === paper.questionsCount` (disables the Publish
button).

## Symptoms
None observed — found via code read during PR review.

## Environment Details
- **Server/Host:** Admin Backend (Django, port 8002)
- **Services Affected:** exam paper publish flow
- **Related Components:** `ADMIN/adminBackend/apps/exam_papers/views.py`
  (`ExamPaperStatusView.post`), `apps/exam_papers/question_quality.py`
  (`review_flags`, `question_problems`), `ADMIN/adminFrontend/src/features/
  exam-practice-admin/components/PaperTable.tsx` (`canPublish`)
- **Time First Observed:** N/A (pre-merge review)

## Investigation Steps

### 1. Initial Diagnosis
Cross-file tracer angle of the PR review asked whether anything can still
reach students before admin approval under the new review-hold flow.

### 2. Root Cause Analysis
Read `ExamPaperStatusView.post` directly (lines 217-271): the
`new_status == PUBLISHED` branch only calls `question_problems()` and a
marks-sum check; `review_flags()`'s warnings (missing answer key, bare MCQ
options, promised-but-missing figure) are advisory and never read here.

### 3. Key Findings
- `review_flags()`'s own docstring says warnings are "never applied for
  [the reviewer], because the person approving is the one vouching" — this
  may be the intended design (human judgment, not an automated block). But
  nothing then prevents a direct API call, a different admin UI, or an
  admin clicking Publish without using the review screen from publishing
  with `reviewed_count == 0`.

## Root Cause
The precondition the feature is named for ("held for review") is enforced
only by disabling a button in one specific UI, not by the server endpoint
that actually performs the publish.

## Prevention / Rule
**Guardrail:** either (a) treat this as an intentional advisory-only design
and document it explicitly (no code change, but a product decision on
record), or (b) if review is meant to be mandatory, add a server-side check
in `ExamPaperStatusView.post` requiring `reviewed_count == questions_count`
before allowing the `REVIEW → PUBLISHED` transition, with an explicit
override path for an admin who deliberately wants to skip it.

## Solution

### Immediate Fix
None — flagged for a product/engineering decision, not assumed to be a bug.

### Long-term Fix
Decide (a) vs (b) above and implement accordingly.

## Prevention
- [ ] Product decision: is review enforcement advisory-only by design?
- [ ] If mandatory: add the server-side gate in `ExamPaperStatusView.post`

## Related Issues
None.

## References
- `ADMIN/adminBackend/apps/exam_papers/views.py:217`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/PaperTable.tsx`
- PR #51: https://github.com/Rest-creator/HBEC/pull/51

---

**Resolved By:** Found during PR review (tinomupezeni / Claude Code)
**Time to Resolution:** N/A — pending product decision
