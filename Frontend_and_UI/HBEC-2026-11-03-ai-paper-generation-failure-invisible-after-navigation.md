# AI paper generation failures become invisible/unrecoverable after navigating away

**Date:** 2026-11-03
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
An admin (Mutsa) reported on 2026-10-29: "when you try to generate papers, leave the page and return to check the papers, they don't have questions or they have disappeared entirely... connected to Generation Failed - Use paid models." Investigation found the underlying data bug (a generated paper could be marked ready with zero questions) was already fixed on 2026-10-06 (`aea7a7533`). What remained — and is almost certainly what Mutsa hit — was a UI/UX gap: the admin page tracks in-flight/failed AI generations only in local React state, which is lost on navigation, and the main papers table had no way at all to show or retry a failed generation. A failed paper looked exactly like permanent data loss even though nothing was lost.

## Symptoms
- Admin starts AI paper generation, navigates away, comes back — the "Generation Failed" card, error text, and retry buttons are gone.
- The main papers table shows the reverted paper as a bare "Draft" with 0 questions and no indication it was ever an AI generation, why it failed, or any way to retry it.
- If the admin's table view was filtered to `status=review`, a paper that reverted to `draft` on failure would vanish from view entirely, compounding the "disappeared" impression.

## Environment Details
- **Server/Host:** HBEC ADMIN frontend/backend
- **Services Affected:** `ADMIN/adminFrontend` (exam-practice-admin feature), `ADMIN/adminBackend` (`exam_papers` app)
- **Related Components:** `ExamPracticeAdminPage.tsx`, `AIGenerationCards.tsx`, `PaperTable.tsx`, `PaperList.tsx`, `apps/exam_papers/views.py` (`GenerateAIJobStatusView`), `apps/exam_papers/serializers.py` (`ExamPaperReadSerializer`)
- **Time First Observed:** 2026-10-29 (reported); investigated and fixed 2026-11-03

## Investigation Steps

### 1. Initial Diagnosis
Traced the admin AI-generation flow end to end: the create-paper POST (`GenerateAIPaperView.post`) creates the `ExamPaper` row synchronously then dispatches a Celery task (`generate_ai_paper_via_harness`) and returns immediately — generation is asynchronous, with real status/result tracked server-side on `ExamPaper.status`/`metadata`.

### 2. Root Cause Analysis
```bash
grep -n "generationPaperIds" ADMIN/adminFrontend/src/features/exam-practice-admin/pages/ExamPracticeAdminPage.tsx
grep -n "sourceType\|generation_error" ADMIN/adminBackend/apps/exam_papers/serializers.py
git log --oneline -- ADMIN/adminBackend/apps/exam_papers/tasks.py | head -10
```
- `generationPaperIds` (`ExamPracticeAdminPage.tsx`) is plain `useState`, populated only from the generate-ai POST response. No URL param, localStorage, or server-fetched list reconstructs it after a real navigation, so the `AIGenerationCards` section (the only UI showing status, error, and retry) simply never renders again for that paper.
- `ExamPaperReadSerializer` (used by the main papers list) never exposed `source_type` at all, despite the frontend table already checking `paper.sourceType === 'admin_generated'` for an "AI" badge — so even that badge was silently dead code, and a failed/reverted AI paper was indistinguishable from any other plain draft.
- No `generation_error`/`generation_error_code` (already written to `ExamPaper.metadata` on failure, per the 2026-10-06 fix) was exposed by the list serializer either — only the transient per-ID job-status endpoint had it.
- Confirmed via `git log` that the actual "paper created with zero questions" data bug was fixed 2026-10-06 (`aea7a7533`) and an idempotency race was fixed earlier (`a6ebebb2d`) — no code path deletes an `ExamPaper` row on failure. The 2026-10-29 report is explained entirely by the UI gap above.

### 3. Key Findings
- Server-side truth (`ExamPaper.status`/`metadata`) was always correct; the frontend's only pointer to which papers to check was ephemeral component state.
- The main table had zero visibility into AI-specific state (source, error, error code) and zero retry affordance — `AIGenerationCards` was the only place any of this ever surfaced, and it depended on the same lost state.

## Root Cause
Generation progress/failure was tracked durably on the server but discoverably only through client-side state that doesn't survive navigation, and the one UI surface that could show it (`AIGenerationCards`) was the only place wired to read it — the main paper list never got the fields needed to show the same information permanently.

## Prevention / Rule
**Guardrail:** Any async background job whose result matters to the user must be discoverable from a GET with no required client-supplied state (e.g. "my pending/failed jobs"), not only from a list of IDs the client itself must remember to keep. Code review for new async admin workflows should check for this "durable discovery" endpoint before approving.

This directly prevents the general pattern behind this bug: a correct server-side state machine made invisible by a client that can only ever point at jobs it personally just started.

## Solution

### Immediate Fix
None needed — no data was lost; this was purely a visibility gap.

### Long-term Fix
- `GenerateAIJobStatusView.get` (`apps/exam_papers/views.py`): when `paperIds` is omitted, auto-discovers the current admin's own unresolved AI generations (`status=processing`, or `status=draft` with `metadata.generation_error` set), scoped to `source_type=admin_generated` and `created_by=request.user`.
- `ExamPaperReadSerializer` (`apps/exam_papers/serializers.py`): now exposes `sourceType`, `generationError`, `generationErrorCode` (the first of these was previously missing entirely, so the existing "AI" badge in the table had never actually rendered).
- Frontend: added `usePendingGenerationJobs()` (`hooks/index.ts`), called on mount in `ExamPracticeAdminPage.tsx` to re-seed `generationPaperIds` from the server's own truth. `PaperTable.tsx` now shows a "Generation failed" badge (with the error as a tooltip) and a row-level "Retry Generation" / "Retry with Paid AI Model" action for any admin-generated draft with a `generationError`, wired through `PaperList.tsx` to the existing retry mutation.
- Added regression tests: `apps/exam_papers/tests/test_generation_job_status_discovery.py` (9 tests: auto-discovery scoping by user/source-type/status, explicit-IDs behavior preserved, serializer field exposure) and 0 new frontend tests (none existed for this page; covered by `tsc --noEmit` passing clean).

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- Commit `aea7a7533` ("Use Paid AI Model Instead" produced a paper with no questions) — the underlying data bug this UI gap was mistaken for a recurrence of.
- Commit `a6ebebb2d` — idempotency vs. duplicate retries.

## References
- `ADMIN/adminBackend/apps/exam_papers/views.py` (`GenerateAIJobStatusView`)
- `ADMIN/adminBackend/apps/exam_papers/serializers.py` (`ExamPaperReadSerializer`)
- `ADMIN/adminFrontend/src/features/exam-practice-admin/pages/ExamPracticeAdminPage.tsx`
- `ADMIN/adminFrontend/src/features/exam-practice-admin/components/PaperTable.tsx`
- `ADMIN/adminBackend/apps/exam_papers/tests/test_generation_job_status_discovery.py`

---

**Resolved By:** Claude (session with Tinotenda Mupezeni)
**Time to Resolution:** Same session as investigation
