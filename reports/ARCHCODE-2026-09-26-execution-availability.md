# Modelling execution availability instead of shipping live-but-inert actions

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Type:** Architecture Decision / Accessibility Decision
**Status:** Completed

## Summary
Step 4 removed the cockpit's fabricated *results* but left its fabricated *affordances*: Run
and Submit were styled as active primary actions, carried printed `⌘↵` / `⌘⇧↵` hints, exposed
`aria-keyshortcuts`, and held live key bindings — all wired to empty handlers. This session
introduced execution availability as a single declared capability that both surfaces read, so
the buttons, the key hints, the bindings, and the shortcut sheet cannot disagree about whether
anything can actually run. Flipping one boolean lights all of them together in step 5.

## Context / Trigger
Directly after step 4, whose report named this as the main open risk: "Run/Submit are still
bound but inert… a dead primary shortcut remains worse than none." The choice on the table was
to withhold the bindings, disable the buttons, or model availability properly. The user chose
the third.

## Scope
**Included:** `src/lib/runner.ts` (new capability module); `requires` on the `Shortcut` type;
availability gate in `useShortcuts`; `aria-disabled` + gated hints on both action buttons; a
visible unavailability reason; pending-state rendering in the shortcut sheet; a PRD §5.2
scoring block in the Spec pane; an availability contract in `scripts/verify-semantics.ts`; two
assertions in `verify-shortcuts.ts` updated to the gated form.

**Deliberately excluded:**
- **Building the runner.** Step 5. This models the absence honestly; it does not fill it.
- **Removing the Run/Submit actions or their bindings.** They are core to the design. Removing
  them would have deleted the correct intent along with the false capability, and step 5 would
  have had to re-invent both.
- **A toast or dialog on press.** A disabled control that explains itself on click is a
  pattern for controls that *might* become available; here the gap is known and permanent for
  this milestone, so a persistent inline reason is better than a transient one.

## Method
Treated it as a *consistency* problem rather than a styling problem. The two surfaces (button,
key binding) were independent, so any fix applied to one alone would have left them disagreeing
— which is precisely the class of bug the previous two steps kept finding. So the decision was
pushed down to a single fact and both surfaces made to derive from it. Every rule added to the
verifier was then negative-tested, which is how the `preventDefault` ordering rule came to
exist at all.

## Decisions & Findings

**Availability is data, not a prop.** `CAPABILITIES = { execution: false }` lives in
`lib/runner.ts` and is read by `isAvailable()`. The alternative — passing an `enabled` boolean
from the page — was rejected because it would put the knowledge in a component and let the
shortcut hook and the button drift apart again.

**The gate must precede `preventDefault()`.** This is the one non-obvious implementation
detail. The natural place to add an availability check is next to the existing
`if (!handler) return;`, which sits *after* `preventDefault()`. Gating there would have made
`⌘↵` swallow Enter in the code editor and produce nothing — trading a dead shortcut for a
broken editor, a strictly worse bug. The check goes immediately after the shortcut is matched,
with a comment saying why, and the verifier asserts the ordering by index comparison.

**`aria-disabled`, not `disabled`.** The `disabled` attribute removes a control from the tab
order, which would hide the two primary actions from keyboard and screen-reader users
completely — the opposite of the intent. `aria-disabled` keeps them focusable and
discoverable, announces the state, and lets `aria-describedby` supply the reason. This is the
APG pattern for a control that should stay discoverable while unavailable.

**Key hints are suppressed, not dimmed.** The `<kbd>` caps were the most actively harmful part
of the lie: a printed keystroke is an invitation. Dimming them would still advertise a
shortcut that does nothing, so they are omitted entirely while unavailable, along with
`aria-keyshortcuts` — announcing a key to assistive tech that does nothing is the same
invitation by another route.

**The reason is visible, not a tooltip.** Consistent with the argument made in the step 3 and
step 4 reports that a tooltip does not satisfy "stated in the UI": it is unavailable on touch,
in screenshots, and to anyone who does not hover. A truncated one-line reason sits beside the
actions, and `aria-describedby` points at it so the same text serves both audiences from one
element.

**The help sheet shows pending rather than hiding it.** Hiding Run/Submit from the sheet would
have made the sheet tidy and the product dishonest by omission — the binding is part of the
design and a reader deserves to know it is coming. They render dimmed, tagged "pending", with
the reason in place of the key cap. The sheet's footer previously asserted "Run and Submit work
while the editor has focus"; that sentence was itself an overclaim and was rewritten.

**This also closed PRD §5.2.** The requirement that "Run never touches the score… must be
stated in the UI, not just the docs" had been flagged open in two consecutive reports and was
satisfied by a button `title` — which does not really satisfy it. With the score slot now
visibly empty and Run visibly unavailable, the question "so what does Run do to my score?"
becomes pressing, so a visible Scoring block went into the Spec pane: the score is granted by
Submit, and Run only shows what your code does. The Spec pane is the right home because that
is what the block is.

**Two verifier bugs were found by negative-testing, not by reading.** The 10px-legibility rule
was written `[0-8]px`, which does not match 9px — the exact size the review had flagged. And
the first attempt at the ordering test moved the gate but left the original in place, so
`indexOf` still found the old position and the test passed against a broken file. Both were
caught only by injecting a fault and observing that the suite stayed green. A rule that has
never been observed failing is an assumption.

## Changes Made
Frontend (`pixel-perfect-replication`, **uncommitted** — Lovable-synced, no commit requested):
- `src/lib/runner.ts` *(new)* — `EXECUTION_REASON`, `CAPABILITIES`, `isAvailable`,
  `unavailableReason`
- `src/lib/shortcuts.ts` — `requires?: string`; `run`/`submit` require `execution`
- `src/lib/use-shortcuts.ts` — availability gate before `preventDefault`
- `src/routes/index.tsx` — `aria-disabled` buttons, gated hints/`aria-keyshortcuts`, visible
  reason marker, PRD §5.2 Scoring block in the Spec pane
- `src/components/arch/shortcut-help.tsx` — pending rendering; footer corrected
- `scripts/verify-semantics.ts` — availability contract (6 rules)
- `scripts/verify-shortcuts.ts` — 2 assertions updated to the gated form; "fires" reworded to
  "is declared to fire" (no longer true while pending)

This repo:
- New `Frontend_and_UI/ARCHCODE-2026-09-26-primary-actions-live-but-inert.md`
- This report

## Verification
```bash
npm run verify    # 89 assertions (timeline + semantics + shortcuts) then tsc --noEmit
npx eslint src/ scripts/
npx vite build    # built in ~2.7s, no errors
```
- `tsc --noEmit` clean; eslint clean on all touched files; build clean.
- All six availability rules negative-tested: undeclared capability, hook ignoring
  availability, gate moved after `preventDefault`, buttons forced live, key hints ungated, and
  the help sheet dropping its pending marker — each produced a `FAIL`; restored → exit 0.
- **Capability-flip test:** `CAPABILITIES.execution` set to `true` and both suites re-run. Both
  pass in either state, confirming the flag is genuinely the only lever and step 5 does not
  need to touch any surface.
- Prettier clean on all touched files.

**Not verified:** anything requiring a browser. The dimmed buttons, the inline reason, the
pending rows in the help sheet, and the new Scoring block have not been seen rendered, and the
header's density at narrow widths is unchecked — relevant because the review's finding 6
(layout below 1024px) is still open and this added a line to the header.

## Follow-ups / Deferred
1. **The runner** — step 5. Until then Run and Submit are honestly inert.
2. **Layout below 1024px** — finding 6, still open, and this change adds header content.
3. **Native menu commands** — blocked on the Tauri/Electron-vs-web decision. Once a shell
   exists, the same `isAvailable` check should gate menu items, not just web buttons.
4. **`npm run verify` in CI** so the availability contract gates merges.
5. **45 unused vendored shadcn components** — unaudited.
6. **Focus containment** in the shortcuts overlay (Tab is not cycled within the dialog).

## References
- `ARCHCODE-PRD.md` §5.2 — score granted by Submit; Run never touches it
- WAI-ARIA APG — `aria-disabled` vs `disabled` for discoverable unavailable controls
- `ARCHCODE-2026-09-26-primary-actions-live-but-inert.md` — defect entry
- `reports/ARCHCODE-2026-09-26-scaffolding-removal.md` — flagged this as the main open risk

---

**Completed By:** Claude (Anthropic)
**Duration:** ~1 session
