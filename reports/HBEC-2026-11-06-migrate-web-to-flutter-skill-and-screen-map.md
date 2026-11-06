# Built a reusable web→Flutter migration skill + a living screen-map inventory for HBEC

**Date:** 2026-11-06
**Project:** HBEC
**Type:** Tooling / Architecture Decision (new skill + new audit script)
**Status:** Completed (skill + tooling shipped; the actual screen-by-screen
migration work it enables is ongoing — see Follow-ups)

## Summary
HBEC runs two student clients off the same backends: a React web app
(`STUDENT/Frontend`) and a Flutter rewrite (`STUDENT/mobile_flutter`)
replacing a removed Expo/RN app. The user wants the Flutter app to become a
visual/UX replica of the web app, screen by screen, and asked for a
repeatable way to guide a coding agent through that translation rather than
re-deriving the approach from scratch each time. Built a project skill
(`migrate-web-to-flutter`) encoding that translation method, and a
supporting script (`scripts/parity/screen_map.py`) that gives the skill (and
any agent) a real, navigable inventory of every web screen — including
nested routes, modals/sheets, and features that are never a route at all —
cross-referenced to its Flutter counterpart and build status. Saved globally
(`~/.claude/skills/migrate-web-to-flutter/`) and here, since the pattern
(read the source of truth deeply, verify visually, maintain a living
structural map instead of a flat gap list, close the loop on every pass) is
reusable beyond HBEC for any "make app B match app A" migration.

## Context / Trigger
User asked to compare the Flutter mobile app against the web app with the
goal of a pixel-accurate (in practice: native-idiom, UX-equivalent) mobile
replica, and specifically asked for a skill to guide a coding agent through
that translation rather than doing it ad hoc each time.

## Scope
- In scope: the skill itself, and a screen-inventory tool to back it. HBEC
  already had a shallower parity tool (`web_flutter_parity.py` +
  `parity_map.yaml`) checking top-level routes/features/colors against a
  hand-maintained decision ledger — that was reused, not replaced.
- Out of scope (deliberately, per the user's own second decision below):
  actually doing all the migration work in this pass. This report covers the
  tool; the work it enables is tracked as its own ongoing effort.
- Fidelity bar, decided with the user before building anything: visual/UX
  parity using Flutter's own native idioms, not literal DOM-to-widget
  transcription and not true pixel-diffing.
- Backlog priority, decided with the user: unbuilt feature areas before
  polishing already-matched ones, by default.

## Method
1. Surveyed both codebases' existing structure and found HBEC already had
   substantial migration infrastructure (`feature_migration_workflow.md`,
   `migration_strategy.md`, the parity script) — the gap wasn't "no process,"
   it was "no concrete technique for reading a web screen accurately and
   proving visual parity," so the new skill wraps the existing workflow
   rather than duplicating it.
2. Drafted the skill, then **dry-ran it with a fresh subagent** (steps 0–3
   only, no code changes) before trusting it for real work. The dry run
   picked a real target, read real source, and produced a real translation
   spec — and in doing so surfaced a genuine tooling bug (see Decisions &
   Findings) that a pure design review would not have caught.
3. Fixed the skill based on what the dry run actually hit, not hypothetical
   edge cases.
4. Built `screen_map.py` to close the deeper gap the dry run also exposed:
   a flat "missing features" list has no way to represent nesting (a modal
   inside an otherwise-built screen) or non-routed features (a conditionally
   rendered alternate home screen, a globally-mounted widget) — so an agent
   using only the flat list either can't see those targets at all, or has no
   way to scope a migration pass tighter than "a whole feature folder."
5. Tested the new script's output directly (not just unit-style assumptions)
   and found three real bugs via manual inspection of its generated report:
   every route nesting under `/` (an empty-path "ancestor" matched
   everything), a status-vocabulary mismatch between the script and the
   existing parity map making every route read as unassessed, and a
   JSX-prop-vs-actual-child extraction bug that misattributed the `/` route
   to a named prop's component and, as a side effect, hid an entire feature
   (`junior`) from the inventory. Fixed all three and re-verified the output.

## Decisions & Findings
- **The parity script's "features" check only sees top-level
  `lib/features/<name>/` directories.** A fully-built Settings feature
  already existed nested under `features/auth/presentation/widgets/settings/`
  (apparently from an earlier uncommitted session) and was therefore
  reported "Missing." This has its own bug-log entry:
  `Mobile_Apps/HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md`.
  The skill's step 0 now requires cross-checking the live Flutter tree
  before trusting any report-driven backlog pick, for exactly this reason.
- **`parity_map.yaml`'s decision vocabulary (matched/adapted/missing/
  web_only/flutter_only) and the natural "build status" vocabulary a
  migration pass sets (built/partial/missing/unknown) are different things
  that needed an explicit, documented translation** — conflating them
  silently would have made every route in the new tool read as unassessed
  even where a real decision already existed.
- **`screen_map.yaml` deliberately does NOT follow `parity_map.yaml`'s
  "never guess a mapping" discipline wholesale.** Fully hand-authoring an
  inventory this granular (every modal, every sheet, across two codebases)
  would mean redoing, by hand, exactly the enumeration labor the tool exists
  to remove. Instead: structure is always re-derived from live code;
  `status`/`note` per node are hand/agent-maintained and preserved across
  runs; a node the tool can't classify defaults to `unknown`, never a
  guessed verdict. This is a conscious, documented departure from the
  existing tool's philosophy, explained in both `scripts/parity/README.md`
  and the skill itself so the two files' trust models are never confused.
- **A non-routed feature (a conditionally-rendered alternate screen like
  `JuniorHome`, or a globally-mounted widget like the feedback button) is
  invisible to a pure route tree.** Added a second discovery pass
  (`attach_floating_features`) that folds in any web feature folder not
  already represented by a route, using the same status vocabulary.

## Changes Made
- `HBEC` repo, `.claude/skills/migrate-web-to-flutter/SKILL.md` — the skill
  (project-scoped).
- `HBEC` repo, `scripts/parity/screen_map.py` — new discovery/inventory
  script; `scripts/parity/screen_map.yaml` (generated+merged data) and
  `STUDENT/mobile_flutter/planning/semantic/screen_map_report.md`
  (generated tree, human/agent-readable).
- `HBEC` repo, `scripts/parity/README.md` — documented the new tool and its
  different trust model relative to `parity_map.yaml`.
- `~/.claude/skills/migrate-web-to-flutter/SKILL.md` — global copy, since
  this will be used regularly across sessions.
- `SOFTWARE-ENGINEER` repo, `Mobile_Apps/HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md`
  — the bug-log entry for the nested-feature blind spot found during the
  dry run (filed separately per this repo's one-entry-per-issue rule).
- This report, plus a full copy of the skill's current text in the
  Reference Copy section below, so another agent working from this repo
  alone (without HBEC checked out) can still read the technique, or copy it
  as a starting point for an analogous migration in another project.

## Verification
- Dry-ran the skill end-to-end (steps 0–3, no code changes) with a fresh
  subagent before trusting it; it correctly picked a real target, read real
  source, and produced a usable translation spec, while also surfacing the
  nested-feature bug above.
- Ran `screen_map.py` repeatedly during development, inspecting the
  generated markdown tree by eye after each fix (not just checking exit
  codes) — this is what caught all three bugs listed above, none of which
  would show up as a crash or a non-zero exit.
- Verified the merge behavior preserves hand/agent-set `status`/`note`
  fields across re-runs by setting a test status, re-running, and confirming
  it survived — then reverted the test data before leaving the file in its
  real, freshly-scaffolded state.

## Follow-ups / Deferred
- The actual migration work the skill/map enable (building out missing
  screens, reconciling misaligned ones) is explicitly ongoing, not part of
  this report — each migrated screen should get the skill's own close-the-
  loop treatment, not a separate report per screen.
- The uncommitted Settings feature's disposition (review/commit/discard) is
  still open — flagged to the user, not resolved here.
- The entire `scripts/parity/` directory (`web_flutter_parity.py`,
  `parity_map.yaml`, `README.md`, `screen_map.py`) was found to be
  uncommitted in the HBEC working tree — pre-existing, not introduced by
  this work, but worth the user's attention since it means this tooling
  currently only exists on one disk.
- A structural fix to `web_flutter_parity.py`'s own feature-folder scanner
  (so a nested implementation registers) is still open; the current fix is
  a behavioral guardrail in the consuming skill, not a scanner change.

## References
- `Mobile_Apps/HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md`
- `HBEC` repo: `scripts/parity/README.md`, `scripts/parity/screen_map.py`,
  `.claude/skills/migrate-web-to-flutter/SKILL.md`
- `HBEC` repo: `STUDENT/mobile_flutter/planning/procedural/feature_migration_workflow.md`,
  `research/procedural/adding_a_feature.md` (the existing workflow this
  skill wraps rather than replaces)

## Reference copy of the skill (snapshot as of this report)

This is a point-in-time copy so another agent can read and use the
technique directly from this repo, even without HBEC checked out. The live,
authoritative copies are HBEC's own `.claude/skills/migrate-web-to-flutter/SKILL.md`
and the global `~/.claude/skills/migrate-web-to-flutter/SKILL.md` — check
there for anything that's changed since 2026-11-06. The skill assumes HBEC's
specific repo layout and its own `scripts/parity/screen_map.py` /
`web_flutter_parity.py` tooling (not reproduced here — they're HBEC-specific
code, not a portable technique); adapting this skill to another project
means rebuilding the equivalent of that tooling first, not just copying the
SKILL.md text.

```markdown
---
name: migrate-web-to-flutter
description: Translate one specific screen/feature from the HBEC web app (STUDENT/Frontend, React+Vite+Tailwind+shadcn) into its Flutter counterpart (STUDENT/mobile_flutter, clean-architecture BLoC) with real visual and UX parity. Use this whenever the user asks to migrate, port, build, or add parity for a web page/feature on the Flutter mobile app, asks for a "mobile replica" of the web app, asks what to build next to close the web/Flutter gap, or references the parity report / parity map / open gaps between the two student apps. Trigger it even if they just name a web page ("do the interactive learning page on mobile") without saying "migrate" or "Flutter" explicitly — any request to bring a web screen's look or behavior onto the Flutter student app belongs here. Do not use this for the already-removed Expo/React Native app, for admin-side work, or for backend/API changes with no mobile screen attached.
---

# Migrate a web screen to Flutter

This fills in the one thing the project's existing migration docs leave thin:
*how to actually read a web page accurately and prove the Flutter result
matches it.* It wraps, not replaces, the workflow already in
`STUDENT/mobile_flutter/planning/procedural/feature_migration_workflow.md`
(BLoC-tests-first, clean-architecture build, golden test, offline check,
memory update) and `research/procedural/adding_a_feature.md` (domain → data →
presentation → DI → routes). Read both before step 4 below if you haven't
built a Flutter feature package in this repo before — this skill assumes you
will follow them, it doesn't restate them.

**Fidelity bar** (decided for this project, don't relitigate it per
invocation): visual and UX parity using Flutter's own idioms, not a literal
DOM-to-widget transcription and not true pixel-diffing. A web hover state, a
CSS grid, a WebGL canvas — none of these have a clean native equivalent, and
forcing one usually produces something that looks wrong on a phone even when
it's geometrically "accurate." The bar is: a user who knows the web app would
recognize this screen immediately, and every place it actually differs is a
decision you made on purpose, not an accident you didn't look closely enough
to catch.

## 0. Pick the target

**The screen map is the map.** Run `python3 scripts/parity/screen_map.py`
(repo root) to refresh it, then read
`STUDENT/mobile_flutter/planning/semantic/screen_map_report.md` — a single
tree of every web screen (every route, nested by URL the way a user actually
drills down through them — `/interactive` → `/interactive/:subjectId` →
`/interactive/:subjectId/lab/:labId`), every modal/sheet/drawer/overlay
reachable from one, and every feature that's never a route at all (a
conditionally-swapped-in experience like `JuniorHome`, or a globally-mounted
widget like the feedback button), each marked ✅ built / 🟡 partial /
❌ missing / 🌐 web-only-by-design / 📱 flutter-only-adaptation /
❔ needs assessment. This is what makes the backlog genuinely legible instead
of a flat list of top-level feature names — you can target a specific modal
inside an otherwise-built screen just as easily as a whole missing pillar.

If the user named a specific web page or feature, find it in the tree (or
its nearest parent) to confirm its Flutter destination and current status,
and check whether it has unbuilt/unknown children worth folding into the
same pass. If it's marked 🌐 web-only, say so and stop — that status came
from `parity_map.yaml`, a recorded product decision, not an oversight.

If no target was named, pick the shallowest ❌/❔ node in the tree whose
parent is already ✅ (so you're extending proven ground, not starting a
whole unstaged pillar in one jump), preferring a node with its own children
(more leverage per pass) over a leaf. Skip anything under a 🌐 node.

**Before committing to a node, verify it against the live Flutter tree —
don't take the map at face value.** Both this script's and the older
`web_flutter_parity.py`'s feature-folder checks are structural (do they see
a top-level `lib/features/<name>/` directory), so a feature built *nested*
inside another one (e.g. settings widgets living under `features/auth/`)
can still read as missing. This happened for real — see
`HBEC-2026-11-06-flutter-parity-script-blind-to-nested-feature.md` in the
SOFTWARE-ENGINEER dev log. Before starting work on any node: `git status`
and grep the Flutter tree for related widget/page names. If you find
existing or uncommitted work that already covers it, stop and say so instead
of duplicating it — that's a more useful result than a wrong target. A node
marked `stale: true` in `scripts/parity/screen_map.yaml` means last run
*couldn't* rediscover something previously there (renamed/removed file) —
check it before trusting its old status.

If the node sits inside a pillar that's only partially staged (a route
already exists and points at a placeholder page), read the placeholder's own
doc comments and the planning docs it points to before assuming the whole
pillar is your scope — they usually already record which slice was deferred
and which was meant to come first. Build that agreed-on first slice, not
whatever subset looks easiest from the outside.

Scope to one screen, one modal, or one tight feature slice per pass. A whole
pillar (all of `interactive-learning`, say) is several of these passes, not
one — the tree is exactly what lets you see that in advance.

`screen_map.py`'s discovery is a best-effort heuristic, not a verified fact:
it finds sub-screens by filename convention (`*Modal.tsx`, `*Sheet.tsx`, …)
and pairs Flutter counterparts by name-guessing. A node it couldn't classify
starts `unknown`, never a guessed `built` or `missing` — that's intentional,
not a gap in the tool, and step 1 is where you actually settle it.

## 1. Read the web source completely before writing any Flutter code

For the target page, read in full — not a skim:
- The page component itself, under `STUDENT/Frontend/src/{pages,features}/...`
- Its feature folder's `components/`, `hooks/`, `api/`, `data/` (transformers),
  `types/` — the page is rarely the whole story; shared components and
  transformers carry logic you'd otherwise miss
- Every API endpoint it calls and what shape it expects back
- Loading, error, and empty states — these are usually separate branches you
  have to find, not inferable from the happy path
- The exact design tokens the page actually draws on:
  `STUDENT/Frontend/src/index.css` (CSS custom properties) and
  `STUDENT/Frontend/src/shared/theme/themes.ts` (theme overrides — a page may
  render differently under the playful skin than the default one)

**Grow the map as you go.** `screen_map.py`'s filename-convention heuristic
won't catch every sub-screen — a wizard step, an inline accordion-driven
form, a confirmation flow built without a `*Modal`/`*Sheet`-suffixed
component. If this read surfaces a distinct reachable screen state that
isn't already a node under your target in `scripts/parity/screen_map.yaml`,
add it by hand (same shape as its siblings, `status: unknown` until you
assess it). This is the actual mechanism that keeps the map complete over
time — the script scaffolds what it can detect mechanically, every migration
pass fills in what it can't.

## 2. Look at it rendered — don't trust the JSX by eye

Tailwind classes and shadcn primitives don't tell you the computed layout:
responsive breakpoints override base classes, CSS vars resolve differently
per theme, and real spacing is often not what the class names suggest once
flex/grid gaps and children's own margins stack up. This is *our own app*
(not a third party), so there's no clean-room restriction — use the `run`
skill, or REA against localhost / a non-live `staging-*.hbca.tech` color in
Debug mode (see `.claude/skills/study-a-web-app/SKILL.md`'s mode table), to
capture a real screenshot at phone width (375–414px). Capture every distinct
state you found in step 1 — empty, loading, error, populated, and any
modal/sheet/expanded sub-state — not just the default view. These screenshots
are what you diff against in step 6, so keep them.

## 3. Write the translation spec before coding

Before touching `lib/`, check whether an existing Flutter page is already a
close structural analogue of your target (e.g. another subject-grid screen,
another form screen, another list-detail pair). Reusing its layout, empty
state, and supporting widgets wholesale is usually the single biggest
shortcut available — don't design a screen from scratch when a sibling
feature already solved the same shape.

Then write down (a scratch note is fine, it doesn't need to be committed) a
concrete mapping:

- **Each visual element/section → the Flutter widget you'll use for it.** See
  the cheat-sheet below for the common cases.
- **Each color/token the page uses → the matching entry in
  `STUDENT/mobile_flutter/lib/core/theme/app_colors.dart`.** Cross-check
  against the Colors table already in the parity report — it has most of the
  mapping done. If a token the web page uses has no Flutter counterpart yet
  (or vice versa), that's new ground: add it to `app_colors.dart` and flag it
  for the parity map update in step 6, don't invent an ad hoc color literal.
- **Each interaction → its native equivalent, not a literal copy.** A CSS
  `:hover` has no mobile equivalent at all — decide explicitly whether the
  affected state should show by default, on tap, or on long-press, and note
  that decision. A `Dialog` that's dismissible by clicking outside becomes a
  Flutter modal with the same dismiss behavior, not a full-screen route,
  unless the web version actually behaves like a route (check for a URL
  change).
- **Each API call → existing repository/datasource method vs. new.** Check
  `lib/features/<name>/data/datasources/` first; most endpoints this screen
  needs may already be wired for a sibling screen.
- **Does this screen mutate data?** If yes, check whether the write path is
  new or reused. A brand-new write must go through the sync queue
  (`SyncQueueService`) per the offline-first rule. A *reused* write path
  (e.g. an existing add/remove-subject flow another feature already calls)
  isn't automatically compliant just because it's existing code — confirm it
  actually routes through the sync queue before relying on it; if it
  doesn't, that's a separate gap to flag (and log per this repo's bug-log
  rule), not something this migration silently inherits.

### Tailwind/shadcn → Flutter cheat-sheet

| Web | Flutter |
|---|---|
| `Dialog` | `showDialog` |
| `Sheet` / `Drawer` | `showModalBottomSheet` |
| `Tabs` | `TabBar` + `TabBarView` |
| `Accordion` | `ExpansionTile` |
| `Toast` (sonner) | `SnackBar` |
| `Skeleton` | A shimmer/placeholder widget (check `lib/shared/widgets/` for an existing one before writing a new one) |
| `Card` | `Card`, or `Container` + `BoxDecoration` for a custom look |
| Tailwind spacing scale | **1:1 to Flutter logical pixels at baseline density** — Tailwind's unit is 4px, so `p-4` = 16px = `EdgeInsets.all(16)`. Don't re-derive spacing by eye; read the class and convert directly. This is a common, easy-to-miss error source. |

## 4. Build it

Follow `feature_migration_workflow.md` and `adding_a_feature.md` as written:
BLoC tests first, clean-architecture layers, DI registration, routes, golden
test. This skill doesn't re-specify those steps — it gates on them in step 6.

## 5. Compare, explicitly

Run the screen on an emulator/device (`run` skill) or capture its golden test
image, for every state you screenshotted in step 2. Put the web and Flutter
screenshots side by side for each state and look for: spacing, color, type
scale, element order, and any state you captured on the web but forgot to
build on Flutter. Every visible difference gets one of two outcomes — fixed,
or recorded as a deliberate decision with a one-line reason (e.g. "web shows
a hover tooltip here; Flutter shows it on long-press instead, no mobile
equivalent for hover"). Never leave a difference unaddressed because it's
"close enough" — if it's intentional, write down why; that's what makes the
fidelity bar in this project ("native idioms, not sloppiness") checkable
later by someone who wasn't in this session.

## 6. Close the loop

- Update the node(s) you built in `scripts/parity/screen_map.yaml`:
  `status: built` (or `partial` if you deliberately left something for a
  later pass) and a `note` for any intentional deviation from step 5. Any
  sub-screen you added by hand in step 1 and actually built gets the same
  treatment. Re-run `python3 scripts/parity/screen_map.py` — it re-derives
  structure and merges your status/note in, so this is quick.
- Re-run `python3 scripts/parity/web_flutter_parity.py` (repo root) — it
  still owns route/feature/color-level decisions and the brand-color
  parity check, which the screen map doesn't cover at all.
- Update `scripts/parity/parity_map.yaml` for anything that script can't
  infer on its own: a new route, a new feature folder, a new color token, or
  an intentional "Adapted"/mobile-adaptation divergence — each with the same
  one-line reason from step 5.
- Update `STUDENT/mobile_flutter/planning/phases/flutter_migration_phases.md`
  and `planning/long_term_plan.md`, and write an episode log if the track is
  now finished — per `feature_migration_workflow.md` step 6.
- Confirm (don't just assume) that the workflow's own gates actually
  happened: BLoC tests exist and pass, a golden test exists for the new
  widget, and if the screen mutates data, the offline/sync-queue path was
  actually exercised, not just wired.
```

---

**Completed By:** Claude (session work with the project owner)
**Duration:** Single session, 2026-11-06
