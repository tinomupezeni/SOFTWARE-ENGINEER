# MakePage's mission question shows stale hint state on re-entry

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (caught in code review, pre-merge)
**Severity:** Low
**Status:** Resolved

## Summary
`MissionPlay`'s "What did you notice?" question (`screen === 'question'`)
kept its `step`/`choice` state across visits. A child who answered wrong
once (entering the hint phase, with that option disabled), backed out to
"Steps" without answering correctly, and reopened the question saw the
hint bubble and disabled option immediately — before tapping anything on
the new attempt.

## Symptoms
- No user report; found in code review of PR #151.
- A fresh attempt at a mission's question visually looked like a second
  attempt from the first tap.

## Environment Details
- **Services Affected:** STUDENT/Frontend, junior/Make feature
- **Related Components:** `features/junior/MakePage.tsx` (`MissionPlay`)

## Investigation Steps

### 1. Initial Diagnosis
`step`/`choice` are plain `useState` initialized once per mount of
`MissionPlay`; the component itself doesn't unmount between "Steps" and
"What did you notice?" — it's the same component switching over an internal
`screen` enum.

### 2. Root Cause Analysis
The only place `screen` transitions to `'question'` is the "What did you
notice?" button; it set `setScreen('question')` without resetting the
question-answering state (`step`, `choice`) that a previous attempt (in the
same `MissionPlay` mount) may have left in a non-fresh phase.

### 3. Key Findings
- `onLeave={() => setScreen('steps')}` on the question view correctly
  returns to the steps screen, but doesn't reset anything either — the
  reset has to happen on (re-)entry, not on leave, since leave doesn't know
  whether the child will come back.

## Root Cause
State belonging to one "attempt" of the question outlived the attempt
because nothing cleared it when a new attempt started.

## Prevention / Rule
**Guardrail:** whenever a screen transition re-enters a sub-flow that has
its own local progress state, reset that state at the entry point, not
hoped-for at the exit point — since the exit (`onLeave`) doesn't know if the
flow will be re-entered or abandoned for good.

## Solution

### Immediate Fix
The button that transitions to `screen === 'question'` now also calls
`setStep(FRESH_STEP)` and `setChoice(null)` before `setScreen('question')`.

### Long-term Fix
None needed; this is the correct, minimal fix point (the single entry).

## Prevention
- [x] Code changes required (done)

## Related Issues
- Found alongside 3 other #151 bugs in the same review pass.

## References
- `/code-review` of PR #151, 2026-11-18

---

**Resolved By:** Claude (code review + fix)
**Time to Resolution:** Same session
