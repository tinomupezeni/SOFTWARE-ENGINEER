# AI Paper Marking "Question Not Found" Drift

**Date:** 2026-10-09
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Investigating

## Summary
When users attempt to submit answers for AI-generated practice papers, the marking request fails because the Harness returns a `404 - {"detail":"Question not found"}`. This is caused by a sync drift between the Student backend's question representation and the Harness DB's question representation.

## Symptoms
- Student feedback complains about papers not being marked ("you are marking my data response questions").
- The feedback's `recentErrors` trail shows consecutive `Harness marking failed: Request failed: 404 - {"detail":"Question not found"}`.
- Affects AI-generated papers (e.g. `01a08fbc-bd22-7aa2-bc0f-771da4701dbf`).

## Environment Details
- **Server/Host:** Production (admin.hbca.tech / student frontend)
- **Services Affected:** `student-backend`, `harness`
- **Related Components:** `apps.practice.views`, `useExamSession.ts`, AI marking services
- **Time First Observed:** 2026-10-04 (from feedback logs)

## Investigation Steps

### 1. Initial Diagnosis
Pulled unresolved system errors and technical feedback using the `hbec-errors` MCP. Found feedback reports complaining about marking. The frontend attached an error trail showing 404s from the Harness.

### 2. Root Cause Analysis
Checked the Student Backend codebase (`apps/practice/views.py` and `models.py`) and the frontend (`useExamPractice.ts` / `examService.ts`). The architecture for AI-generated papers creates native `Question` rows in the Harness. The Student backend syncs these rows locally but with its own IDs, storing the Harness ID in `harness_question_id`.
The frontend's submission logic tries to send `harnessQuestionId || localId` to the Harness.
Since the Harness returns 404, either the `harness_question_id` mapping in the Student backend was lost/corrupted during a paper update drift, or the Harness actually lost the question rows after generating them.

### 3. Key Findings
- The paper ID `01a08fbc-bd22-7aa2-bc0f-771da4701dbf` returned 404 on the Admin Backend's global past papers API, confirming it is an AI-generated paper personal to the student.
- AI papers have a strict reliance on `harness_question_id` to route answers back to the correct context in the Harness.
- "Drift" happens after AI papers are updated, throwing the mapping out of sync.

## Root Cause
When an AI paper is updated, the drift causes either the Student Backend to lose the correct `harness_question_id` mappings for its local questions, or the Harness drops the questions entirely. This forces the frontend to send an invalid ID to the Harness, resulting in 404s.

## Prevention / Rule
**Guardrail:** Implement an integrity assertion during the AI paper sync/update loop that strictly validates the existence of the `harness_question_id` mapping for every question before completing the update transaction.

This prevents the system from silently orphaned local questions that have no matching counterpart in the Harness.

## Solution

### Immediate Fix
Pending investigation into whether the Student Backend's `views.py` is dropping the `harnessQuestionId` from the payload, or if the update logic is breaking the DB.

### Long-term Fix
Synchronize the paper update logic so that structural changes to AI papers atomically reflect in both the Harness and Student DB without losing ID mappings.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- Drift between Student DB and Harness DB.

## References
- Found via `hbec-errors` MCP.
- `STUDENT/hbec_backend/apps/practice/views.py:1051`

---

**Resolved By:** Antigravity
**Time to Resolution:** Ongoing
