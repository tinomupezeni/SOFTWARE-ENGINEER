# SignaturePad can get stuck mid-draw on devices without pointer capture, blocking delivery sign-off

**Date:** 2026-11-24
**Project:** ZIMPHOS
**Environment:** Development (caught during PR review, PR #3, before merge)
**Severity:** High
**Status:** Investigating

## Summary
PR #3 adds a delivery sign-off flow requiring a captured signature (`SignaturePad.tsx`). An earlier commit in the PR had an `onPointerLeave={handleUp}` handler; a later commit in the same PR removed it and added only `onPointerCancel={handleUp}` instead. `pointercancel` fires on a narrower, different set of browser-cancellation events than `pointerleave` — it is not triggered by an ordinary pointer sliding past the element's bounds while still pressed.

## Symptoms
- No runtime symptom yet — caught during pre-merge code review. On a device where `setPointerCapture` isn't supported (the code already hedges for this with optional chaining: `event.currentTarget.setPointerCapture?.(...)`), a driver's finger sliding past the canvas edge before lifting — an ordinary part of signing — leaves `drawing.current` stuck `true`, `onChange` is never called, and the delivery form reports signing as incomplete despite the driver having signed.

## Environment Details
- **Server/Host:** Development / PR review only, not deployed.
- **Services Affected:** `frontend` (field app delivery sign-off).
- **Related Components:** `frontend/src/components/field/SignaturePad.tsx:78`; consumed by `DeliveryPage.tsx`.
- **Time First Observed:** 2026-11-24, during review of PR #3.

## Investigation Steps

### 1. Initial Diagnosis
Diffed the component across the PR's commits (not just the final state) to see whether `onPointerLeave` removal was deliberate, and checked the fallback path the code itself anticipates (`setPointerCapture` unsupported) against the remaining handler set.

### 2. Root Cause Analysis
The component's own code acknowledges pointer capture may not be supported (optional chaining on `setPointerCapture`), which means the `pointerup`/`pointercancel` listeners are the only path to ending a stroke on such devices — but without capture, a pointer leaving the element's bounds while pressed doesn't reliably fire either event on all browsers; `pointerleave` was the handler actually covering that case, and it was dropped.

### 3. Key Findings
- The removal appears to be an unintentional side effect of unrelated pointer-event cleanup in the later commit, not a deliberate behavior change (no comment or PR note explains it).

## Root Cause
Removing `onPointerLeave` without accounting for the already-hedged "no pointer capture" fallback path it was covering.

## Prevention / Rule
**Guardrail:** any pointer-based drawing/signature component that hedges against missing `setPointerCapture` support must keep `onPointerLeave` (in addition to `onPointerUp`/`onPointerCancel`) as the fallback stroke-end signal for that no-capture path, and a test exercising "pointer down, move past bounds without pointer-up" must assert the stroke ends and `onChange` fires.

## Solution

### Immediate Fix
_Pending — to be fixed in this session._

### Long-term Fix
Restore `onPointerLeave={handleUp}` alongside the existing `onPointerCancel`/`onPointerUp` handlers, and add a test for the no-capture-fallback leave-while-pressed scenario.

## Prevention
- [x] Code review caught this before merge (no production exposure).
- [ ] Add a regression test for the pointer-leave-while-pressed-no-capture case.
- [ ] Documentation to update: none required beyond this log entry.
- [ ] Code changes required — in progress.

## Related Issues
- Found alongside other PR #3 findings; see sibling entries in this directory dated 2026-11-24.

## References
- PR: https://github.com/winstonjthinker/Zimphos/pull/3

---

**Resolved By:** Claude Sonnet 5 (code-review subagent, PR review session) — fix pending
**Time to Resolution:** Caught before merge; fix in progress
