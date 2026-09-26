# Keyboard-driven cockpit had zero keyboard operability

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The ArchCode cockpit presents itself as a keyboard-driven engineering tool — dense panes,
tabbed telemetry, a code editor — but shipped with no keyboard affordances at all: no
`⌘↵` to run, no tab-switching shortcuts, no shortcuts sheet, and tab bars that were plain
`<button>` elements with no ARIA tab semantics or arrow-key navigation. The entire interface
was mouse-and-tab-order operable only. A keyboard-only user could not switch telemetry views
efficiently, could not discover that Run/Submit were the primary actions, and screen-reader
users got no tab/tabpanel relationship to navigate.

## Symptoms
- Tab bars rendered as visual buttons with no `role="tablist"` / `role="tab"` /
  `role="tabpanel"`, so assistive tech announced them as unrelated buttons.
- No arrow-key, Home, or End navigation within a tab group — the WAI-ARIA tabs pattern.
- No global shortcuts; the only "shortcuts" a user could find were the ones the browser and
  OS provided, none of which mapped to cockpit actions.
- Run and Submit were unlabelled as to keyboard operability, and nothing in the UI surfaced
  their existence beyond visual text on the buttons.
- No discoverable list of available shortcuts anywhere.

## Environment Details
- **Server/Host:** local dev (`npm run dev`, Vite)
- **Services Affected:** cockpit shell — `src/routes/index.tsx`, `src/routes/__root.tsx`
- **Related Components:** `SpecPane`, `TelemetryPane`, `TopBar`
- **Time First Observed:** 2026-09-25, during the frontend HIG design review

## Investigation Steps

### 1. Initial Diagnosis
Read the cockpit route and confirmed the tab bars were plain buttons and that no
`keydown` listener, `onKeyDown` handler, or `aria-keyshortcuts` attribute existed anywhere in
`src/`.

```bash
grep -rn "onKeyDown\|keydown\|aria-keyshortcuts\|role=\"tab" src/
# (no matches)
```

### 2. Root Cause Analysis
The cockpit was built as a visual mock first, with interaction modelled as "click this
button". Nothing in the build treated keyboard operability as a requirement, so no
keyboard layer was ever written. The deeper cause is that the original review *believed the
PRD mandated the bindings* — that false premise is what made the gap look like a spec
failure rather than a missing design decision, and it is corrected separately (see Related).

```bash
grep -n "shortcut\|keyboard" ARCHCODE-PRD.md
# no shortcut specification exists in the PRD at all
```

### 3. Key Findings
- The PRD specifies **no** keyboard shortcuts. The bindings are a design proposal, not spec
  compliance.
- The prior review entry, the timeline report, and the focus/motion defect entry all repeated
  the false claim that the PRD specified `⌘↵` / `⌘⇧↵` / `⌘1`–`⌘4`. All three corrected here
  and in those files.
- A naive `e.key === "1"` style matcher would break on non-US layouts: on a German layout
  `⇧2` produces `key: "@"`, and matching on the character rather than the physical digit
  means the binding silently does not fire.
- Global pane-switching shortcuts that do not guard editable regions would swallow typing in
  the code editor.

## Root Cause
Keyboard operability was never treated as a build requirement, and the review that should
have caught it was anchored to a PRD requirement that did not exist. The result was a
cockpit that is visually a professional keyboard tool but is operationally mouse-only.

## Prevention / Rule
**Guardrail:** every global key binding must be declared once in a single registry
(`src/lib/shortcuts.ts`) and validated by `scripts/verify-shortcuts.ts`, which asserts (a) no
two bindings claim the same combo, (b) every declared combo resolves back to its own
shortcut, (c) the `KeyboardEvent` fields a real browser sends actually match, and (d) every
tab in a tab group has a binding.

This closes the gap because the failure mode is a binding that exists, looks correct in a
help sheet, and never fires — which no typecheck or lint rule can detect, and which is exactly
what the layout-dependent digit matching and the editable-region guards would have shipped
silently. The same script also counts tabs directly from the component source, so adding a
fifth telemetry tab without a `⌘5` binding fails the suite.

## Solution

### Immediate Fix
- `src/lib/shortcuts.ts` — single source of truth: binding registry, `comboOf()` matcher,
  `isEditableTarget()`, platform display formatting, `ariaKeyShortcuts()`.
- `src/lib/use-shortcuts.ts` — one `keydown` listener; per-binding `allowInEditable` guard;
  `duplicateCombos()`.
- `src/components/arch/shortcut-help.tsx` — `?` overlay listing all bindings, Escape to
  close, focus moved in on open and restored to the trigger on close.
- `src/routes/index.tsx` — tab state lifted from `SpecPane`/`TelemetryPane` up to the page so
  the shortcut layer drives the same state the bars do; `TabBar` rewritten to the ARIA tabs
  pattern with roving `tabIndex` and Arrow/Home/End; `TabPanel` added with matching
  `aria-labelledby`; Run/Submit given `aria-keyshortcuts` + `title` + visible `<kbd>` hints;
  help trigger button added.
- `scripts/verify-shortcuts.ts` — 40+ assertions; wired as `npm run test:shortcuts` and into
  `npm run verify`.

```bash
npm run verify      # 86 assertions across timeline + semantics + shortcuts, then tsc
npx eslint src/ scripts/
npx vite build
```

### Long-term Fix
- The bindings are a **proposal** and still need design sign-off before they are treated as
  spec. The PRD should either adopt them or explicitly say shortcuts are out of scope, so
  this class of ambiguity does not recur.
- Native menu-bar command registration (so the shortcuts are discoverable in the OS menu)
  is still blocked on the Tauri/Electron-vs-web decision.
- `scripts/verify-shortcuts.ts` should move into CI; it is currently only wired into
  `npm run verify`.

## Prevention
- [x] Single binding registry; no ad-hoc `keydown` handlers
- [x] Layout-robust digit matching via `event.code`
- [x] Editable-region guard on every global binding
- [x] `aria-keyshortcuts` on the action buttons
- [x] Discoverable shortcuts overlay
- [x] Negative-tested the matcher (a duplicate combo was injected and correctly failed)
- [ ] Design sign-off on the proposed bindings
- [ ] `npm run verify` in CI
- [ ] PRD amended to state shortcut policy

## Known Caveats
- **`Run` and `Submit` are bound but inert.** No execution engine exists yet, so `⌘↵` and
  `⌘⇧↵` fire and do nothing visible. This is the same scaffolding debt as the "Toggle Pass/Fail
  State" button, and it is called out in the report as a UX regression risk if shipped as-is:
  a dead primary shortcut is worse than no shortcut. The keyboard *plumbing* is verified; the
  action behind it is step 4 of the review sequence.
- PRD §5.2 requires "Run never touches the score" to be stated in the UI. It currently appears
  in the Run button's `title` and the shortcuts overlay, which is technically UI but not
  persistently visible. **Still open.**
- No browser-driven verification was possible. Focus order, the overlay's focus containment
  (it traps initial focus and restores on close, but does not yet cycle Tab within the
  dialog), and the sub-1024px layout are unverified visually.

## Related Issues
- `ARCHCODE-2026-09-25-no-focus-ring-and-unthrottled-motion.md` — the same review's other
  accessibility finding; its PRD-citation is corrected in this entry's commit.
- `reports/ARCHCODE-2026-09-25-keyboard-shortcut-system.md` — implementation report.
- `reports/ARCHCODE-2026-09-25-archcode-frontend-hig-review.md` — origin of the finding.

## References
- WAI-ARIA Authoring Practices — Tabs pattern (roving tabindex, Arrow/Home/End)
- WCAG 2.1 SC 2.1.1 Keyboard, SC 1.3.1 Info and Relationships
- `KeyboardEvent.code` for layout-independent key identification

---

**Resolved By:** Claude (Anthropic)
**Time to Resolution:** ~1 session (defect entry covers the same day's implementation)
