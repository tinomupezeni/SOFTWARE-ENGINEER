# Library page's "Open queue" CTA links to itself

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Staging (found while dedup'ing the Library page's board grid, not yet checked on production)
**Severity:** Low
**Status:** Investigating (found, not fixed — out of scope for the change in progress)

## Summary
`LibraryPage.tsx`'s "Pipeline pulse" sidebar shows an "Awaiting review" stat
with an "Open queue" call-to-action when `reviewPending > 0`. That CTA's
`to` is hardcoded to `/library` — the page the button already sits on.
Clicking it does nothing.

## Symptoms
- No error, no crash — just a button that doesn't navigate anywhere new.
- Easy to miss because it only renders when `reviewPending > 0`, and even
  then looks like a normal working link.

## Environment Details
- **File:** `ADMIN/adminFrontend/src/features/library/pages/LibraryPage.tsx`,
  the `Stat` component's `cta` prop on the "Awaiting review" stat.

## Investigation Steps
Found by inspection while trimming this same file's board-grid section for
an unrelated dedup pass. Cross-checked against `App.tsx`'s own routing
comments: `/ingestion/review` is itself just a redirect to `/library`
("pending items now live inline on the SubjectPage" — the standalone
review queue page was retired). So even pointing the CTA at
`/ingestion/review` wouldn't fix it; it would bounce right back to
`/library` per the existing redirect.

## Root Cause
Not yet determined precisely — likely a leftover from before the review
queue was folded into `SubjectPage`, never updated to point at a real
destination once the old destination was retired.

## Prevention / Rule
**Guardrail:** An automated link-integrity check (e.g. a Playwright pass over every route) that renders each page, collects every CTA/nav link on it, and asserts each target path differs from the current route.

This catches a `to` prop hardcoded to the page it already sits on before a human happens to click it — exactly the kind of dead link that survives silently because it renders normally and only fails on click.

## Solution
Not applied — needs a decision on where "Open queue" should actually take
an admin now that there's no standalone review-queue page (a specific
subject's `PendingReviewSection`? a filtered view? removing the CTA
entirely since review is now spread across subjects rather than being one
queue?). Flagging for a follow-up rather than guessing under an unrelated
change.

## Prevention
- [ ] Code changes required — deferred, needs a product decision first
- [ ] Documentation to update — n/a

## References
- `ADMIN/adminFrontend/src/features/library/pages/LibraryPage.tsx` (`Stat` usage, `cta={{ label: 'Open queue', to: '/library' }}`)
- `ADMIN/adminFrontend/src/App.tsx` (`/ingestion/review` → `/library` redirect, with the "pending items now live inline on the SubjectPage" comment)

---

**Resolved By:** Not resolved — logged only
**Time to Resolution:** N/A
