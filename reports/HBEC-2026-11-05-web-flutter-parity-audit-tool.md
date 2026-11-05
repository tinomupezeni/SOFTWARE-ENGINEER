# Web ↔ Flutter parity audit tool

**Date:** 2026-11-05
**Project:** HBEC (STUDENT/mobile_flutter + STUDENT/Frontend)
**Type:** Architecture Decision / Tooling Build
**Status:** Completed (v1 — structural + color-token parity; visual/screenshot
diffing explicitly deferred, see Follow-ups)

## Summary
Built a repeatable audit script that cross-checks the Flutter mobile app
against the web app's routes, feature folders, and brand color tokens, so
that "does the Flutter app match the web version" stops being something
discovered by manually reading both codebases every time it comes up. The
tool and its hand-maintained map live in the HBEC repo
(`scripts/parity/`), since they need direct, live access to both
codebases on every run; this report documents the decision and method so
the pattern is findable and reusable for other cross-platform parity work.

## Context / Trigger
Asked to make the Flutter app's Friday screen match the web version
"exactly," specifically an orange bottom-nav-bar background. Reading both
codebases to do this surfaced that the premise didn't hold: the web app has
no persistent bottom tab bar at all — Friday there is a floating launcher
button + chat sheet, and the only orange tied to it is the FAB's accent
color in one theme skin (`playful`, junior/primary grades), not a nav-bar
background. The user was asked to clarify intent before any code was
written, and confirmed the narrower, real interpretation (orange tab icon
only). Afterward, the user asked for "a better way... a tool that... ensures
we don't miss a thing when we do the translation" — this report is that
tool.

## Scope
**Included:**
- A Python script (`scripts/parity/web_flutter_parity.py`) that extracts
  live state from both codebases (React Router routes from `App.tsx`,
  `go_router` routes from `router.dart`, `features/` directory names on
  both sides, and a curated set of brand color tokens from `index.css` /
  `app_colors.dart`) and cross-checks it against a hand-maintained YAML map.
- `scripts/parity/parity_map.yaml`, seeded with the current real state of
  both apps (every route, every feature folder, 25 color tokens), each row
  carrying a `status` (`matched` / `adapted` / `missing` / `web_only` /
  `flutter_only`) and a note explaining *why* where it isn't a plain match.
- A generated report
  (`STUDENT/mobile_flutter/planning/semantic/web_flutter_parity_report.md`)
  and a `README.md` explaining how to run and maintain it.
- Fixing two stale planning docs discovered along the way (separate bug-log
  entry: `Mobile_Apps/HBEC-2026-11-05-flutter-planning-docs-stale-rn-reference.md`).

**Explicitly excluded (not overlooked — see Follow-ups):**
- Screenshot/visual pixel-diffing. This catches structural and token drift,
  not layout, spacing, or component-level visual fidelity.
- CI wiring. It's a manual/on-demand check for now.
- Full coverage of every `app_colors.dart` constant — only a curated
  brand/domain subset is held to parity; add a row when a new token matters.
- Non-default web theme skins, except `fridayOrange` (which specifically
  targets the `playful` skin, the one relevant to the triggering task).

## Method
1. Considered and rejected automatic code translation (React/Tailwind →
   Flutter/Dart) as the "better way" the user asked about — no such tool
   produces idiomatic Flutter or preserves app-specific business logic
   reliably; it would trade a known manual-audit cost for an unknown
   silent-miss cost, which is the opposite of what was asked.
2. Recognized this codebase already has an established pattern for exactly
   this problem shape — "one contract (or map), validated against every
   side that must agree with it" — used repeatedly elsewhere (question-
   diagram fixtures, MCQ inline-option contracts, `scripts/
   check_config_parity.py`'s service-contract registry). Followed that
   pattern rather than inventing a new one: a human-maintained map is the
   contract, the script is the validator, and anything in code but not in
   the map is a loud `UNMAPPED` rather than a silent gap.
3. Manually read both codebases (web `App.tsx`, `index.css`, `features/`;
   Flutter `router.dart`, `app_colors.dart`, `features/`) to hand-seed the
   map's first version with the actual current mappings and known
   adaptations/gaps, rather than letting the script's first run produce a
   wall of noise it would take a human the same manual-audit effort to
   triage — the whole point was to not repeat that effort.
4. Ran the script against the real seed, found and fixed two real bugs in
   it (route regex missed a few web-only redirect/catch-all routes not yet
   in the map; the CSS parser mis-scoped `:root`/theme-skin blocks nested
   inside `@layer base { }`, treating an outer `@layer` as the selector
   instead of walking matching braces) — fixed by hand-matching braces
   rather than loosening the regex's accuracy.
5. Treated the first clean-ish run's remaining findings (color drift) as
   real signal, not a bug to silence: the tolerance band was not loosened
   to make them disappear.

## Decisions & Findings
- **Build a map + validator, not a translator or a one-shot diff.** The map
  is durable and improves with use; a one-shot diff would need re-running
  by hand (manually) every time, and a translator would be unreliable for
  cross-framework semantics.
- **`UNMAPPED` beats silent coverage gaps.** The script never infers a
  mapping between a web item and a Flutter item by name similarity — a new
  item on either side always requires a human decision recorded in the map,
  so the map stays an honest record of intent rather than a guess.
- **Real findings on first run, fixed on the user's explicit choice:**
  several brand colors were measurably off from their own stated
  source-of-truth CSS variable — e.g. web's `--accent: 48 100% 50%`
  ("Zimbabwe Gold") computes to `#FFCC00`, not the `#FFD700`
  `app_colors.dart` actually used (also used for `--assistant`/
  `assistantBase`). Also flagged: `destructive`, `revisionBase`,
  `primaryHover`, `projectLight` — all off by a modest amount (≤15 of 255
  RGB units per channel). Asked whether to leave these, fix them, or review
  swatches first; user chose to fix them to exact web parity. Each value
  was computed by hand from the web CSS variable's true HSL (verified with
  Python's `colorsys`, not eyeballed), applied to `app_colors.dart`, and
  the two dashboard golden tests whose rendered pixels depend on
  `revisionBase` were regenerated against the corrected colors.
- **`--project-guide` is a genuine, intentional web/Flutter color
  divergence**, not drift: web deliberately uses a near-black charcoal here
  (its own CSS comment explains a red/orange sat on top of `--destructive`
  and silently read as an error state), while Flutter uses a real
  red-orange (`#DC4A38`). Recorded as `adapted` with that reasoning rather
  than flagged as an error — the map is also where "this difference is
  intentional, here's why" gets written down so it isn't re-litigated.
- Confirmed the earlier Friday-screen finding formally: `/friday` has no
  web route counterpart; recorded as `flutter_only` (a deliberate mobile
  adaptation — promoting a floating widget to its own tab), not a gap.

## Changes Made
**New files:**
- `scripts/parity/web_flutter_parity.py` (HBEC repo root)
- `scripts/parity/parity_map.yaml`
- `scripts/parity/README.md`
- `STUDENT/mobile_flutter/planning/semantic/web_flutter_parity_report.md`
  (generated output, committed so drift is visible in diffs over time)
- `STUDENT/mobile_flutter/planning/episodes/2026-11-05_web_flutter_parity_tool.md`

**Modified:**
- `STUDENT/mobile_flutter/planning/state.md` — corrected stale RN-as-
  production-client claim; added a cross-link to the new tool.
- `STUDENT/mobile_flutter/planning/procedural/feature_migration_workflow.md`
  — retargeted the "reference implementation" from the deleted RN app to
  the web app; added a parity-script step.
- `STUDENT/mobile_flutter/planning/episodes/index.md` — indexed the new
  episode entry.

**Separately, same session, also on Friday:**
- `STUDENT/mobile_flutter/lib/core/theme/app_colors.dart` — added
  `fridayOrange` (`#F37125`, ported from web's `playful`-skin `--accent`),
  then, after the first parity-audit run, corrected `primaryHover`,
  `accent`, `accentHover`, `destructive`, `revisionBase`, `assistantBase`,
  and `projectLight` to their exact web-equivalent hex values.
- `STUDENT/mobile_flutter/lib/shared/widgets/main_tab_scaffold.dart` — the
  Friday tab's icon now uses `fridayOrange` when active, instead of the
  shared green indicator every other tab uses.
- `STUDENT/mobile_flutter/test/golden_tests/goldens/{ci,linux}/
  progress_stats_panel_render.png` — regenerated against the corrected
  `revisionBase`.

## Verification
- `python3 scripts/parity/web_flutter_parity.py --section routes
  --no-report` and `--section features --no-report`: both exit 0, "no
  drift found" — confirmed the route and feature maps are fully accurate
  against current code before relying on the tool's output in this report.
- `python3 scripts/parity/web_flutter_parity.py` (all sections): first run
  exited 1 with exactly 7 findings, all in `colors`, all reviewed by hand
  above — no `UNMAPPED` or `STALE` findings remained once the map was
  corrected iteratively against two real script bugs (found and fixed per
  Method §4). After applying the computed color fixes, re-run exits **0,
  zero findings** across all three sections.
- `flutter analyze`: clean (zero errors) on every changed file.
- `flutter test`: dashboard golden tests (achievement grid, streak today,
  progress stats panel) regenerated and passing. One pre-existing failure
  (`login_page_golden_test.dart`) confirmed **unrelated** — reproduced by
  stashing all of this session's changes and re-running against the clean,
  untouched codebase, where it failed identically; not investigated further
  as out of scope for this initiative.
- Not yet done: no CI wiring, no independent human eyeballing of every row
  in the generated report against the live apps side by side — the
  report's accuracy rests on the script's extraction logic being correct,
  which was spot-checked (color math verified by hand with `colorsys` for
  several rows) but not exhaustively.

## Follow-ups / Deferred
- Screenshot/visual-diff layer (REA/Playwright for web, Flutter integration-
  test screenshots for mobile) as a second layer on top of this structural
  check, per `scripts/parity/README.md`'s own stated gap.
- Promote the script to a CI gate once the map has stabilized enough that
  `UNMAPPED` findings aren't still routine for ordinary feature work.
- Triage the `missing`-status rows in `parity_map.yaml` (reset-password,
  terms/privacy, interactive-learning pillar, settings feature, onboarding,
  junior-home copy, feedback widget, notifications full-page route, exam
  AI-papers sub-screen) into `mobile_flutter/planning/short_term_plan.md` —
  not merged in yet, left for a deliberate prioritization pass.
- A broader sweep of `mobile_flutter`'s remaining ~9 files that mention
  React Native, to confirm none besides the two already fixed make a
  present-tense claim about a directory that no longer exists.

## References
- Related bug-log entry (found during this work, logged separately):
  `Mobile_Apps/HBEC-2026-11-05-flutter-planning-docs-stale-rn-reference.md`
- Key files: `scripts/parity/web_flutter_parity.py`,
  `scripts/parity/parity_map.yaml`,
  `STUDENT/Frontend/src/App.tsx`, `STUDENT/Frontend/src/index.css`,
  `STUDENT/mobile_flutter/lib/core/navigation/router.dart`,
  `STUDENT/mobile_flutter/lib/core/theme/app_colors.dart`

---

**Completed By:** tinomupezeni (with Claude Code)
**Duration:** ~1 session (same session as the Friday-screen fix that
triggered it)
