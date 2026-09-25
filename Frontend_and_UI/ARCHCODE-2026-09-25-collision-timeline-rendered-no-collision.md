# Collision timeline rendered no collision, and asserted a failure that never happened

**Date:** 2026-09-25
**Project:** ArchCode (`pixel-perfect-replication`)
**Environment:** Development
**Severity:** Critical
**Status:** Resolved

## Summary

The "Thread Collision Timeline" tab in the ArchCode cockpit — the product's signature
teaching visual, and the one element the PRD names as making invisible collapse legible —
rendered identically in the pass and fail states. It also carried a legend asserting
"colliding write" vs "serialized write", a claim the geometry contradicted. A learner
inspecting the failure that the whole product exists to explain was shown a chart with
nothing in it and a caption that was not true.

## Symptoms

- Opening the timeline in either state produced the same four bars in the same positions.
- The only differences between states were bar fill colour and bar width (`22%` vs `10%`),
  which encode nothing about worker behaviour.
- The legend read "colliding write" in the fail state and "serialized write" in the pass
  state, while the read bars overlapped across t=24–32% and the write bars overlapped across
  t=52–56% in *both* states.
- The dirty-read window the PRD identifies as the entire lesson was never marked anywhere.
- No stale-version marker, no contention count, no resource label — the row under contention
  (`seat_id=100`) appeared nowhere in the component.

## Environment Details

- **Server/Host:** Local development, Vite dev server
- **Services Affected:** ArchCode cockpit UI, telemetry pane
- **Related Components:** `src/routes/index.tsx` (`THREADS` const + timeline tab), all
  telemetry tabs
- **Time First Observed:** 2026-09-25, during the HIG design review

## Investigation Steps

### 1. Initial Diagnosis

Read the component rather than the design. The `THREADS` constant and the timeline JSX were
adjacent in the same file.

### 2. Root Cause Analysis

`THREADS` was a hand-authored table of `left` offsets:

```ts
const THREADS = [
  { id: "worker-01", read: 6, write: 34 },
  { id: "worker-02", read: 12, write: 40 },
  { id: "worker-03", read: 18, write: 46 },
  { id: "worker-04", read: 24, write: 52 },
];
```

Rendered with a fixed `width: "26%"` read bar and a fixed write bar whose width was
interpolated on `passed`. Nothing anywhere computed overlap. Bars were positioned by hand,
so any change to the data required manually re-tuning offsets to keep the picture honest —
and nothing detected when a hand-tuned offset stopped matching the claim.

Computed the actual geometry to confirm rather than eyeball it: read bars at
left = {6, 12, 18, 24}% with width 26% produce overlaps on [24, 32] in both states; write
bars at left = {34, 40, 46, 52}% with width 22% produce overlaps on [52, 56] in both states.

### 3. Key Findings

- **The visualization was not a function of the data.** Pass/fail was a CSS class switch on
  a hand-positioned layout. The chart could not have distinguished the two states even in
  principle, because the information that distinguishes them was never computed.
- **The failure mode was worse than absence.** The legend stated a specific, checkable claim
  ("colliding write") that the marks on screen refuted. A wrong chart teaches the wrong
  lesson more durably than an absent one, because the learner has no cue that it is wrong.
- **The underlying framing was also incorrect, and this was the deeper defect.** The legend
  implied the bug was write/write collision. It is not. The real log line is
  `read-then-write window 41ms on seat_id=100` — the writes are *serialized*; the defect is
  that two workers held version 3 across another worker's commit, so both wrote `stock=9`
  and 114 grants were issued for 100 seats. Building a write-overlap sweep, which is what
  the old legend implied, would have found *nothing* in the actual failure and reported the
  system as clean.

## Root Cause

A visualization that illustrates a claim instead of deriving it. The component encoded its
conclusion as static layout and asserted the conclusion in a legend, so the two could drift
apart silently and neither was checked against the data. Because the conclusion was authored
rather than computed, no input could ever falsify it.

## Prevention / Rule

**Guardrail:** Every state in a diagnostic visualization must be computed from the same data
structure that feeds the surrounding text output, and asserted to differ between the states
it claims to distinguish — a regression test that fails if the derived result is identical
across states that are documented to behave differently.

This closes the gap because the defect was not a wrong offset or a bad colour; it was that
nothing in the pipeline compared the chart against the data or the legend against the chart.
A computed derivation plus a state-differing assertion makes both divergences impossible to
merge unnoticed: if the pass and fail inputs ever produce the same derivation, the test
fails rather than the UI quietly lying.

## Solution

### Immediate Fix

Replaced the hand-positioned markup with a derived timeline (`src/lib/timeline.ts` +
`src/components/arch/collision-timeline.tsx`):

1. Modelled the run as an event log of read and write spans, each carrying the row version
   observed or committed.
2. Implemented the actual invariant: *a worker's read→write span must not contain another
   worker's commit to the same row that advances the version past the one the worker read.*
3. Derived the conflict regions from that invariant, so pass/fail is a property of the data
   rather than a prop driving a class name.
4. Added `scripts/verify-timeline.ts` asserting the fail state yields exactly one 41ms
   window and the pass state yields none.

```bash
npm run test:timeline
```

The derived fail-state window is now 41ms, matching the terminal's own
`read-then-write window 41ms on seat_id=100` line — the chart and the log agree because
both are computed from the same events.

### Long-term Fix

- The conflict region is encoded with a hatch pattern, a participant count and a label rather
  than hue, so it survives greyscale and colour-vision deficiency.
- The band is a `<button>` with `aria-pressed`, selecting it dims non-participant lanes, and
  the region exposes a `role="img"` summary plus a "Describe in text" disclosure, so the
  finding is available to a screen reader rather than existing only as geometry.
- The pass state renders an explicit protected-region hatch and states that no worker held a
  read across a commit, instead of showing the same empty space.

## Prevention

- [x] Derivation logic in a testable module with assertions over both states
- [x] npm script for the assertion suite (`npm run test:timeline`)
- [x] Chart state derived from data, not from a `passed` prop
- [ ] Carry the same treatment to the Invariant Matrix and Database State Diff tabs, which
      are still hand-authored tables with the same latent drift risk

## Related Issues

- Filed in the same session as the design review: the review's Critical 1. Contrast and
  colour-semantics defects from that review are logged separately.

## References

- `ARCHCODE-DESIGN-REVIEW.md` — Critical 1 (timeline inert), and the framing correction
- `ARCHCODE-PRD.md` §9 — telemetry views, "highlighting red bars where two workers held
  conflicting locks"
- `ARCHCODE-pressure-test.md` §1 — the capability lost if performance grading is dropped
- `src/lib/timeline.ts` — the invariant and its derivation
- `scripts/verify-timeline.ts` — assertions over both states

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~1 hour
