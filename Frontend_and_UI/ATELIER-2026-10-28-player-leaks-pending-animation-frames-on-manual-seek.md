# Player._scheduleNext leaks pending animation frames under manual seeking

**Date:** 2026-10-28
**Project:** Atelier (pencil-sketch)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
`Player._scheduleNext()` (`frontend/js/player.js`) armed a new
`requestAnimationFrame` registration without canceling any previously
armed one. Invisible under normal playback (the real rAF loop only ever
calls `_tick` once per real frame), this leaked one extra pending frame
per call whenever `_tick` was driven manually and repeatedly from outside
the rAF loop -- exactly what a debug/test "seek to fraction X" helper
does to fast-forward the playhead for screenshot-based verification. Each
leaked frame later fired with the browser's own tiny real elapsed time,
silently overwriting the progress the manual seek had just set.

## Symptoms
- Browser-based Phase 10 verification screenshots showed the on-screen
  progress percentage reading absurdly small values (e.g. "2%") at
  screenshot checkpoints that were deliberately seeked to 50% of the
  timeline.
- The actual canvas drawing content was correct for the requested
  fraction (action cursor advanced proportionally); only the displayed
  progress text/percentage was wrong.

## Environment Details
- **Server/Host:** local dev (served via FastAPI's StaticFiles, no build step)
- **Services Affected:** `frontend/js/player.js` playback engine
- **Related Components:** the `__debugSeekToFraction` test-only escape
  hatch in `frontend/main.js`, used by every browser-driven verification
  script since Phase 8
- **Time First Observed:** 2026-10-28, during Phase 10 duration-aware
  playback verification

## Investigation Steps

### 1. Initial Diagnosis
Compared `window.__debugPlayerState()` readings immediately before and
after a seek call; the action cursor advanced correctly but
`lastProgress.elapsedMs` stayed implausibly small.

### 2. Root Cause Analysis
Added temporary tracing inside `_tick` to log every call's `nowPerf` and
computed playhead value, then ran a single seek call under Playwright.

### 3. Key Findings
- Every one of the debug seek's manual `_tick(largeNowPerf)` calls that
  didn't yet reach completion falls through to `_emitProgress(...)` and
  then `_scheduleNext()`.
- `_scheduleNext()` called `requestAnimationFrame(cb)` again on every
  call without canceling the previous registration -- `requestAnimationFrame`
  registrations are independent entries in a list, not a single mutable
  slot, so nothing stopped earlier ones from firing later.
- Because the debug seek's catch-up loop runs fully synchronously (no
  yield to the event loop), dozens of these registrations piled up
  un-fired during a single seek call. The instant that synchronous call
  returned, the browser fired all of them back-to-back, each with the
  browser's own real (tiny) timestamp, each calling `_emitProgress` with
  a correspondingly tiny elapsed value -- overwriting the correct value
  the seek had just produced.

## Root Cause
`_scheduleNext()` assumed there would only ever be at most one in-flight
`requestAnimationFrame` registration at a time, which is true for the
real playback loop (self-perpetuating: each real frame arms exactly the
next one) but false whenever something outside that loop calls `_tick`
multiple times without an intervening real frame fire.

## Prevention / Rule
**Guardrail:** regression test `"_scheduleNext never leaves more than one
frame request pending at once"` in `frontend/test/player.test.js`, which
mocks `scheduleFrame`/`cancelFrame` with call counters and asserts that
after several manual `_tick` calls, exactly one request remains armed
(`scheduleCount === cancelCount + 1`). Verified this test fails (confirmed
by temporarily reverting the fix and re-running) without the fix and
passes with it.

This closes the gap because the existing test harness's mock
`scheduleFrame`/`cancelFrame` were both no-ops (`makeHarness()` in the
same file), which is exactly why this defect was invisible to the
existing suite despite extensive player test coverage -- the new test is
the first one to actually assert on the scheduling/cancellation
interaction itself.

## Solution

### Immediate Fix
`_scheduleNext()` now calls `this._cancelScheduled()` before arming a new
frame, making repeated calls idempotent regardless of caller.

### Long-term Fix
None needed beyond the above -- it's a general correctness fix with no
behavior change for real (non-seeking) playback.

## Prevention
- [x] Code changes required (`_scheduleNext` in `frontend/js/player.js`)
- [x] Regression test added
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Report: `reports/ATELIER-2026-10-28-phase-10-duration-aware-artistic-planning.md`

## References
- `frontend/js/player.js` -- `_scheduleNext`, `_cancelScheduled`, `_tick`
- `frontend/main.js` -- `__debugSeekToFraction`
- `frontend/test/player.test.js` -- the new regression test

---

**Resolved By:** Claude (pair-programming session with tinomupezeni)
**Time to Resolution:** ~40 minutes (required building a tracing harness to isolate the race)
