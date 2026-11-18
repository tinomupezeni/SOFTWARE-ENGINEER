# Plot answer: a second pointer could steal or reset the aim mid-plot

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (caught via code review before merge)
**Severity:** Medium
**Status:** Resolved

## Summary
`PlotAnswer.tsx` (the exam-practice plot question's answer surface, where a
student taps and slides to aim a point on a grid, then lets go to plot it)
kept the in-progress aim in a single shared ref with no check on which
pointer owned it. A second simultaneous touch — a stray palm, a second
finger — could silently take over or cancel the first pointer's in-progress
aim, causing the wrong point to be plotted or the intended one to be
silently dropped.

## Symptoms
- Not yet reported in production; found during code review of PR #153
  (`feat/plot-reticle-svgjs`) before merge.
- Expected real-world symptom: a student plotting with one finger while a
  palm or second finger brushes the touch surface gets the wrong answer
  plotted, or no answer plotted at all, with no error shown.

## Environment Details
- **Server/Host:** N/A — client-side React component
- **Services Affected:** STUDENT/Frontend, exam-practice plot questions
- **Related Components:** `plotAim.ts`, `plotReticle.ts`, `plottedPoints.ts`
- **Time First Observed:** found during review, not yet in the wild

## Investigation Steps

### 1. Initial Diagnosis
Code review (`/code-review`) flagged that `aiming`/`reticle` state lived in
component-level refs with no `event.pointerId` discrimination across
`press`/`follow`/`release`/`drop`.

### 2. Root Cause Analysis
`press()` called `setPointerCapture` on the pressed pointer, but pointer
capture only redirects *that* pointer's own future events to the element —
it does not block a second pointer's `pointerdown`/`pointermove` from also
firing on the same `<rect>`. A second pointer's `press()` call would
overwrite `aiming.current` (and thus what `release()` commits) with the new
pointer's aim, regardless of which pointer the student intended to use.

### 3. Key Findings
- The same bug class (shared mutable pointer state, no `pointerId` check)
  was independently found and fixed the same day in `TraceBoard.tsx` (PR
  #152) — see that entry for the matching pattern.
- `release()`/`drop()` read `aiming.current` unconditionally on any
  `pointerup`/`pointercancel`, so a second pointer lifting first could
  commit or cancel the first pointer's work.

## Root Cause
No single-active-pointer invariant was enforced: `press`/`follow`/`release`/
`drop` all operated on shared refs with no `pointerId` guard, so any pointer
could read or mutate state that conceptually belonged to whichever pointer
started the current aim.

## Prevention / Rule
**Guardrail:** any touch/pointer-driven interactive surface in this codebase
that accumulates state across `pointerdown`→`pointermove`→`pointerup` (plot,
trace, drawing, drag) must track the owning `event.pointerId` in a ref and
have every handler (`move`/`up`/`cancel`) reject events whose `pointerId`
does not match, and `down` reject a new pointer while one is already active.
This is now true in both `PlotAnswer.tsx` and `TraceBoard.tsx`; a future
component with the same shape (whiteboard ink, future drag-gesture bites)
should follow the same pattern from the start, not discover it via a bug
report.

## Solution

### Immediate Fix
Added `activePointerId` ref. `press()` ignores a new pointer while one is
already active and records the winning pointer's id; `follow()`, `release()`
and `drop()` each early-return when the event's `pointerId` doesn't match
the active one, and `release()`/`drop()` clear `activePointerId` once the
active pointer lifts or is cancelled.

```ts
const activePointerId = useRef<number | null>(null);

const press = (event) => {
  if (activePointerId.current !== null) return;
  activePointerId.current = event.pointerId;
  event.currentTarget.setPointerCapture?.(event.pointerId);
  follow(event);
};
```

### Long-term Fix
None needed beyond the pattern above; consider extracting a small shared
`useSinglePointer()` hook if a third component needs the same shape (ink
module / whiteboard is a candidate).

## Prevention
- [x] Code changes required — done, `PlotAnswer.tsx`
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a, client-side UX correctness
- [ ] Documentation to update — covered by this entry

## Related Issues
- Same bug class, same day: TraceBoard.tsx pointer race (PR #152).

## References
- PR #153: `feat/plot-reticle-svgjs`
- `STUDENT/Frontend/src/features/exam-practice/components/PlotAnswer.tsx`

---

**Resolved By:** Claude Sonnet 5 (code review + fix)
**Time to Resolution:** Same session as review
