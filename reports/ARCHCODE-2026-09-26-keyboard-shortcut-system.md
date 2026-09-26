# Keyboard shortcut system for the ArchCode cockpit

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Type:** Feature / Accessibility Decision
**Status:** In Progress (plumbing complete and verified; Run/Submit actions pending the runner)

## Summary
Built the cockpit's entire keyboard layer as step 3 of the HIG review sequence: a single
declarative binding registry, one global key listener with per-binding editable-region
guards, a discoverable shortcuts overlay, `aria-keyshortcuts` on the primary actions, and a
rewrite of both tab bars to the WAI-ARIA tabs pattern. The design work that mattered was not
the key handling itself but three decisions: the bindings are a *proposal* rather than PRD
compliance, digit keys must be matched on `event.code` to survive non-US layouts, and pane
shortcuts must yield to the code editor. All 86 assertions across the three verification
suites pass, and the matcher was negative-tested.

## Context / Trigger
Step 3 of `ARCHCODE-DESIGN-REVIEW.md`: "the product claims keyboard-driven operation and
delivers none of it." The review had flagged zero keyboard affordances as a critical finding,
so this session implemented it.

Two corrections to the review's own premise came out of the work and are logged here because
they change how the finding should be read:

1. **The PRD specifies no keyboard shortcuts.** The review claimed it did. The only match for
   "one-command" anywhere in the PRD is §11.3's badge-artifact promise, not a key binding.
   The bindings are therefore a design decision this work *invented*, and they need sign-off.
2. The §11.3 citation was initially mis-transcribed as §5.4 in the review's own correction
   block, which is a different section (Diagnostics). Fixed.

## Scope
**Included:** global binding registry and matcher; editable-region guarding; shortcuts
overlay with focus save/restore; `aria-keyshortcuts`; ARIA tabs + tabpanels for both tabbed
panes with Arrow/Home/End; state lifting so shortcuts and tab bars share one source of truth;
a verification suite; propagation of the PRD-citation correction to all three previously
pushed documents that repeated it.

**Deliberately excluded:**
- **Native menu-bar command registration.** Blocked on the Tauri/Electron-vs-web shell
  decision. Web `keydown` is the only layer available today, so the shortcuts are not
  discoverable from the OS menu yet.
- **Any real Run/Submit behaviour.** That is the execution engine (review step 4). This work
  bound the keys and verified they fire; it did not build a runner. See Follow-ups.
- **Visible, persistent "Run never touches the score" copy.** Required by PRD §5.2. It exists
  in the Run button `title` and the overlay, which does not satisfy "stated in the UI" in
  spirit. Flagged rather than half-solved.
- **Focus cycling inside the shortcuts overlay.** Initial focus is moved into the dialog and
  restored to the trigger on close, but Tab is not yet contained to the dialog.

## Method
Rather than writing `onKeyDown` handlers per component, the bindings were inverted into a
declarative registry so that one listener and one validator could cover the whole app. The
reusable idea: **a shortcut system should be a data structure plus a validator, not a set of
event handlers** — because then "does every tab have a shortcut" and "do two shortcuts
collide" become assertions instead of code review.

The validator counts tabs by reading `src/routes/index.tsx` directly rather than duplicating
the list, specifically so that the common future mistake — adding a fifth telemetry tab and
forgetting the binding — fails the suite instead of producing a tab no keyboard user can
reach.

## Decisions & Findings

**Bindings are a proposal, not a requirement.** No source of truth specifies them, so they
are marked as a design decision in code comments, in the defect entry, and here. If the
project later adopts different bindings, this work is not "violating" the spec — and the
correction means the review's Critical finding is re-readable as "a gap worth closing" rather
than "a spec failure."

**Digit bindings must match on `event.code`.** A `⌘2` binding written as `e.key === "2"`
silently does not fire on a German or French layout, where `⇧2` yields `"@"` / `"é"`. The
matcher uses `code` (`Digit2`) so the *physical* key is identified regardless of layout or
modifier state. This is the single most likely way a shortcut system ships broken and shows
no error — there is no type, lint, or test failure, the key just does nothing. A dedicated
assertion covers exactly this case.

**Global bindings need an editable-region guard, and it should be per-binding.** A blanket
"ignore all shortcuts when focus is in an input" rule is wrong in both directions: it would
block `⌘↵` from the code editor (where running the current scenario is *most* useful), and it
would leave pane-switching free to hijack typing. So `allowInEditable` is a property of each
binding: Run and Submit set it, pane switches do not.

**Tab state had to be lifted, and that was a smell in the original code.** Each pane owned
its own `useState` for the active tab, which made the tab bar unreachable from a global
shortcut layer without prop-drilling a setter into every pane. Lifting both to the page and
passing `tab`/`onTab` down makes the shortcut layer and the bar read the same state, so they
cannot drift.

**`noUncheckedIndexedAccess` caught two real holes.** `tabs[next]` and `shortcut.keys[0]` are
`string | undefined` under the repo's tsconfig. Both are now guarded rather than asserted
away.

**One lint warning was a genuine bug, not noise.** `react-hooks/exhaustive-deps` flagged
reading `returnFocusTo.current` inside an effect *cleanup*. The ref is captured when the
overlay opens instead, so focus returns to the element that was actually focused at open
time — not to whatever the ref points at when the dialog happens to close.

**The verifier was negative-tested.** A duplicate combo was injected into the registry; the
suite reported it and exited 1. A check that cannot fail is not a check.

## Changes Made
Frontend (`pixel-perfect-replication`, **uncommitted** — the repo syncs to Lovable and no
commit was requested):
- `src/lib/shortcuts.ts` *(new)* — registry, `comboOf`, `isEditableTarget`, `formatCombo`,
  `formatShortcut`, `ariaKeyShortcuts`
- `src/lib/use-shortcuts.ts` *(new)* — global listener, editable guard, `duplicateCombos`
- `src/components/arch/shortcut-help.tsx` *(new)* — `?` overlay, Escape close, focus restore
- `src/routes/index.tsx` — `TabBar` → ARIA tabs; `TabPanel` added; `specTab`/`telemetryTab`
  lifted to `ArchCode`; `useShortcuts` + `ShortcutHelp` wired; `Keyboard` icon imported;
  Run/Submit given `aria-keyshortcuts`, `title`, and `<kbd>` hints; help trigger added
- `scripts/verify-shortcuts.ts` *(new)* — 40+ assertions
- `package.json` — `test:shortcuts`; `verify` extended to run all three suites

This repo:
- New defect entry `Frontend_and_UI/ARCHCODE-2026-09-26-no-keyboard-operability-in-keyboard-driven-cockpit.md`
- This report
- Corrections propagated to three already-pushed documents that repeated the false
  "the PRD specifies `⌘↵`…" claim: the HIG review report, the timeline rebuild report, and
  the focus/motion defect entry

## Verification
```bash
npm run verify        # 86 assertions (timeline + semantics + shortcuts) then tsc --noEmit
npx eslint src/ scripts/   # 0 problems in all touched files
npx vite build         # built in ~3s, no errors
```
- `tsc --noEmit` clean. (Repo-wide `npm run lint` still reports ~160 pre-existing errors in
  untouched vendored shadcn components; not in scope.)
- Shortcut suite negative-tested: injected duplicate combo → reported, exit 1; restored → exit 0.
- Negative assertions confirm plain `Enter`, `⌘A`, `⌘5`, and `⇧⌘5` match nothing.
- Cross-file assertions confirm the tab counts in `index.tsx` match the binding counts, and
  that `tab`/`tabpanel` roles, roving tabindex, and the `aria-controls`/`aria-labelledby`
  pair are all present.

**Not verified:** anything requiring a browser. Focus order, overlay focus containment,
real key events reaching the listener, and the sub-1024px layout are all unconfirmed.

## Follow-ups / Deferred
1. **Run/Submit are bound but inert** — pressing `⌘↵` does nothing visible. A dead primary
   shortcut is worse than none, so this must land together with the runner (step 4) or the
   bindings should be withheld. This is the main open risk in the current state.
2. **PRD §5.2 copy** — "Run never touches the score" needs a persistent visible treatment,
   not a tooltip.
3. **Focus containment** in the shortcuts overlay (cycle Tab within the dialog).
4. **Design sign-off** on the proposed bindings; then amend the PRD so shortcut policy is
   explicit either way.
5. **Native menu commands** once the shell is chosen.
6. **`npm run verify` in CI**, so the binding/tab-count assertions actually gate merges.
7. **Delete the dead `.dark` block** at `src/styles.css:122` — a previously pushed entry
   wrongly claimed this was already done; corrected in this commit.

## References
- WAI-ARIA Authoring Practices — Tabs pattern
- `KeyboardEvent.code` — layout-independent physical key identification
- `ARCHCODE-DESIGN-REVIEW.md` — step 3 and the corrected finding
- `ARCHCODE-2026-09-26-no-keyboard-operability-in-keyboard-driven-cockpit.md` — defect entry
- `reports/ARCHCODE-2026-09-25-archcode-frontend-hig-review.md` — origin, PRD citation corrected

---

**Completed By:** Claude (Anthropic)
**Duration:** ~1 session
