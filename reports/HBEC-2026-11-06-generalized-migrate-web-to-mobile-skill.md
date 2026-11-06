# Generalized the HBEC web-to-Flutter migration skill into a project-agnostic one

**Date:** 2026-11-06
**Project:** HBEC (origin), but the result is explicitly NOT HBEC-specific
**Type:** Tooling (new global skill)
**Status:** Completed

## Summary
The `migrate-web-to-flutter` skill built earlier today (see
`HBEC-2026-11-06-migrate-web-to-flutter-skill-and-screen-map.md`) is
hardcoded to HBEC's layout: `STUDENT/Frontend`/`STUDENT/mobile_flutter`
paths, its `scripts/parity/screen_map.py` tooling, and Flutter/BLoC
conventions. The user wants the same capability — "build a mobile app that's
a perfect mirror of the web version" — available any time, in any project,
not just HBEC. Extracted the reusable technique into a new skill,
`migrate-web-to-mobile`, saved only globally
(`~/.claude/skills/migrate-web-to-mobile/SKILL.md`), since a project-scoped
copy would only ship with whichever single repo it lived in.

## Scope
In scope: generalizing the *technique* (screen-by-screen translation
method, the native-idiom fidelity bar, the living-inventory pattern, the
"verify live code, never trust a stale tracker" discipline, the
close-the-loop habit) across any web-framework/mobile-framework pairing.
Out of scope: rebuilding `screen_map.py` as a generic multi-framework tool —
that script's route/JSX-parsing regexes are inherently React-Router/go_router
-shaped. Instead, step 0 of the new skill teaches an agent to assess whether
a given project needs scripted tooling at all (only worth it past a certain
scale) and, if so, to build an equivalent **for that project's actual stack**
rather than assuming HBEC's.

## Method
Read back through the HBEC skill and the session's actual lessons (not just
the skill's prose) to separate what was HBEC-specific from what was a
genuinely portable insight:
- **Portable**: the fidelity-bar definition itself; "a flat gap list hides
  nesting and non-routed screens"; "a structural existence-check produces
  false negatives the moment a real implementation doesn't follow the
  expected folder convention" (this bit us twice in one session — Settings
  nested under `auth/`, feedback as a shared widget not a feature folder);
  "verify against live code before trusting any tracker, including your own
  tool's output"; "look at it rendered, don't trust source by eye"; "check an
  existing structurally similar screen before designing from scratch";
  "don't assume an existing write path follows this project's offline/data
  convention just because it's existing code."
- **HBEC-specific, left out of the generic version**: exact file paths, the
  Tailwind→Flutter cheat-sheet table (replaced with an instruction to build
  the real table for whatever stack pairing is actually in play, plus a
  handful of stack-agnostic examples — modal→native-sheet, tab-strip→native-
  tabs, toast-library→native-transient-message), BLoC/clean-architecture
  specifics (replaced with "follow whatever this project's own convention
  already is").

## Decisions & Findings
- **A generated screen-map SCRIPT is deliberately not part of the generic
  skill.** Making one genuinely framework-agnostic (parsing an arbitrary
  web router + an arbitrary mobile router) is a much larger undertaking than
  the skill itself, and a wrong guess at "the" cross-framework pattern would
  be worse than an honest "build a lightweight inventory for this project,
  script it later if the scale justifies it." The generic skill names the
  SHAPE the inventory needs (nested by reachability, covers non-routed
  screens, status preserved across regenerations) without mandating an
  implementation.
- **Explicit hand-off rule between the two skills**: the generic skill's own
  description says to use `migrate-web-to-flutter` instead when working in
  HBEC specifically, so the two don't compete for triggering on the same
  request.

## Changes Made
- `~/.claude/skills/migrate-web-to-mobile/SKILL.md` — new, global skill.
- No changes to the existing HBEC-specific `migrate-web-to-flutter` skill
  (project + its own global copy) — left as the better-tuned choice for
  HBEC itself.

## Verification
Read the new skill back end to end checking that every HBEC-specific noun
(a file path, a framework name used as a default assumption, a fixed
mapping table) was either removed or turned into an instruction to
discover/derive it for the actual project at hand. Not yet dry-run against
a second real project (no second project was available in this session) —
flagged as a follow-up.

## Follow-ups / Deferred
- Dry-run `migrate-web-to-mobile` against a real second project (ideally a
  different web framework AND a different mobile framework than HBEC's
  React+Flutter pairing) to see if anything HBEC-specific slipped through
  unnoticed, the same way `migrate-web-to-flutter`'s own dry run caught a
  real tooling bug before the skill was trusted.
- If a second or third project independently needs scripted screen-map
  tooling, consider whether a genuinely generic generator (e.g. keyed off a
  small per-project config describing router shape/patterns) is worth
  building then — not speculatively now.

## References
- `HBEC-2026-11-06-migrate-web-to-flutter-skill-and-screen-map.md` (the
  origin skill this one generalizes from)
- `~/.claude/skills/migrate-web-to-flutter/SKILL.md` and
  `~/.claude/skills/migrate-web-to-mobile/SKILL.md`

## Reference copy of the skill (snapshot as of this report)

The live, authoritative copy is `~/.claude/skills/migrate-web-to-mobile/SKILL.md`
on the account this was built under — check there for anything changed since
2026-11-06. Unlike the HBEC-specific skill this generalizes from, this one
needs no project-specific tooling to be usable — it's a technique, not a
wrapper around one repo's scripts.

```markdown
---
name: migrate-web-to-mobile
description: Translate a web app's screens into a mobile app (any stack pairing — React/Vue/Angular/Svelte web with Flutter/React Native/native iOS/native Android/Kotlin Multiplatform mobile) with real visual and UX parity, using the mobile platform's own native idioms. Use this whenever the user wants a mobile app that mirrors, replicates, or achieves parity with an existing web app — "build a mobile version that matches the web app", "make this pixel-perfect on mobile", "port this web screen to Flutter/React Native/SwiftUI", "what's left to build for mobile parity" — in ANY project. Exception: if the current project is HBEC (paths like STUDENT/Frontend, STUDENT/mobile_flutter), use the more specific, pre-tuned `migrate-web-to-flutter` skill instead — this generic skill is for every other project. Not for porting between two web apps, or for a mobile app with no web counterpart to mirror.
---

# Migrate a web app to mobile (generic)

This is the project-agnostic version of a technique first built for one
specific project (HBEC, web↔Flutter). That original effort learned real
lessons the hard way — a flat "missing features" list hides nesting and
non-routed screens, a stale tracking file gets trusted over live code and
causes duplicate work, "pixel-perfect" needs a concrete definition before
anyone starts, screenshots catch what source-reading alone misses — and this
skill carries those lessons forward without assuming any specific framework,
file layout, or tooling. **Step 0 exists because this skill has no idea what
your project looks like yet; don't skip it.**

**Fidelity bar — decide this explicitly before any screen work, don't drift
into it per-screen:** the near-universal right answer is visual/UX parity
using the mobile platform's own native idioms, not literal
element-for-element transcription and not true pixel-diffing. A web hover
state, a CSS grid, a canvas-based visualization — these don't have clean
native equivalents, and forcing one usually looks wrong on a phone even when
it's geometrically "accurate." If the user hasn't stated a fidelity bar,
state this default back to them in one line before starting, so it's a
decision made once, not re-litigated screen by screen. The bar in practice:
a user who knows the web app recognizes the screen immediately, and every
place it actually differs is a decision made on purpose, not an accident
nobody looked closely enough to catch.

## 0. Discover the actual project — don't assume anything

Before picking a target or reading a single line of application code,
establish:

- **Where the web app and the mobile app each live** (often two directories
  in a monorepo, or two separate repos — ask if it's not obvious).
- **The web stack**: framework (React/Vue/Angular/Svelte/plain), router
  (React Router/Vue Router/file-based), styling system (Tailwind/CSS
  modules/styled-components/plain CSS), component library if any
  (shadcn/MUI/Chakra/Ant). Read `package.json` and skim a couple of real
  pages — don't guess from the framework name alone, since styling/component
  conventions vary a lot project to project.
- **The mobile stack**: Flutter (`pubspec.yaml`), React Native
  (`package.json` with `react-native`), native iOS (`.xcodeproj`/SwiftUI vs
  UIKit), native Android (Kotlin/Compose vs XML views), or Kotlin
  Multiplatform. Read whatever that stack's own convention docs are (a
  CLAUDE.md, README, or just the existing code's own patterns) for its
  architecture (MVVM/clean-architecture/MVI/whatever this project already
  uses), state management, navigation, and testing conventions. **Follow
  what's already there — this skill does not impose an architecture.**
- **Whether this project already has some form of web↔mobile tracking.**
  Grep for anything parity/migration-shaped (a script, a markdown doc, an
  issue-tracker label) before assuming there's none. If one exists, read and
  use it — don't build a second, competing one.

### If no tracking exists yet, build a minimal one — this is usually the actual first task

A flat "here's what's missing" list is not enough once a project has more
than a handful of screens, for three reasons learned the hard way on the
original project this skill generalizes from:
1. **Nesting is invisible in a flat list.** A screen reachable only by
   drilling into another one (a detail page, a step in a flow) needs to be
   seen as a child of its parent, not a sibling in a flat backlog — otherwise
   an agent either can't find it as a target at all, or can't scope a pass
   tighter than "the whole feature."
2. **Non-routed screens are invisible to a route-only check.** A modal, a
   sheet, a confirmation dialog, a feature that's conditionally swapped in
   rather than its own route, a globally-mounted floating widget — none of
   these show up if you only enumerate the router's route table.
3. **A structural check (does this folder/file exist?) produces false
   negatives the moment an implementation doesn't follow the expected
   layout.** A feature built nested inside another feature, or under a
   shared/common location instead of its own folder, reads as "missing" to
   a naive folder-name check even when it's fully built — this happened for
   real and nearly caused duplicate work twice in the same session.

The fix isn't a specific script — it's a **living inventory** with this
shape, however you implement it for this project (a generated+merged
YAML/JSON file is one good option, matching the pattern from the original
project: structure re-derived from live code every time, `status`/`note`
fields hand/agent-maintained and preserved across regenerations):

- One entry per reachable screen state: every route, nested by how a user
  actually drills into it (not a flat list), every modal/sheet/dialog
  reachable from a screen, and every feature that's never its own route.
- Each entry: the web source location, the mobile destination (if any), a
  status (built / partial / missing / platform-only-by-design /
  mobile-only-adaptation / unknown), and a one-line reason for anything
  non-obvious.
- An entry defaults to `unknown`, never a guessed verdict — a thing this
  skill's discovery heuristics can't classify should say so, not pretend.
- Grows over time: when later reading a page's source (step 1) surfaces a
  sub-screen the inventory doesn't have yet (a wizard step, a non-obviously-
  named modal), add it by hand. The inventory is built once and refined on
  every subsequent pass, not a one-time artifact.

If building a small generator script is clearly worth it for this project's
scale (many routes, a framework with an easily-parsed route table), do that
— but don't over-invest in tooling before the first real screen gets built;
a hand-maintained markdown/YAML file is a perfectly good v1 for a smaller
app, and can be scripted later once the manual version proves its shape.

## 1. Pick the target

Prefer the inventory from step 0 over asking the user what to build, once it
exists. Pick the shallowest missing/unknown node whose parent is already
built (extends proven ground rather than starting a whole unstaged area in
one jump); prefer a node with children of its own (more leverage per pass)
over an isolated leaf. Skip anything marked platform-only-by-design.

**Before committing to any target, verify it against the LIVE codebase —
never trust a tracking file, a planning doc, or even this skill's own
inventory at face value.** The exact failure mode to guard against: a
feature already fully built but in a non-obvious location (nested inside
another feature, under a shared/common folder) reads as missing to any
structural check. `git status` and grep the mobile codebase for related
file/class/component names before concluding something doesn't exist yet —
building a duplicate is a worse outcome than a slower start.

If the target sits inside an area that's only partially staged (a nav entry
or route already exists pointing at a placeholder), read that placeholder's
own comments and whatever planning docs it references before assuming the
whole area is in scope — they usually already record which slice was
deliberately deferred and which was meant to come first.

Scope to one screen, one modal, or one tight slice per pass. A whole feature
area is several passes, not one — the inventory is what makes that visible
in advance instead of discovered partway through an overrun pass.

## 2. Read the web source completely before writing any mobile code

Read in full, not a skim:
- The page/screen component itself and everything it visibly composes.
- Supporting code the page depends on but doesn't contain inline: shared
  components, hooks/composables, API calls and the shapes they expect back,
  state-management logic.
- Loading, error, and empty states — usually separate code paths, not
  inferable from the happy path alone.
- The actual design tokens the page draws on (a theme file, CSS custom
  properties, a design-system config) — read the real values, don't
  estimate from component/class names.

**Grow the inventory as you go** (see step 0): a sub-screen this read
surfaces that isn't already tracked gets added, `status: unknown`, before
you move on.

## 3. Look at it rendered — don't trust markup/source by eye

A component tree or a set of utility classes doesn't reliably tell you the
real computed layout: responsive breakpoints override base styles,
design-token values resolve differently per theme, and real spacing is
rarely what class names alone suggest once nested margins/gaps stack up.
Get an actual screenshot of the real rendered page at a representative
mobile viewport width (whatever rendering/browser tooling is available in
this environment — a dev server plus a browser-automation tool, or the
project's own existing screenshot tooling if it has any) for every distinct
state found in step 2: empty, loading, error, populated, and any
modal/expanded sub-state. These are what you diff against in step 5 — keep
them.

If this is the project's OWN web app (not a third party), there is no
clean-room restriction on reading its source or capturing it directly.

## 4. Write the translation spec before coding

Before writing mobile code, check whether an existing screen in the mobile
codebase is already a close structural analogue of the target (another
list/detail pair, another form, another card grid). Reusing its layout,
empty-state handling, and supporting pieces is usually the single biggest
shortcut available — don't design from scratch when a sibling screen already
solved the same shape.

Then write down a concrete mapping (a scratch note is fine):

- **Each visual element/section → the mobile widget/view you'll use for
  it.** Build the actual web-pattern → mobile-pattern table for THIS stack
  pairing — don't assume a Flutter-shaped answer for a React Native or
  SwiftUI target. A few universal shapes to translate regardless of stack:
  a web modal/dialog → the platform's native modal/sheet presentation; a web
  tab strip → the platform's native tab component; a toast/snackbar library
  → the platform's own transient-message mechanism; a skeleton loader → the
  platform's own shimmer/placeholder pattern (check for one already in the
  codebase before writing a new one).
- **Each design token → its mobile equivalent**, resolved from the actual
  values read in step 2, not re-estimated. If a token exists on one side but
  not the other, that's new ground to create deliberately, not to
  approximate with an ad hoc value.
- **Each interaction → its native equivalent, not a literal copy.** A CSS
  `:hover` has no touch equivalent at all — decide explicitly whether the
  affected state should be visible by default, revealed on tap, or on
  long-press, and record that decision. A dismiss-on-backdrop-click web
  modal becomes a platform modal/sheet with the same dismiss behavior, not
  automatically a full navigation push, unless the web version is actually
  URL-driven (check for a route change, don't assume from appearance alone).
- **Each API call → an existing data layer method vs. a new one.** Check
  whatever this mobile codebase's established pattern is for API/data
  access before adding a new one — most endpoints a screen needs may already
  be wired for a sibling screen.
- **Does this screen mutate data?** If so, find out — don't assume — how
  this specific mobile codebase handles writes: synchronous, optimistic,
  queued for offline sync, or something else. Follow whatever the
  established pattern actually is. If you're reusing an existing write path
  from another screen, confirm it already follows that pattern rather than
  assuming it does just because it's existing code — a write path that
  silently bypasses an established offline/sync convention is a real,
  separate defect worth surfacing on its own, not something to inherit
  quietly into a new screen.
- A numeric spacing/sizing scale (Tailwind's 4px unit, a web design system's
  own scale) usually maps directly to the mobile platform's logical
  units/points at baseline density — read the actual value and convert
  directly rather than re-deriving spacing by eye, which is an easy,
  common source of subtle drift.

## 5. Build it

Follow this mobile codebase's own existing conventions exactly — its
architecture pattern, its test-writing order (some projects write
tests-first), its dependency-injection/state-management approach, its
navigation/routing setup. This skill does not specify these; the project
you're in already has (or is establishing) its own, and consistency with
sibling screens matters more than any generic best practice.

## 6. Compare, explicitly

Get the mobile screen actually rendered (an emulator/simulator, a device, or
a snapshot/golden-test mechanism if the project has one) for every state
screenshotted in step 3. Put the web and mobile renders side by side and
check: spacing, color, type scale, element order, and any state captured on
web but missing on mobile. Every visible difference gets one of two
outcomes — fixed, or recorded as a deliberate decision with a one-line
reason. Never leave a difference unaddressed because it's "close enough" —
an unrecorded difference is indistinguishable from an accident to the next
person (or agent) who looks.

## 7. Close the loop

- Update the inventory from step 0: the node(s) just built get a real
  status and any deviation notes from step 6. Any sub-screen added by hand
  during step 2 that actually got built gets the same treatment.
- Follow whatever this project's own convention is for recording completed
  work (a changelog, a planning doc, an episode log) — don't invent a new
  one if one already exists.
- Confirm — don't just assume — that this project's own quality gates
  actually ran: tests exist and pass for the new screen, and if it mutates
  data, the offline/sync behavior (whatever this project's actual
  convention turned out to be in step 4) was genuinely exercised.
```

---

**Completed By:** Claude (session work with the project owner)
**Duration:** Single session, 2026-11-06
