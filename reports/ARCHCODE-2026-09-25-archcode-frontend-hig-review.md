# ArchCode Frontend — HIG Design Review and Severity Findings

**Date:** 2026-09-25
**Project:** ArchCode (`pixel-perfect-replication`)
**Type:** Audit (design/accessibility review against Apple HIG)
**Status:** Completed (review written; fixes not yet applied)

## Summary

The ArchCode cockpit frontend (`src/routes/index.tsx`, 744 lines, the entire product UI)
was reviewed against 123 pages of Apple's Human Interface Guidelines via the vendored
`apple-design` skill. The review is in `ARCHCODE-DESIGN-REVIEW.md` at the project root.
Rating: **Critical issues** — six Critical findings.

The design's *text* contrast is genuinely well-tuned (every status colour clears 4.5:1 on
every surface; Submit button at 8.48:1). The failures are elsewhere: the product's signature
visual is non-functional, and the non-text half of the design system (borders, bars,
de-emphasised text) was never checked.

## Context / Trigger

The user asked to use `apple-design/` as the design guide for the ArchCode frontend,
immediately after cloning `pixel-perfect-replication` from GitHub. This followed the
ArchCode PRD and pressure test, which had specified the cockpit layout in ASCII without any
implementation existing.

## Scope

**Included:** accessibility (Lens 1), desktop platform conventions (Lens 2, macOS column),
visual design and craft (Lens 3), interaction and content/writing (Lenses 4–5), and a
measurement pass on the colour system. Ten HIG pages loaded: the always-load set
(`accessibility`, `layout`, `typography`, `color`, `designing-for-macos`) plus
`split-views`, `tab-views`, `toolbars`, `focus-and-selection`, `motion`, `dark-mode`,
`writing`.

**Excluded and why:**

- **Rendered/visual verification.** No browser was driven and no screenshots were taken. All
  findings derive from source, which is the appropriate artifact here — the code *is* the
  design. Two findings are explicitly marked as code-derivation needing a 30-second visual
  check (finding 6, narrow-window layout). Contrast figures are computed from the actual
  oklch values, so those are measured rather than estimated.
- **iOS platform conventions.** Web app; reviewed against the macOS column per the skill's
  scoping rule.
- **Fixes.** Not requested in this session. The review ends with a five-step sequencing.
- **Tauri/Electron shell design.** Flagged as a dependency for the keyboard-shortcut work
  rather than designed.

## Method

1. Read `SKILL.md` in full and `hig-lookup.md` for routing, per the skill's operating manual.
2. Inventoried the artifact: found the whole product is one 744-line route file, with ~45
   unused shadcn components and `react-resizable-panels` installed but unused.
3. Read the source and the stylesheet, then ran targeted greps to confirm the *absence* of
   things (focus styles, ARIA, reduced-motion, `color-scheme`) rather than assuming.
4. **Wrote a converter from oklch → sRGB → WCAG relative luminance and measured every
   foreground/background pair actually used in the file**, including alpha-composited
   surfaces (`bg-primary/10` over `bg-surface`) and the non-text minimums (3:1 for UI
   components per WCAG 1.4.11). This produced the most actionable output of the session and
   is the step worth repeating on any future palette change.
5. Audited through the skill's five lenses in order, then wrote the report in the skill's
   prescribed format.

## Decisions & Findings

### Critical 1 — The collision timeline renders no collision (the product's thesis fails)

`THREADS` (`index.tsx:472`) positions two absolutely-placed divs per worker with no overlap
detection, no z-order, and no connector. Measured from the coordinates: read bars overlap
across t=24–32% and write bars across t=52–56% **in both the pass and fail states**. The
only difference is fill colour (`bg-destructive/60` vs `bg-primary/50`) and bar width
(22% vs 10%). The legend promises "colliding write" vs "serialized write"; the geometry
makes no such distinction. The dirty-read window the PRD identifies as the entire lesson is
never marked.

Assessed as Critical rather than a craft note because the UI actively mislabels what it
shows, which is the "conventions broken in ways that confuse" threshold — and because the
product's stated purpose is making invisible collapse legible, which this element does not do.

### Critical 2 — Timeline bars fail both contrast and colour-independence

Measured: `bg-accent/40` read bar vs its `bg-card` track is **1.78:1**; `bg-destructive/60`
**2.38:1**; `bg-primary/50` **2.87:1**. Non-text UI requires 3:1. These bars are the *entire*
dataset in this view and the only distinguishing channel is hue.

Notably the rest of the app already double-encodes state correctly — `Check`/`X` glyphs,
"passed"/"failed" text, printed log severity, `+`/`-` sign column. The timeline is the one
miss, and it holds the most data. The failure is narrow and the fix is local.

### Critical 3 — Red means two incompatible things on one screen

`Pill tone={kind === "hard" ? "red" : "amber"}` (`index.tsx:244`) paints four red "hard"
badges including on a **passing** run; `Pill tone={ok ? "green" : "red"}` (`index.tsx:588`)
uses the same red for a **failed** verdict. Amber does triple duty: "Medium" difficulty,
"soft" invariant, and the Run button.

**Decision:** difficulty is a property of the problem, severity a property of the run —
they must not share a colour family. Difficulty becomes typography-only; red and green are
reserved for verdict.

### Critical 4 — No focus indicator, and the design system already has the token

Zero `focus-visible` / `focus:ring` / `ring-ring` in product code, while `--ring` is defined
in **both** palettes (`styles.css:94`, `:131`) and mapped at `:48`. The affordance exists
and is unused. Compounded by zero keyboard shortcuts on an app that is entirely
keyboard-driven, with `⌘↵` / `⌘⇧↵` / `⌘1`–`⌘4` proposed by this review as a way to close
that gap. (Correction: the PRD specifies no shortcuts; see the correction block below.)

**Decision:** global `:focus-visible` rule off the existing token, plus a row-fill variant
for lists per `focus-and-selection.md`.

### Critical 5 — Infinite motion, no `prefers-reduced-motion` guard, motion carrying status

`pulse-dot` (`styles.css:180`, 2s infinite opacity loop) sits beside "Engine: Ready", and
is the *only* indicator the engine is live — so motion is the sole carrier of information.
`animate-pulse` on the terminal block. No `@media (prefers-reduced-motion: reduce)` anywhere
in the project. `tw-animate-css` is already a dependency and ships the variants needed.

### Critical 6 — Layout breaks below 1024px

`grid-cols-1 lg:grid-cols-[...]` inside `h-screen overflow-hidden` (`index.tsx:735`).
Below `lg` the grid takes implicit `auto` rows, the uncapped `SpecPane` grows to content
height, and the editor/telemetry grid is squeezed and clipped. Net effect: a spec pane and
an invisible verdict. The PRD already ruled the timeline desktop-only, so the honest
sub-1024px answer is a message, not a squeeze.

### Two design defects carried over from the PRD, now confirmed in code

- **`schema.sql` is read-only** (`index.tsx:395`). This is exactly Finding 1 of the earlier
  PRD review, now confirmed in the implementation: it makes the *Performance & Query
  Optimization* and *Schema Rigor* radar axes unfalsifiable, because the learner never
  writes the index the grader credits.
- **The missing product surface.** No scenario selector (the PRD's four assault scenarios
  have no UI; `sandbox.yml` hardcodes the chaos params), and no Plan/Trace tabs. The
  latter is the capability the pressure test named as the thing lost if performance grading
  is dropped.

### The contrast measurement, in full

Passing (text): `--muted-foreground` 5.66–6.11:1, `--primary` 8.05–8.69:1, `--destructive`
4.71–5.08:1, `--warning` 9.39–10.14:1, `--accent` 4.92–5.31:1, Submit button 8.48:1.

Failing:

| Pair | Ratio | Need |
| --- | --- | --- |
| `text-muted-foreground/60` (line numbers, log timestamps) | 2.86:1 | 4.5:1 |
| `text-muted-foreground/70` (comments, `RO` badge) | 3.50:1 | 4.5:1 |
| `--border` on `--card` | 1.30:1 | 3:1 (structure) |
| timeline bars vs track | 1.78–2.87:1 | 3:1 |
| `.dark --accent` on `.dark --card` (if ever enabled) | 1.22:1 | 4.5:1 |

**The pattern: the foreground half of the system was tuned and the non-foreground half was
not.** Borders at 1.30:1 mean every pane edge, card boundary and table rule in the app sits
below the structural minimum — a single-token fix with more craft impact than anything else
in the report.

### Craft judgement

The palette is near-black `#0A0A0D` + acid green `#26C55F` + Inter/JetBrains Mono at a
uniform 8px radius — the first of the three template looks the skill names ("near-black with
one acid-green or vermilion accent"), with the default type pairing for a generated dark
dashboard.

**The stronger observation:** the brand colour is the colour of *not failing*. Green is the
identity, the primary action, and the pass state at once. For a product named after
diagnosing architectural collapse, that inverts the emphasis — and demoting green to a quiet
confirmation would make Critical 3 structurally impossible.

The real signature element is unused: `FAIL_LOGS` and `THREADS` are a genuine event log with
a pool-saturation event and a 41ms read-then-write window, currently rendered as a monospace
list. The design's own material is an instrument panel, and it is showing a terminal.

## Changes Made

No code changed. Files created:

- `ARCHCODE-DESIGN-REVIEW.md` — the review, in the skill's prescribed format (Summary,
  Critical, Improvements, Craft notes, What works, Platform notes) with severity tags and
  `file.md › Heading` citations, plus a five-step sequencing at the end.
- `reports/ARCHCODE-2026-09-25-archcode-frontend-hig-review.md` — this entry.
- `/tmp/opencode/contrast.py` — the oklch → WCAG converter, kept outside the repo. Should be
  promoted into `pixel-perfect-replication/scripts/` and wired to a palette-change check if
  the token system is going to keep being edited.

Nothing in `pixel-perfect-replication` was modified, so the Lovable-connected branch is
untouched.

## Verification

Contrast figures are computed, not estimated: an oklch → sRGB → WCAG relative-luminance
converter was written and run against every pair used in the source, including
alpha-composited surfaces. All six Critical findings are code-derivable and were confirmed
by grep for absence (`focus-visible`, `aria-`/`role=`, `prefers-reduced-motion`,
`color-scheme`, `react-resizable-panels` usage).

**Not verified:** rendered output at any viewport width, and keyboard-only traversal. Finding
6's failure mode follows from the grid definitions and is flagged in the review as needing a
30-second visual check at 900px before acting on it.

## Follow-ups / Deferred

Per the review's sequencing:

1. Build the real collision timeline from a real event log, with an overlap sweep emitting a
   single conflict band above the lanes, non-colour-coded (hatch + bracket + count).
2. Reserve red/green for verdict only; raise `--border`; drop the opacity modifiers.
3. Accessibility pass: focus ring off the existing `--ring`, reduced-motion guard, keyboard
   shortcuts, deliberate narrow-window state.
4. Remove scaffolding: the `Toggle Pass / Fail State` control, the editable/read-only
   overclaim in the editor status bar, the dead `zinc` pill tone.
5. Product surface: scenario selector, Plan/Trace tabs, pane resizing, `schema.sql`
   editable.

Open questions carried forward:

- **Shell decision (Tauri/Electron vs web) blocks the shortcut architecture.** If it ships
  as a desktop shell, every toolbar item needs a menu-bar command, and ArchCode currently
  has no menu bar at all.
- **Dark-only is defensible but must be a decision.** Delete the dead `.dark` block (its
  `--accent` is 1.22:1 if ever applied) and declare `color-scheme: dark`.
- **RTL** is unaddressed; the collision band's "which writer came first" reading inverts
  under RTL. Not a v1 blocker; do not let it become one.

## References

- `ARCHCODE-DESIGN-REVIEW.md` — the review this entry summarises
- `ARCHCODE-PRD.md` §12 (accessibility as design input), §9 (telemetry views), §5.2 (Run/Submit)
- `ARCHCODE-pressure-test.md` §1 (the capability lost if performance grading is dropped)
- `pixel-perfect-replication/src/routes/index.tsx` — the reviewed artifact
- `pixel-perfect-replication/src/styles.css` — the token system and the two dead animation
  definitions
- `apple-design/SKILL.md`, `references/hig-lookup.md`, and the ten guideline pages loaded
