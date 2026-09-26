# Run and Submit were live-looking but inert; now gated on a real capability

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
After step 3 added keyboard shortcuts and step 4 removed the fabricated verdict, the two
primary actions were still fully dressed as working: solid primary/secondary styling,
`⌘↵` / `⌘⇧↵` printed directly on the buttons, `aria-keyshortcuts` exposed, and live key
bindings — all wired to empty handlers, because the cockpit has no runner. Pressing `⌘↵`
did nothing at all. A primary action that presents as available and silently does nothing is
the most expensive kind of broken, because a user discovers it by believing the product works.
Rather than delete the actions (they are core to the design) or leave them live, availability
is now a single declared capability that both the buttons and the key bindings read.

## Symptoms
- "Run Chaos Test" and "Submit Architecture" rendered as active primary/secondary buttons.
- `<kbd>` hints `⌘↵` and `⌘⇧↵` printed on the buttons, inviting the press.
- `aria-keyshortcuts` announced both bindings to assistive tech.
- The shortcut sheet listed Run and Submit as ordinary working shortcuts, and its footer
  asserted "Run and Submit work while the editor has focus".
- Pressing either shortcut, or clicking either button, produced no result and no explanation.

## Environment Details
- **Server/Host:** local dev (`npm run dev`, Vite)
- **Services Affected:** `src/routes/index.tsx`, `src/lib/runner.ts` (new), `src/lib/shortcuts.ts`,
  `src/lib/use-shortcuts.ts`, `src/components/arch/shortcut-help.tsx`
- **Related Components:** `TopBar`, `ShortcutHelp`
- **Time First Observed:** 2026-09-26, immediately after the step 3 keyboard pass

## Investigation Steps

### 1. Initial Diagnosis
Confirmed the handlers were empty functions and that no runner, container spawn, or grading
path existed anywhere in the codebase.

```bash
grep -n "run: () =>\|submit: () =>" src/routes/index.tsx
# run: () => {},
# submit: () => {},
```

### 2. Root Cause Analysis
The keyboard pass declared bindings for the *designed* product without distinguishing "this
binding is part of the design" from "this binding can fire today". The registry had no concept
of availability, so `useShortcuts` matched the combo, called `preventDefault()`, and invoked a
no-op. The `preventDefault()` is what made it actively harmful: `⌘↵` was swallowed and
replaced with silence.

### 3. Key Findings
- The two surfaces were independent. A disabled button with a live shortcut — or a live button
  with a dead shortcut — is the same defect one layer up from step 4's, and only a shared
  source of truth can rule it out.
- Gating in the hook had to happen **before** `preventDefault()`. Gating after it would have
  swallowed Enter in the code editor, replacing a dead shortcut with a broken editor.
- `disabled` would have been the wrong attribute: it removes the control from the tab order,
  hiding the primary actions from keyboard and screen-reader users entirely.
- The shortcut sheet's footer text asserted behaviour that did not exist ("Run and Submit work
  while the editor has focus") — a documentation-level version of the same overclaim.

## Root Cause
Availability was never modelled. The shortcut registry recorded design intent, and the
listener treated any registered binding as executable, so intent was silently presented as
capability.

## Prevention / Rule
**Guardrail:** `scripts/verify-semantics.ts` enforces an availability contract — every
capability named by `requires` in the registry must be declared in `lib/runner.ts`;
`useShortcuts` must consult it; the check must precede `preventDefault`; action buttons must
render `aria-disabled`; key hints must be gated on availability; and the help sheet must mark
pending bindings.

This closes the gap because the failure mode is a *pairing* failure — a control that looks up
capability state in one place and renders it in another, or forgets to. There is no type that
distinguishes a `requires` field nobody reads from one that is honoured, and no lint rule that
notices a `<kbd>` printed on a dead button. Asserting the pairing (declared → consulted →
gated → rendered) is the only mechanism that catches a break at any link.

## Solution

### Immediate Fix
- `src/lib/runner.ts` *(new)* — `CAPABILITIES = { execution: false }`, `isAvailable()`,
  `unavailableReason()`, `EXECUTION_REASON`. One fact, two consumers.
- `src/lib/shortcuts.ts` — `requires?: string` on the `Shortcut` type; `run` and `submit`
  declare `requires: "execution"`. The binding stays in the design; only its firing is gated.
- `src/lib/use-shortcuts.ts` — availability checked before `preventDefault`, so Enter still
  inserts a newline in the editor.
- `src/routes/index.tsx` — Run/Submit render `aria-disabled`, dimmed, `cursor-not-allowed`, with
  `aria-describedby` pointing at a visible reason; `<kbd>` hints and `aria-keyshortcuts` omitted
  while unavailable. A visible `EXECUTION_REASON` marker sits beside the actions.
- `src/components/arch/shortcut-help.tsx` — pending bindings render dimmed, tagged "pending",
  showing the reason instead of a key cap. Footer rewritten to stop asserting they work.
- Also closed here: **PRD §5.2** ("Run never touches the score… must be stated in the UI") now
  has a visible Scoring block in the Spec pane rather than only a button tooltip.

```bash
npm run verify    # 89 assertions, then tsc --noEmit
npx eslint src/ scripts/
npx vite build
```

### Long-term Fix
- Flipping `CAPABILITIES.execution = true` is the single change that lights up the buttons, the
  hints, the bindings, and the help sheet together. Verified: both suites pass with the
  capability on *and* off, so the switch is genuinely the only lever.
- The runner itself is step 5.

## Prevention
- [x] Availability modelled as a declared capability, not inferred at each call site
- [x] Buttons and bindings read the same source
- [x] Gate placed before `preventDefault` so the editor is unharmed
- [x] `aria-disabled` (focusable) rather than `disabled` (would hide the actions)
- [x] Key hints suppressed while unavailable
- [x] Help sheet marks pending bindings; footer no longer overclaims
- [x] Availability contract added to `verify-semantics.ts`, wired into `npm run verify`
- [x] All six availability rules negative-tested
- [x] Verified green with the capability both off and on
- [ ] `npm run verify` in CI

## Related Issues
- `ARCHCODE-2026-09-26-no-keyboard-operability-in-keyboard-driven-cockpit.md` — introduced the
  live-but-inert bindings; its "Known Caveats" section is resolved by this entry.
- `ARCHCODE-2026-09-26-fabricated-verdicts-and-editable-overclaim.md` — the same dishonesty at
  the data layer.
- `reports/ARCHCODE-2026-09-26-scaffolding-removal.md` — the report that flagged this as the
  main open risk after step 4.

## References
- WAI-ARIA APG — `aria-disabled` vs `disabled` for discoverable unavailable controls
- `KeyboardEvent.preventDefault` semantics — why the gate must precede it
- `ARCHCODE-PRD.md` §5.2 — score granted by Submit; Run never touches it

---

**Resolved By:** Claude (Anthropic)
**Time to Resolution:** ~1 session
