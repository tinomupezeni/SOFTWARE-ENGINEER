# The problem selector was a `<button>` with a chevron that did nothing

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The cockpit header rendered "Problem #42: The Flash Sale Over-Allocation" inside a `<button>`
carrying a `ChevronDown` icon and a `hover:border-accent/50` border transition. The button had
no `onClick`, no menu, and no state: it was styled to look exactly like a dropdown trigger and
did nothing when activated. This is the archetype of a dead affordance, and it sat in the
product's most prominent position — the one control that looked like it let a user switch
problems in a product built around many problems.

## Symptoms
- Clicking the problem chip in the header did nothing: no menu, no change, no feedback.
- The chip showed a chevron and a hover border, promising a menu that did not exist.
- Keyboard activation (`Enter`/`Space`) also did nothing, since the element had no handler.
- A button with no action is announced by assistive technology as a control and is focusable,
  so it was a tab stop that led nowhere.

## Environment Details
- **Server/Host:** local dev (`npm run dev`, Vite)
- **Services Affected:** `src/routes/index.tsx` (cockpit header)
- **Related Components:** `src/components/arch/scenario-picker.tsx`
- **Time First Observed:** 2026-09-26, while implementing step 5's scenario selection

## Investigation Steps

### 1. Initial Diagnosis
Read the header while working out where the scenario picker belonged.

### 2. Root Cause Analysis
```bash
git show HEAD:src/routes/index.tsx | sed -n '117,124p'
# <button className="group hidden min-w-0 items-center gap-2 rounded-md border border-border
#   bg-card px-3 py-1.5 text-xs transition-colors hover:border-accent/50 lg:flex">
#   <span className="truncate font-medium">Problem #42: The Flash Sale Over-Allocation</span>
#   <Pill tone="amber">Medium</Pill>
#   <span className="truncate text-muted-foreground">Concurrency &amp; Locking</span>
#   <ChevronDown className="h-3.5 w-3.5 text-muted-foreground" />
```
No `onClick`, no `aria-*` state, no menu component.

### 3. Key Findings
- The element was `hidden … lg:flex`, so it disappeared entirely below the `lg` breakpoint while
  leaving the layout to reflow — a second-order problem: the "problem" identity vanished
  without a replacement on smaller screens.
- It was also a `<button>`, so it was focusable and announced as an actionable control, making
  the lie stronger for keyboard and screen-reader users than for mouse users.
- The PRD has exactly one problem, so a functional problem-switcher would also have been
  premature. The correct fix was to remove the promise, not to build the menu.

## Root Cause
Scaffolding drew the control it expected the finished product to have — a multi-problem IDE
with a problem switcher — without wiring behaviour, and the visual affordances (chevron, hover
border, button element) survived while the functionality did not arrive. Nothing in the build
flags a button with no handler, so the gap is invisible to typecheck, lint, and build.

## Prevention / Rule
**Guardrail:** Add to `scripts/verify-semantics.ts` a check that fails on interactive
elements carrying affordance affordances with no behaviour: any `<button>` rendered without an
`onClick`/`onKeyDown`/`type="submit"` and not inside a `<form>`, and any element with a
`ChevronDown`/caret icon that is not wrapped in a control with a handler.

Dead affordances are a styling bug, so the guardrail has to be a source check keyed on
affordance markers (chevron, caret, ellipsis) rather than on runtime behaviour, because a
button that renders and does nothing is indistinguishable from a working one in any
screenshot or DOM snapshot.

## Solution

### Immediate Fix
Removed the `<button>` and its chevron. The problem identity is now a static, non-interactive
label in the header, and the control that genuinely does change state — the scenario picker —
is placed directly beneath it as a real APG radiogroup with a visible selected state.

The product now only shows a switcher where a switcher works, and the single-problem reality of
the PRD is not dressed up as a menu.

### Long-term Fix
If multi-problem support arrives with its own design review, the switcher can be built for
real and guarded by the check above.

## Prevention
- [x] Dead affordance removed
- [x] Replaced with a working, stateful control (scenario radiogroup)
- [ ] Add the dead-affordance guardrail to `verify-semantics.ts`
- [ ] Audit the remaining scaffold chrome for chevron/caret controls with no handler

## Related Issues
- `reports/ARCHCODE-2026-09-26-step5-product-surface.md`

## References
- `src/routes/index.tsx` (cockpit header)
- `src/components/arch/scenario-picker.tsx`

---

**Resolved By:** Claude (Anthropic), on behalf of the user
**Time to Resolution:** ~20 minutes
