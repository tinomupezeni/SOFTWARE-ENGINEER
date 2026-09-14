# Exam Practice "Notify me when available" button was built but never wired to any caller

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
`STUDENT/Frontend/src/features/exam-practice/components/PaperList.tsx`'s
"No papers available" empty state renders a `Bell`-icon "Notify me when
available" `<Button>`, gated on an `onNotifyRequest?: () => void` prop. Its
only caller, `pages/PaperListingPage.tsx`, never passed that prop (nor
`subjectName`, `PaperList`'s other optional prop) — so the button either
never rendered its subject-specific copy or, worse, would have rendered
with no click handler at all if it had reached students as-is. Same class
of bug as `HBEC-2026-09-14-subject-edit-dialog-points-to-nonexistent-
family-edit.md` in `ADMIN/adminFrontend`, found the same day: a UI
affordance fully built (icon, copy, styling, prop plumbing) with no wiring
from its parent to make it do anything.

## Symptoms
- No runtime error — React silently accepts a component tree where an
  optional prop is simply never passed. `onNotifyRequest && (<Button ...>)`
  meant the button didn't even render, so the empty state looked
  intentionally bare rather than broken.
- A student hitting "No papers available" for a subject had no way to
  signal that, despite a button clearly designed for exactly that having
  already been built into the component.

## Environment Details
- **Server/Host:** Local dev checkout, `STUDENT/Frontend/`
- **Services Affected:** None at runtime yet — no backend endpoint existed
  for this button to call until this same session's build (see below).
- **Related Components:**
  - `src/features/exam-practice/components/PaperList.tsx`
  - `src/features/exam-practice/pages/PaperListingPage.tsx`
- **Time First Observed:** 2026-09-14, while implementing the new
  "content gap report" feature (student → admin demand signal) that this
  dead prop was the natural home for.

## Investigation Steps

### 1. Initial Diagnosis
Read `PaperList.tsx` in full while scoping the content-gap-report feature
and found the `onNotifyRequest` prop, its `Bell`-icon button, and its
`subjectName`-driven empty-state copy already present.

### 2. Root Cause Analysis
Grepped for `PaperList`'s only import site (`PaperListingPage.tsx`) and
confirmed both `PaperList` calls passed only `papers`/`loading` — neither
`subjectName` nor `onNotifyRequest` was ever supplied, despite both being
declared and consumed inside `PaperList.tsx` itself.

### 3. Key Findings
- The component-level feature (icon, button, conditional render, subject
  name interpolation) was fully built and correct.
- The parent page never finished the wiring — no handler existed to pass,
  because until this session there was also no backend endpoint for such a
  handler to call.

## Root Cause
`PaperList.tsx` was built ahead of its consumer — the prop and UI were
scaffolded for a future feature (a way for students to request more
content) that hadn't been designed yet at the time, and `PaperListingPage.tsx`
was never revisited once that feature (content-gap reporting) was actually
specified and its backend endpoint built.

## Prevention / Rule
**Guardrail:** A lint rule (or code-review checklist item) flagging any
component prop declared as optional-and-conditionally-rendered
(`prop && <JSX/>` on a prop with no default) that has zero non-test call
sites passing it anywhere in the repo — the same shape of guardrail
already logged for the admin-frontend sibling of this bug
(`HBEC-2026-09-14-subject-edit-dialog-points-to-nonexistent-family-edit.md`).
`onNotifyRequest` would have shown up as an always-undefined prop the
moment it was added, before it could sit dead through a later session.

## Solution

### Immediate Fix
Wired `PaperListingPage.tsx` to pass `subjectName` and a new
`handleNotifyRequest` (calling the newly-built `reportContentGap` API,
`STUDENT/Frontend/src/lib/contentGapApi.ts`) into both `PaperList` call
sites (official + community tabs). Also added a `notifyRequested?: boolean`
prop to `PaperList.tsx` so the button visibly disables/relabels
("Request sent") after one click, rather than silently no-oping on a
second — the server-side 7-day cooldown is the real abuse guard, this is
just UX confirmation.

Full details of the content-gap-report feature itself (new API client,
matching Topic Revision button, tests) are the subject of this session's
main build, not a separate bug — logged here only because the *dead prop*
was itself a pre-existing, independent defect this session happened to
fix while building on top of it.

### Long-term Fix
None needed beyond the guardrail above.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — the lint-rule guardrail above (not added
      this session — a repo/tooling-level change, not this specific fix)
- [ ] Documentation to update — n/a
- [x] Code changes required — done

## Related Issues
- `HBEC-2026-09-14-subject-edit-dialog-points-to-nonexistent-family-edit.md`
  — identical bug shape (fully-built feature, missing UI wiring) found the
  same day in the admin frontend.

## References
- `STUDENT/Frontend/src/features/exam-practice/components/PaperList.tsx`
- `STUDENT/Frontend/src/features/exam-practice/pages/PaperListingPage.tsx`
- `STUDENT/Frontend/src/lib/contentGapApi.ts`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery
