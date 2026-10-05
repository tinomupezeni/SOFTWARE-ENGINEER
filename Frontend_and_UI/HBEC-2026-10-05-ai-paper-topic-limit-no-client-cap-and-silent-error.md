# AI paper topic picker had no 20-topic cap and silently discarded the backend's rejection reason

**Date:** 2026-10-05
**Project:** HBEC
**Environment:** Production (Student Frontend)
**Severity:** Medium
**Status:** Resolved

## Summary
`GeneratePaperModal` (the topic picker for AI exam-paper generation) let a
student tick an unlimited number of topics with no warning, even though the
backend rejects more than 20 with a `400 ValidationError`. When that
rejection happened, the frontend's error handling discarded the backend's
specific message and showed a generic "Could not start paper generation.
Please try again." — explaining a live incident where one student hit the
rejection 5 times in 17 seconds with no idea why.

## Symptoms
- `POST /api/ai/papers/generate/` → `400 ValidationError: {'topics': ['Ensure
  this field has no more than 20 elements.']}`, 5 occurrences for one student,
  2026-10-05T14:05:46 to 14:06:03 (17 seconds).

## Environment Details
- **Server/Host:** `hbca-vps` (backend reporting the error), client-side bug
  in `STUDENT/Frontend/`
- **Services Affected:** Student Frontend, `hbec-student-backend` (the
  rejecting endpoint — correct behavior, not the bug)
- **Related Components:**
  `src/features/exam-practice/components/GeneratePaperModal.tsx`,
  `src/features/exam-practice/api/generateApi.ts`,
  `src/features/exam-practice/hooks/useAiPaperGeneration.ts`
- **Time First Observed:** 2026-10-05, found via `system_error_logs` triage
  using the new `hbec-errors-mcp` tool — originally flagged as "a third,
  unrelated issue for the same student whose technical feedback (`'Harness
  marking failed: too many requests'`) prompted today's broader error
  investigation."

## Investigation Steps

### 1. Initial Diagnosis
The backend rejection message itself (`"Ensure this field has no more than
20 elements"`) is clear and correct — ruling out a backend bug immediately.
The question was why a student would hit it 5 times in a row rather than
once.

### 2. Root Cause Analysis
- `GeneratePaperModal.tsx`'s `toggleTopic` pushed/removed from
  `selectedTopics: string[]` with no length check anywhere; no counter, no
  disabled state, nothing stopping a student from ticking every topic in the
  subject.
- `generateApi.ts`'s `startPaperGeneration` catch block branched only on
  `error.status` (409/404/429/402/5xx), with no case for 400 — it fell
  through to `{ reason: 'unknown' }`.
- `useAiPaperGeneration.ts`'s `START_FAILURE_MESSAGES['unknown']` is
  `'Could not start paper generation. Please try again.'` — shown verbatim,
  explaining why "try again" is exactly what the student did, 5 times.
- Separately: `apiFetch` (`src/lib/api.ts`) does parse the response body into
  `ApiError.payload`, but DRF's field-error shape for this endpoint
  (`{"topics": [...]}`) lands at the payload **root**, not under
  `error.message` or `error.errors` (which `apiFetch` only populates from a
  top-level `message` key or an `errors` key respectively) — so even a 400
  handler reading `error.message` would still have shown nothing useful
  without reading `error.payload` directly.

## Root Cause
Two independent gaps compounding: no client-side enforcement of a limit the
backend has always had, and no handling at all for the one HTTP status
(400) that limit produces — so the student got no warning before hitting it,
and no explanation after.

## Prevention / Rule
**Guardrail:** `generateApi.test.ts`'s
`'surfaces the backend field-error message on a 400, not a generic failure'`
asserts the specific field-error string is extracted and returned, not
discarded; `GeneratePaperModal.topicCap.test.tsx` asserts the 21st checkbox
is disabled and the counter/warning render at the cap.

## Solution

### Immediate Fix
- `GeneratePaperModal.tsx`: added `MAX_TOPICS = 20` matching the backend
  limit. `toggleTopic` now refuses to add past it; the topic list shows a
  live "`N`/20 selected" counter, disables remaining checkboxes at the cap,
  and shows an explicit "You can select up to 20 topics" message.
- `generateApi.ts`: `startPaperGeneration` now has a `400` branch that reads
  `error.payload`'s root for a DRF-shaped field-error array and returns a new
  `validation_error` reason carrying that specific message.
- `useAiPaperGeneration.ts`: prefers `start.message` (the specific backend
  reason) over the generic reason-keyed map when present.

### Long-term Fix
None needed — the client-side cap makes the backend rejection effectively
unreachable through normal use; the message passthrough remains as a
defensive fallback (stale client state, a future field gaining the same
treatment, etc.).

## Prevention
- [x] Code change applied (frontend)
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Test coverage added (`generateApi.test.ts`,
      `GeneratePaperModal.topicCap.test.tsx` — neither file had prior tests)

## Related Issues
- Surfaced while investigating the same student's reported technical
  feedback (`"Harness marking failed: too many requests"`, see the session's
  broader `system_error_logs` triage) — a genuinely separate, unrelated bug
  found incidentally in the same error sweep.

## References
- `STUDENT/Frontend/src/features/exam-practice/components/GeneratePaperModal.tsx`
- `STUDENT/Frontend/src/features/exam-practice/api/generateApi.ts`
- `STUDENT/Frontend/src/features/exam-practice/hooks/useAiPaperGeneration.ts`
- `STUDENT/Frontend/src/lib/api.ts` (`ApiError`, `apiFetch`)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Same session as discovery
