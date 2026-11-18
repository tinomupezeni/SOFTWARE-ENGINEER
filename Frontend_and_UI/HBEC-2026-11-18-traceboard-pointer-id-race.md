# TraceBoard let a second touch reset an in-progress stroke

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (caught in code review, pre-merge)
**Severity:** Medium
**Status:** Resolved

## Summary
`TraceBoard` (`STUDENT/Frontend/src/features/junior/TraceBoard.tsx`), the
"Trace it" drawing surface, tracked the in-progress stroke in mutable
closures (`points`, `steady`, `line`) shared across all pointer events with
no check on `event.pointerId`. A second simultaneous pointer — a child's
palm touching the board mid-stroke, or two fingers — reset the first
pointer's accumulated stroke, corrupting the points eventually handed to the
rules for judging.

## Symptoms
- No user-visible report yet; found during code review of PR #152
  (`feat/kids-trace-ink`).
- A young child's palm or second finger touching the board mid-stroke fires
  a second `pointerdown`; the handler unconditionally restarted tracking,
  discarding the first pointer's points. The next `pointerup` (from either
  pointer) would commit a truncated/wrong stroke, producing an incorrect
  hint or pass/fail judgement for a stroke the child never actually drew
  that way.

## Environment Details
- **Services Affected:** STUDENT/Frontend (React), junior/Kids Trace it
  feature
- **Related Components:** `features/junior/TraceBoard.tsx`

## Investigation Steps

### 1. Initial Diagnosis
Code review flagged that `down`/`move`/`up` closures over `points`/`steady`/
`line` have no guard distinguishing which physical pointer they're tracking.

### 2. Root Cause Analysis
`PointerEvent.pointerId` exists specifically to distinguish concurrent
touch/pen/mouse contacts, but none of the three handlers read it. `down`
would call `setPointerCapture` for whichever pointer fired it, but capture
alone doesn't stop a *different* pointer's events from also reaching the
same listeners and mutating the same shared state.

### 3. Key Findings
- `svg.js`'s own event delegation (`draw.on('pointerdown', ...)`) fires for
  every pointer that touches the element — it does not scope by pointer on
  its own.
- The same bug class exists wherever a drawing/gesture surface tracks state
  in module-local mutable variables instead of keyed-by-pointer state.

## Root Cause
Multi-touch is a hardware reality on tablets/phones a child uses with their
whole hand, and the handlers assumed single-pointer input without stating or
enforcing that assumption.

## Prevention / Rule
**Guardrail:** an `activePointerId` variable now gates all three handlers:
`down` is a no-op if a pointer is already active, and `move`/`up` ignore any
event whose `pointerId` doesn't match the active one. This is the standard
single-active-pointer pattern for pointer-event-based drawing surfaces, and
it generalizes to any future gesture surface built on the same `svg.js`
event pattern in this codebase (the whiteboard/plot-reticle work mentioned
in this PR's own "next" notes).

## Solution

### Immediate Fix
```typescript
let activePointerId: number | null = null;

const down = (e: PointerEvent) => {
  if (live.current.done || activePointerId !== null) return;
  e.preventDefault();
  activePointerId = e.pointerId;
  // ...
};
const move = (e: PointerEvent) => {
  if (!steady || e.pointerId !== activePointerId) return;
  // ...
};
const up = (e: PointerEvent) => {
  if (!steady || e.pointerId !== activePointerId) return;
  activePointerId = null;
  // ...
};
```

### Long-term Fix
None needed beyond the above; contained to `TraceBoard.tsx`.

## Prevention
- [x] Code changes required (done)
- [ ] Regression test added — not added: this requires simulating two
  concurrent native `PointerEvent`s against the `svg.js`-rendered SVG in
  jsdom, which the existing `trace.test.ts` suite doesn't exercise at all
  (it tests the pure rules in `trace.ts`, not the DOM component). Worth a
  follow-up if `TraceBoard.tsx` gains component-level tests.
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a

## Related Issues
- Same PR's `bites.ts` first-take quota bug (see
  `HBEC-2026-11-18-bites-build-crowded-out-by-first-take-quotas.md`).

## References
- PR #152 (`feat/kids-trace-ink`)

---

**Resolved By:** Claude Sonnet 5 (agent session)
**Time to Resolution:** Same session as discovery
