# Flutter ElevatedButton crashes when placed directly in a Row

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The Cobalt Sky theme's global `ElevatedButtonThemeData` sets
`minimumSize: Size.fromHeight(kMinTouchTarget)` to guarantee the 48dp
minimum touch target from the HCI guide. `Size.fromHeight` sets width to
`double.infinity` by design (fixed height, unconstrained width) — safe
inside a stretched `Column`, but any `ElevatedButton` placed as a plain
(non-`Expanded`/`Flexible`) child of a `Row` crashes at layout time with
"BoxConstraints forces an infinite width." Caught while writing a widget
test for the POS cart summary bar's "Charge" button, before it shipped.

## Symptoms
- `RenderConstrainedBox.performLayout` assertion failure:
  `BoxConstraints(w=Infinity, ...)` fed into `RenderPhysicalShape.layout()`.
- Would have manifested as a hard crash the first time the POS "Charge"
  button rendered on a real device.

## Environment Details
- **Server/Host:** N/A — client-side layout bug.
- **Services Affected:** `mobile_flutter` app, any screen placing an
  `ElevatedButton` as a direct `Row` child.
- **Related Components:** `core/theme/app_theme.dart`
  (`ElevatedButtonThemeData`), `features/pos/presentation/widgets/
  cart_summary_bar.dart` (the button that triggered it).
- **Time First Observed:** During Phase 3 widget-test authoring,
  2026-11-02.

## Investigation Steps

### 1. Initial Diagnosis
A widget test for `CartSummaryBar` (`Row` containing an `Expanded` total
display + an `ElevatedButton`) failed with a layout assertion as soon as
the cart had an item (the button only renders then).

### 2. Root Cause Analysis
Traced the exception to `RenderConstrainedBox` receiving
`BoxConstraints(w=Infinity, ...)`. `Row` gives non-flex children loose,
unbounded-width constraints on the main axis (each child reports its own
intrinsic width); the `ElevatedButton`'s own `ConstrainedBox` then tries to
satisfy a `minimumSize` whose width is `double.infinity`
(`Size.fromHeight(48)` literally means "height 48, width infinite"),
which has no valid resolution.

### 3. Key Findings
- Audited every other `ElevatedButton` in the app
  (login screen, stock-adjustment sheet, add-to-cart sheet, checkout
  screen, product-list retry button, sale-receipt "New sale" button): all
  of them sit inside a stretched `Column`, a `ListView`, or a
  `Scaffold.bottomNavigationBar` slot — all of which give finite width, so
  none of them hit this. The cart summary bar's `Row` layout was the only
  place in the app with this shape.

## Root Cause
A global button theme optimized for "full-width button in a form" (the
common case) silently breaks the less common "button sized to its content
next to other content in a Row" case, because `Size.fromHeight`'s infinite
width has no safe fallback once a parent gives unbounded width instead of
clamping it.

## Prevention / Rule
**Guardrail:** Any `ElevatedButton` placed as a direct `Row` child must
pass an explicit `style: ElevatedButton.styleFrom(minimumSize: Size(<w>,
kMinTouchTarget))` overriding the app theme's `Size.fromHeight` default —
there is no generic fix at the theme level, since the theme's infinite
width is correct for the common (Column/ListView) case. A widget test that
pumps the real button (not just checks its `height`, as the earlier
48dp-touch-target tests did) is what caught this; the touch-target tests
alone would not have.

## Solution

### Immediate Fix
`cart_summary_bar.dart`'s "Charge" `ElevatedButton` now sets
`style: ElevatedButton.styleFrom(minimumSize: const Size(88, kMinTouchTarget))`,
overriding the infinite-width default for just this button.

### Long-term Fix
No theme-level change — documented here as the pattern to recognize before
placing any future button as a bare `Row` child.

## Prevention
- [x] Code changes required (done — see Solution)
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a (caught pre-release by a widget test)
- [ ] Documentation to update — covered by this entry

## Related Issues
- None.

## References
- `mobile_flutter/lib/core/theme/app_theme.dart`
  (`ElevatedButtonThemeData.minimumSize`)
- `mobile_flutter/lib/features/pos/presentation/widgets/cart_summary_bar.dart`
- `mobile_flutter/test/features/pos/cart_summary_bar_test.dart`
- `reports/CRM-2026-11-02-flutter-mobile-rebuild-phase3-pos-checkout.md`

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** Found and fixed within the same session, before merge.
