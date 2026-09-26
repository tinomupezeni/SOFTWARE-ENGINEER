# Rebuilding the collision timeline as a derivation, and correcting its framing

**Date:** 2026-09-25
**Project:** ArchCode (`pixel-perfect-replication`)
**Environment:** Development
**Status:** Step 1 of 5 complete

## Summary

Implemented step 1 of the design review's sequencing: replaced the ArchCode cockpit's
collision timeline with one whose regions are computed from an event log rather than
hand-positioned, and corrected the underlying model of the bug it was supposed to teach. Two
token and accessibility defects were fixed alongside because they were load-bearing for the
new component. Steps 2–5 (full semantic pass, keyboard shortcuts, scaffolding removal,
missing product surface) remain.

## Context / Trigger

The design review rated the frontend **Critical issues** with six Critical findings, the
first being that the collision timeline — the product's signature element — rendered no
collision in either state. The user said "start" on step 1 of the recommended sequencing.

## Scope

**Included:**

- `src/lib/timeline.ts` — the invariant and its derivation, as a pure module
- `src/components/arch/collision-timeline.tsx` — the component
- `scripts/verify-timeline.ts` + `npm run test:timeline` — assertions over both states
- `--border-strong` and the collision-region tokens in `src/styles.css`
- Global `:focus-visible` and a `prefers-reduced-motion` guard
- The `Pill` red/amber semantic collision

**Excluded, deliberately:**

- **A test framework.** The repo has none and adding vitest to a Lovable-generated project
  is a decision for the user. The assertions run on the already-present `tsx` and exit
  non-zero, so they work in CI without a runner.
- **Steps 2–5** of the sequencing.
- **`package-lock.json`.** `npm install` was needed because bun is not installed here, and it
  created a second lockfile alongside the tracked `bun.lock`. Removed rather than committed;
  duplicate lockfiles are how dependency resolution drifts.
- **Rendered verification.** No browser was driven. The derivation is asserted, but the
  layout at various widths remains unverified in a real viewport.

## Method

The review identified the symptom (the chart is inert). Working through the fix surfaced
that the *stated model* was also wrong, which changed the design before any code was
written.

The old legend said "colliding write" versus "serialized write", implying the bug was
write/write collision. It is not. The log line is `read-then-write window 41ms on
seat_id=100`: the writes are serialized, and the defect is that two workers held version 3
across another worker's commit, so both wrote `stock=9` and 114 grants were issued for 100
seats. A write-overlap sweep — the obvious implementation of the stated framing — would
have found nothing in the real failure and reported the system as clean.

So the invariant implemented is:

> A worker's read→write span must not contain another worker's commit to the same row that
> advances the version past the one that worker observed.

Versioning the rows is what makes this decidable. It also draws the correct line in a case
that is easy to get wrong: a commit that *produced* the version a worker already holds is
not a conflict — it is the commit the worker is entitled to build on. Without version
numbers, any commit during an open read looks like a conflict, and the visualization
over-reports.

Pass/fail now falls out of the data. The pass fixture is the same structure with
`SELECT ... FOR UPDATE SKIP LOCKED` serializing each critical section to 2–4ms, and the
derivation returns zero windows for it. The old component could not have distinguished the
states even in principle, because nothing computed the difference.

## Decisions & Findings

### A bug the assertions caught before it shipped

The first run of the assertions reported a 15ms window where 41ms was expected. Root cause
was a self-inflicted defect and an instructive one: the "is this read stale" predicate and
the "which commits invalidated it" query were written as two separate filters, and the
second silently omitted the version clause. `worker-02` — which read v2 and wrote v3 — was
therefore counted as invalidating `worker-12`'s v3 read, dragging the mark from 59ms to
33ms.

Fixed structurally rather than by adding the missing clause: both call sites now go through
a single `invalidatingCommits()` helper, so the predicate cannot exist in two forms. The
generalisable lesson is that duplicated conditions drift, and the fix is to make the
duplication unrepresentable.

### Visual hierarchy fell out of the contrast fix

The bars measured 1.78–2.87:1, but at full opacity `--primary` is 8.05:1 and
`--destructive` 4.71:1. The defect was entirely the `/40` and `/60` alpha modifiers, so no
new colours were needed. Reads became *outlined* rather than filled and writes became the
only solid marks on screen. That was chosen to make the bars legible, and it has the side
benefit of putting visual weight where a reader is looking.

### One token was doing two jobs

`--border` served both decorative card edges and data-bearing tracks, and 3:1 for the second
is wrong for the first — a decorative edge is not a UI component under WCAG 1.4.11. The
original 1.30:1 was a compromise forced by that conflation. Splitting into `--border`
(quiet, raised slightly to 0.32) and `--border-strong` (0.52, clears 3:1 on every surface)
removes the compromise rather than picking a side.

### Motion was carrying information

The engine-status dot's 2s pulse is the only signal that the engine is live. The standard
`prefers-reduced-motion` treatment would have removed it and taken the information with it.
The reduced-motion path instead substitutes a static ring, so the state survives without the
motion.

## Changes Made

- **`src/lib/timeline.ts`** (new) — `Span`, `Attempt`, `StaleWindow`, `Lane` types;
  `buildLanes`, `detectStaleWindows`, `summarize`, and the shared `invalidatingCommits`
  predicate.
- **`src/components/arch/collision-timeline.tsx`** (new) — conflict rail, five worker lanes,
  legend, and a "Describe in text" disclosure. The region is a `<button>` with
  `aria-pressed`; selecting it dims non-participant lanes.
- **`scripts/verify-timeline.ts`** (new) — ten assertions across both states.
- **`package.json`** — added `test:timeline`.
- **`src/routes/index.tsx`** — removed `THREADS` and the 40-line hand-positioned timeline;
  added the `outline` pill tone and reserved red/green for the verdict; dropped the
  `hard ? "red" : "amber"` call.
- **`src/styles.css`** — `--border-strong`, `--collision-fill`, `--protected-fill`,
  `--protected-outline`; `hatch-collapse` and `hatch-protected` utilities;
  `color-scheme: dark`; global `:focus-visible`; reduced-motion block.

The conflict region is encoded with a hatch pattern, a participant count and a text label
rather than hue, so it survives greyscale, colour-vision deficiency and forced-colors mode.

## Verification

- `npx tsc --noEmit` — clean.
- `npm run test:timeline` — 10/10 assertions pass. The derived fail-state window is 41ms,
  matching the terminal's own `read-then-write window 41ms on seat_id=100` line. The chart and
  the log now agree because both are computed from the same events, which is the check that
  the model is right rather than merely self-consistent.
- `npm run build` — succeeds.
- `npx eslint` on all five touched files — clean. Repo-wide lint errors went from 208 to
  160, the difference being the deleted block; the remaining 160 are pre-existing in the
  unused shadcn components.

**Not verified:** rendered output at any viewport width, and keyboard traversal. The review's
finding 6 (layout collapse below 1024px) is still code-derived only.

## Follow-ups / Deferred

Per the sequencing, steps 2–5:

2. Complete the semantic pass; step 1 covered only the timeline's colours and the `Pill`
   collision.
3. Accessibility: the `⌘↵` / `⌘⇧↵` / `⌘1`–`⌘4` shortcuts proposed by the design review (the
   PRD specifies none) are still unimplemented. The
   focus ring makes focus visible but a keyboard user still cannot run or submit — this is
   now the largest open accessibility gap.
4. Remove scaffolding: the "Toggle Pass / Fail State" control, the editor's
   editable/read-only overclaim, `react-resizable-panels` sitting unused.
5. Product surface: scenario selector, Plan/Trace tabs, and making `schema.sql` editable so
   the two performance-related radar axes become falsifiable.

Also outstanding:

- **Shell decision (Tauri/Electron vs web)** still blocks the shortcut architecture — if it
  ships as a desktop app every toolbar item needs a menu-bar command, and there is no menu
  bar.
- **Responsive behaviour** needs a real viewport check; if the app is desktop-only, sub-1024px
  should show a deliberate message rather than the current squeeze.
- **The contrast converter should move into the repo** and run over the token set in CI. It
  was the highest-leverage step in the whole review and currently lives in `/tmp`.
- **The Invariant Matrix and Database State Diff tabs are still hand-authored tables** with
  the same latent drift risk that made the timeline inert. They should be derived from the
  same event log.

## References

- `ARCHCODE-DESIGN-REVIEW.md` — the review this implements, step 1
- `ARCHCODE-PRD.md` §9 (telemetry), §12 (accessibility)
- `ARCHCODE-pressure-test.md` §1 (capability lost if performance grading is dropped)
- `src/lib/timeline.ts`, `src/components/arch/collision-timeline.tsx`,
  `scripts/verify-timeline.ts`
- `pixel-perfect-replication/AGENTS.md` — Lovable history constraints, respected (nothing
  committed or pushed in this session)
