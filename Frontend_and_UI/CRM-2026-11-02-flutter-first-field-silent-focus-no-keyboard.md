# Flutter: first TextField in a freshly-built subtree never opens the keyboard on tap

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Environment:** Development (reproduced on a real Android 15 device)
**Severity:** High
**Status:** Resolved

## Summary
In the POS checkout's new-walk-in-customer form, the first `TextField`
(Name) never opened the on-screen keyboard on tap — every subsequent field
(Phone) worked perfectly on the very first tap. Root cause: Flutter can
silently grant framework-level focus to the first focusable descendant of
a subtree that's swapped into an already-active `FocusScope` (here, a
bottom sheet switching from a search view to a form view), without ever
opening the actual platform `TextInputConnection`. The field's
`FocusNode.hasFocus` reports `true`, so a user's first real tap is — from
Flutter's point of view — not a focus change at all, and the "show
keyboard" side effect never fires.

## Symptoms
- Tapping the "Name" field in the new-customer form did nothing visible:
  no keyboard, no cursor blink change, `adb shell dumpsys input_method`
  showed `mInputShown=false` even seconds after the tap.
- The *second* field (Phone) always worked correctly, first tap, every
  time — including as the very first interaction in a completely fresh
  form instance.
- `ElevatedButton`/`TextButton` taps elsewhere in the same sheet worked
  normally throughout (ruling out a hit-testing/coordinate problem).

## Environment Details
- **Server/Host:** N/A — client-side Flutter bug.
- **Services Affected:** `mobile_flutter` app, `ContactPickerSheet`'s
  new-customer form (any screen with an analogous "swap sheet content to a
  form with its own first TextField" pattern is equally exposed).
- **Related Components:**
  `features/pos/presentation/widgets/contact_picker_sheet.dart`.
- **Time First Observed:** 2026-11-02, during a real-device walkthrough of
  the new receipt/walk-in-customer feature.

## Investigation Steps

### 1. Initial Diagnosis
Assumed a coordinate problem (a recurring theme this session — see the
pairing-port and screenshot-scale mistakes logged separately) and
re-measured the field's exact on-screen pixel bounds via PIL. Coordinates
were correct; the tap still didn't focus the field.

### 2. Root Cause Analysis
Used `adb shell dumpsys input_method | grep mInputShown` as ground truth
for "is the platform keyboard actually connected," independent of
screenshots. Systematically isolated variables:
- Fresh app process (ruled out stale-engine state): bug persisted.
- Explicit `FocusNode` instead of an implicit one: no change.
- Removed `textCapitalization`: no change.
- **Swapped field order** (Phone first, Name second): the bug *moved with
  the position* — whichever field was now first failed, whichever was
  second worked. This was the conclusive test.

### 3. Key Findings
- The bug is strictly positional (first focusable descendant of the
  newly-built subtree), not tied to any specific field's configuration.
- It reproduces specifically when the new subtree replaces content inside
  an *already-focused* `FocusScope` (the search `TextField` above it had
  `autofocus: true` and held focus right before the swap).
- `WidgetsBinding.instance.addPostFrameCallback` to defer the swap by one
  frame did **not** fix it — ruling out a build/animation timing race.
- The actual fix: inside the *new* form's `initState`, schedule a
  post-frame `FocusScope.of(context).unfocus()`. This clears whatever
  silent auto-focus Flutter assigned, so the user's first real tap is a
  genuine 0→1 focus transition and correctly opens the IME.

## Root Cause
Flutter's focus system can auto-claim the first focusable node of a newly
built subtree to satisfy an "always something is focused within an active
scope" invariant, without actually establishing a platform text-input
connection. The `TextField`'s own tap handler only requests focus (and
asks the platform to show the keyboard) when the `FocusNode` transitions
from unfocused to focused; if it's already (silently) focused, the tap is
a no-op from the framework's perspective.

## Prevention / Rule
**Guardrail:** Any time a bottom sheet / dialog swaps its content from one
subtree to another *within the same still-mounted modal route* (not a
fresh route push), and the new subtree contains its own `TextField`(s),
add a post-frame `FocusScope.of(context).unfocus()` in the new subtree's
`initState()`. Pushing a brand-new route (e.g. `Navigator.push`) does not
need this — the issue is specific to content swapped in place inside an
already-focused scope.

This closes the gap because the root cause is exactly "a field was already
silently focused without an IME connection" — explicitly unfocusing after
the new subtree's first frame guarantees the next tap is a real focus
transition.

## Solution

### Immediate Fix
`_NewCustomerFormState.initState()` now does:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) FocusScope.of(context).unfocus();
});
```
Verified fixed on the real device: `mInputShown=true` on first tap, for
either field, in either order.

### Long-term Fix
No code change beyond the guardrail above. Future screens built on the
same "swap content within one modal route" pattern should follow it from
the start rather than rediscovering this the hard way.

## Prevention
- [x] Code changes required (done — see Solution)
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a (caught via manual real-device testing)
- [x] Documentation to update — this entry

## Related Issues
- None directly, but see the same session's
  `DevOps_and_Infrastructure/DevEnv-2026-11-02-adb-wireless-pairing-port-confusion.md`
  and the Phase 3 report's "screenshot scale" mistake — same session had
  two other instances of "assumed a coordinate/input problem, root cause
  was elsewhere."

## References
- `mobile_flutter/lib/features/pos/presentation/widgets/contact_picker_sheet.dart`
- `reports/CRM-2026-11-02-flutter-pos-receipt-and-walkin-customer.md`

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** Found and fixed within the same session, verified on real hardware before merge.
