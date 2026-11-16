# Trade picker bottom sheet unreadable on devices without backdrop-blur support

**Date:** 2026-11-16
**Project:** MARITCHO
**Environment:** Production (web frontend)
**Severity:** Medium
**Status:** Resolved

## Summary
The "Who do you need?" trade picker bottom sheet used a translucent surface
color (`rgba(30, 41, 59, 0.82)`) intended to read as frosted glass over a
backdrop-blur filter. On phones without backdrop-blur support, the blur
never applied, so the busy page content behind the sheet showed straight
through the text, making the skill list unreadable. The sheet's body also
let its children shrink when content overflowed, squashing list items.

## Symptoms
- Trade/skill picker sheet text unreadable over busy backgrounds on some
  mobile browsers.
- Sheet content visually compressed when the list was taller than the
  available space.

## Environment Details
- **Server/Host:** N/A (client-side CSS)
- **Services Affected:** `frontend` web app, `TradePickerSheet` component
- **Related Components:** `src/styles/tokens.css`, `src/styles/components.css`,
  `src/features/jobs/TradePickerSheet.tsx`
- **Time First Observed:** PR #10, opened 2026-11-13

## Investigation Steps

### 1. Initial Diagnosis
Reviewed PR #10 (`fix/solid-trade-picker-sheet`) diff against `main`.

### 2. Root Cause Analysis
Traced `--color-sheet` token to its only consumer, the `.sheet` surface
class, and confirmed no `backdrop-filter` fallback existed for browsers
that don't support it — the translucency assumed blur would always render.

### 3. Key Findings
- `--color-sheet: rgba(30, 41, 59, 0.82)` relied entirely on backdrop blur
  for readability.
- `.sheet__body` children had no `flex-shrink: 0`, so a scrollable body
  could still compress its own list items instead of just scrolling.
- `TradePickerSheet.tsx` carried a stray `marginTop: -4` inline override
  compensating for the old spacing, no longer needed once body layout was
  fixed.

## Root Cause
A translucent surface color was used as a glass effect without a solid
fallback for devices/browsers where `backdrop-filter` has no effect,
combined with flex children that were allowed to shrink inside a
scrollable container.

## Prevention / Rule
**Guardrail:** The visual-regression suite (`frontend/e2e/visual/screens.spec.ts`)
now has a dedicated screen (`04b-who-do-you-need`) with a committed baseline
screenshot for this exact sheet-over-content state, so any future
translucency/overflow regression fails CI instead of surfacing in
production.

This closes the gap because the original bug had no visual test covering
a sheet opened over busy content — only functional screens were captured.

## Solution

### Immediate Fix
N/A — caught in PR review before any production exposure.

### Long-term Fix
- Changed `--color-sheet` to a solid `#1e293b` and darkened `--color-scrim`
  to `rgba(2, 6, 23, 0.7)`, removing the dependency on backdrop blur for
  readability.
- Added `.sheet__body > * { flex-shrink: 0; }` so body content scrolls
  instead of squashing.
- Added `.sheet:focus { outline: none; }` since the sheet takes focus on
  open (for Escape/screen-reader behavior) but shouldn't itself show a
  focus ring — its controls show their own.
- Removed the now-unneeded `marginTop: -4` inline override in
  `TradePickerSheet.tsx`.
- Added the `04b-who-do-you-need` visual regression screen + baseline PNG.

## Prevention
- [x] Visual regression test added
- [ ] Monitoring/alerts to add — N/A, client-side CSS
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- PR #10 (`fix/solid-trade-picker-sheet`), merged into `main` at 8d2e8cb.

## References
- `frontend/src/styles/tokens.css`
- `frontend/src/styles/components.css`
- `frontend/src/features/jobs/TradePickerSheet.tsx`

---

**Resolved By:** tinomupezeni (PR review + merge via Claude Code)
**Time to Resolution:** Same-day (reviewed and merged 2026-11-16)
