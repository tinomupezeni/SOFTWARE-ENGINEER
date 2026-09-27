# Modal dialog declared `aria-modal="true"` with no focus trap, so Tab walked behind it

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The keyboard-shortcut help dialog rendered `role="dialog" aria-modal="true"` and focused its
close button on open, but implemented no focus containment. Because it was a fixed overlay on
top of a still-interactive page, Tab from the single close button moved focus to the next
focusable element in the *document* — the spec tabs behind the overlay — and continued
through the whole cockpit while `aria-modal` told assistive technology that nothing outside the
dialog was reachable. The dialog was in fact the exact opposite of modal.

## Symptoms
- With the dialog open, one Tab press moved focus out of the dialog to the page behind it.
- Focus continued cycling through the cockpit indefinitely; there was no way back to the dialog
  except Shift+Tab or clicking.
- The focused element was invisible: it sat behind the overlay.
- `aria-modal="true"` was present, so a screen reader announced a modal region while focus was
  in a different region entirely.

## Environment Details
- **Server/Host:** local dev (`npm run dev`, Vite)
- **Services Affected:** `src/components/arch/shortcut-help.tsx`
- **Related Components:** `use-shortcuts`, spec/telemetry tab roving-tabindex handlers
- **Time First Observed:** 2026-09-26, real-interaction pass over the step-5 build

## Investigation Steps

### 1. Initial Diagnosis
Driving the dialog with real CDP key events rather than by reading the markup, then logging
`document.activeElement` after each Tab.

### 2. Root Cause Analysis
```bash
grep -n 'aria-modal\|addEventListener("keydown"\|onKeyDown' src/components/arch/shortcut-help.tsx
# -> role="dialog" / aria-modal="true" present; no keydown handler
```

The dialog declared itself modal in ARIA terms and did nothing about focus, so the two halves
of modality diverged.

### 3. Key Findings
- The dialog contains exactly one focusable control (its close button), making the wrap-around
  behaviour easy to miss: a two-element cycle looks correct, so the leak is only visible once
  the *next* element outside the dialog is identified.
- The cockpit behind the dialog uses roving `tabindex`, so focus landed on a spec tab —
  a real, focusable, invisible-behind-the-overlay control.
- This only surfaces under keyboard interaction. Mouse-driven review passed, because a click
  anywhere outside would also have closed the dialog and masked it.

## Root Cause
`aria-modal` is a declaration to assistive technology, not a behaviour. Modal focus behaviour
is a separate, manual implementation: intercept Tab/Shift+Tab, compute the dialog's
focusable set, and wrap the ends. The dialog implemented the declaration and omitted the
behaviour. Focus management on open (autofocus the close button, and restore focus to the
invoking element on close) was present, which is what made the gap easy to overlook — the
dialog looked deliberately focus-managed in review.

## Prevention / Rule
**Guardrail:** Add a keyboard interaction check to the mandatory pre-deploy verification
procedure: for every `aria-modal` element in the app, open it, press Tab more times than the
dialog contains focusable elements, and assert focus is still inside the dialog; then press
Shift+Tab and assert the same; then assert focus returns to the invoking element on close.

No static check can catch this, because a `role="dialog"` with no handler is valid, common, and
indistinguishable from a correct one by grep. It is only observable by driving real Tab
presses, so it must be an explicit item in the browser-verification procedure rather than an
optional extra.

## Solution

### Immediate Fix
Added a window-level `keydown` handler that collects the dialog's focusable elements,
filters out anything not rendered, and wraps focus:

```ts
const first = focusable[0];
const last = focusable[focusable.length - 1];
if (!first || !last) {
  e.preventDefault();
  return;
}
if (e.shiftKey && (!inside || active === first)) {
  e.preventDefault();
  last.focus();
} else if (!e.shiftKey && (!inside || active === last)) {
  e.preventDefault();
  first.focus();
}
```

Focus is also restored to the invoking element on close. The `first`/`last` narrowing is
explicit rather than a non-null assertion, because `noUncheckedIndexedAccess` makes an
in-bounds index read `T | undefined` and a `!` would have hidden a real "empty after
filtering" case.

### Long-term Fix
Fold the Tab-cycling assertion above into the standing browser-verification procedure so any
future dialog is covered automatically.

## Prevention
- [x] Focus trap implemented
- [x] Focus restored to the invoking element on close
- [x] Dedicated focus suite: 12 passed, 0 failed
- [x] Full interaction suite: 75 passed, 0 failed, no runtime errors
- [ ] Add the "every `aria-modal` traps focus" check to `pre_deploy_verification.md`

## Related Issues
- `Frontend_and_UI/ARCHCODE-2026-09-26-no-keyboard-operability-in-keyboard-driven-cockpit.md`
- `reports/ARCHCODE-2026-09-26-keyboard-shortcut-system.md`

## References
- `src/components/arch/shortcut-help.tsx`
- `ARCHCODE-2026-09-26-guardrails-that-could-not-fail.md`
- WCAG 2.1 SC 2.4.3 Focus Order, SC 4.1.2 Name/Role/Value

---

**Resolved By:** Claude (Anthropic), on behalf of the user
**Time to Resolution:** ~45 minutes
