# Admin Ingestion Review "Save Mapping" Called a Retired Feature's Route

**Date:** 2026-09-22 (found) / 2026-09-23 (fixed)
**Project:** HBEC
**Environment:** Discovered during a dead-code audit of admin backend/frontend
(cross-referencing every frontend API call against the backend's actual
routes)
**Severity:** Low, revised down from Medium — confirmed unreachable from any
page, not a live broken action
**Status:** Resolved

## Summary
While auditing for dead backend endpoints, the reverse case turned up:
`ADMIN/adminFrontend/src/features/ingestion/api/ingestionApi.ts` had a
`updateReviewItemMapping()` calling `PUT /ingestion/review-queue/${id}/mapping/`
— a route that doesn't exist anywhere in `apps/ingestion/urls.py`. Initial
triage assumed this was a live broken action. It wasn't: the entire chain
(`MappingEditor.tsx` dialog → `useUpdateReviewItemMapping` →
`updateReviewItemMapping()`) was unreachable from any page — a leftover of a
standalone `/ingestion/review` page that `App.tsx`'s own routing comment says
was deliberately retired: *"Standalone review queue retired — pending items
now live inline on the SubjectPage... the old `/ingestion/review` URL
redirects to Library."* Nothing ever called the dead chain, so nothing was
silently failing in front of a user.

## Symptoms
None observed in practice — the audit found this by static cross-reference,
not a user report, and further tracing showed no UI path could ever reach it.

## Investigation Steps

### 1. Initial Diagnosis
Built a full list of every backend route and every frontend API call site,
cross-referenced both directions. This asymmetry — a frontend call with no
matching backend route — was the only one found in the reverse direction.

### 2. Root Cause Analysis
Before assuming "broken and needs a backend endpoint," traced every caller of
`updateReviewItemMapping()`:
- `useUpdateReviewItemMapping()` (`hooks/index.ts`) — its only caller.
- `MappingEditor.tsx` — the only thing that could call the hook. Grepped for
  `<MappingEditor` anywhere in `src/` — zero matches, never rendered.
- `useMappingOptions()` — used only by `MappingEditor.tsx`, transitively dead
  the same way.
- The live mapping-approval path is actually `PendingReviewSection.tsx`,
  embedded on `SubjectPage`, whose own header comment says it **replaces**
  the standalone review page. It reads `item.currentMapping` and sends it
  straight through the working `approve/` endpoint — no separate "edit
  mapping first" step exists in the current design.
- `App.tsx`'s own routing: `/ingestion/review` is a `<Navigate>` redirect to
  `/library`, with a comment explicitly documenting the retirement.

### 3. Key Findings
- This was two-sided abandonment (no frontend caller, no backend route),
  unlike the mark-scheme bug found in the same audit (one-sided: real
  frontend caller, real backend capability, just never wired together).
  The distinguishing signal was the codebase's own architecture comment
  documenting the retirement — worth checking for before assuming a stale
  call means a missing backend feature.

## Root Cause
`MappingEditor.tsx` and its exclusive hook/API chain were never deleted when
the standalone review-queue page was retired in favor of `PendingReviewSection`.

## Prevention / Rule
**Guardrail:** when a frontend call targets a nonexistent backend route,
check whether the *calling code itself* is reachable from any route/page
before concluding a backend endpoint needs building — a dead caller needs
deletion, not a new endpoint. This is the same "verify before deleting"
guardrail from the sibling dead-code-audit entry, applied in the opposite
direction: verify before *building*, not just before removing.

## Solution

### Immediate Fix
Removed the whole dead chain rather than building the endpoint it called:
- `ADMIN/adminFrontend/src/features/ingestion/components/MappingEditor.tsx` (deleted)
- `useUpdateReviewItemMapping()`, `useMappingOptions()` (`hooks/index.ts`)
- `updateReviewItemMapping()`, `getMappingOptions()` (`api/ingestionApi.ts`)
- Corresponding exports in `components/index.ts` and the feature's `index.ts`
- `MappingUpdate` type kept — still used by the live `approveReviewItem()` path

### Verification
- `npm run typecheck` clean, full vitest suite 242/242 passing after removal.
- Confirmed (separately, not acted on) that `ReviewQueueList`/`ReviewItemCard`/
  `ReviewItemDetail` are similarly orphaned leftovers of the same retired
  page — flagged for a future cleanup pass, out of scope for this fix.

## Prevention
- [x] Code changes required — done
- [x] Documentation to update — this entry
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a

## Related Issues
Surfaced by `Architecture_and_Design/HBEC-2026-09-22-dead-code-audit-admin-backend-frontend.md`.
Same session as the sibling fix in
`Backend_and_API/HBEC-2026-09-22-admin-edit-paper-mark-scheme-silently-dropped.md`.

## References
- `ADMIN/adminFrontend/src/features/ingestion/components/MappingEditor.tsx` (removed)
- `ADMIN/adminFrontend/src/features/ingestion/hooks/index.ts`
- `ADMIN/adminFrontend/src/features/ingestion/api/ingestionApi.ts`
- `ADMIN/adminFrontend/src/features/ingestion/components/PendingReviewSection.tsx` (the live path)
- `ADMIN/adminFrontend/src/App.tsx` (retirement comment, `/ingestion/review` redirect)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Found 2026-09-22, fixed 2026-09-23 (same audit thread).
