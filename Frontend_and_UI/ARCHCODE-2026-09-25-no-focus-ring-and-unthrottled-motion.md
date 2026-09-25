# No focus indicator anywhere, and an infinite animation carrying the only status signal

**Date:** 2026-09-25
**Project:** ArchCode (`pixel-perfect-replication`)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary

ArchCode is an entirely keyboard-driven tool — the PRD specifies `⌘↵` to run, `⌘⇧↵` to
submit and `⌘1`–`⌘4` for telemetry tabs — and it shipped with no visible focus indicator on
any interactive element, while defining a `--ring` token in both colour palettes and never
using it. Separately, an infinite 2-second pulse on the "Engine: Ready" dot was the only
indication the engine was live, and the project contained no
`prefers-reduced-motion` guard anywhere.

## Symptoms

- Keyboard users could not tell which element had focus. The browser default was suppressed
  by Tailwind's preflight, so focus was entirely invisible, not merely unstyled.
- The "Engine: Ready" dot pulsed indefinitely to signal liveness. With
  `prefers-reduced-motion: reduce` set, the dot sat at full opacity and became
  indistinguishable from a static indicator.
- Terminal output blocks carried `animate-pulse` with the same problem.

## Environment Details

- **Server/Host:** Local development
- **Services Affected:** Every interactive element; engine status indicator
- **Related Components:** `src/styles.css`, `src/routes/index.tsx`
- **Time First Observed:** 2026-09-25, during the HIG design review

## Investigation Steps

### 1. Initial Diagnosis

Searched for focus styling and motion preferences rather than assuming their absence.

### 2. Root Cause Analysis

```bash
grep -rn "focus-visible\|focus:ring\|ring-ring\|aria-\|role=" src/
grep -rn "prefers-reduced-motion" src/
grep -n "\-\-ring" src/styles.css
```

Zero focus styles in product code. Zero `prefers-reduced-motion` rules. `--ring` defined at
both `:94` and `:131` and mapped to `--color-ring` at `:48`, referenced nowhere.

### 3. Key Findings

- `--ring` was fully plumbed — declared, mapped to a colour, registered with Tailwind — and
  still unused. Every layer of the design system anticipated focus styling; the application
  layer never asked for it. This is not a missing token, it is a missing application of one.
- Tailwind's preflight removes the UA focus outline, so absence of a custom style means
  *zero* focus indication rather than a default one.
- `pulse-dot` is defined in `styles.css:180` and applied to the engine status dot. The dot's
  animation is the only signal distinguishing "engine live" from "engine idle", so removing
  it under a motion preference would have removed information rather than decoration.

## Root Cause

No accessibility pass ever ran against the built UI, and nothing in the build would have
failed. Both defects are invisible in review because neither produces an error: a missing
focus ring and an unthrottled animation look identical to a reviewer who is not navigating
by keyboard, and a screenshot of the animated state looks fine.

## Prevention / Rule

**Guardrail:** Treat any infinite animation that encodes a status as requiring an explicit
static alternative for `prefers-reduced-motion`, and assert that every interactive component
declares a focus style — enforced as a build-time check or a documented per-component
requirement, since neither is detectable by a visual review.

This closes the gap because both defects share a root condition: they are only observable
under conditions a standard review does not reproduce (keyboard navigation; a motion
preference). The guardrail converts each into a requirement that must be satisfied
explicitly, and the token-existence check catches the second class — a focus token that is
declared but never applied is otherwise indistinguishable from one that is genuinely absent.

## Solution

### Immediate Fix

- Added a global `:focus-visible` rule using the existing `--ring`, with `outline-offset: 2px`.
  Uses `focus-visible` rather than `focus` so pointer interaction does not show a ring.
- Added a `prefers-reduced-motion: reduce` block that neutralises animations and transitions
  project-wide.
- Under that preference, `.pulse-dot` keeps its meaning via a static
  `box-shadow` ring, so "engine live" is still distinguishable from "engine idle" without
  motion.

```css
:focus-visible {
  outline: 2px solid var(--color-ring);
  outline-offset: 2px;
}

@media (prefers-reduced-motion: reduce) {
  .pulse-dot {
    animation: none;
    box-shadow: 0 0 0 2px color-mix(in oklab, var(--color-primary) 55%, transparent);
  }
}
```

### Long-term Fix

- Keyboard shortcuts from the PRD (`⌘↵`, `⌘⇧↵`, `⌘1`–`⌘4`) are still unimplemented. The
  focus ring is necessary but not sufficient for keyboard operability; a keyboard user can
  now see focus but still cannot run or submit.
- The new conflict region is a `<button>` with `aria-pressed`, so it is focusable and
  announces its state. This is the first focusable, stateful element in the product and
  serves as the pattern for the rest.

## Prevention

- [x] Global `:focus-visible` using the existing `--ring` token
- [x] `prefers-reduced-motion` guard with a static status alternative
- [ ] Implement the PRD's keyboard shortcuts — this remains the larger open gap
- [ ] Add a CI check that fails when a new infinite animation is introduced without a
      reduced-motion alternative

## Related Issues

- Design review Critical 4 and Critical 5
- `ARCHCODE-2026-09-25-collision-timeline-rendered-no-collision.md` — the first focusable
          element in the product

## References

- `ARCHCODE-DESIGN-REVIEW.md` — Critical 4, Critical 5
- `ARCHCODE-PRD.md` §12 — accessibility as design input
- `src/styles.css` — `:focus-visible`, reduced-motion block, `pulse-dot`
- WCAG 2.2 SC 2.4.7 (Focus Visible), SC 2.3.3 (Animation from Interactions)
- Apple HIG, *Focus and selection*; *Motion*

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~20 minutes
