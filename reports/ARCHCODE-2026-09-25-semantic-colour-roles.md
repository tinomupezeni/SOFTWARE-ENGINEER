# Semantic colour pass: roles instead of hues, and a contract that can fail

**Date:** 2026-09-25
**Project:** ArchCode (`pixel-perfect-replication`)
**Environment:** Development
**Status:** Steps 1–2 of 5 complete

## Summary

Completed step 2 of the design review's sequencing by moving the cockpit from hand-chosen
hues to a single role table, then making that table enforceable. The design question was
whether to reserve a hue for findings; the answer turned out to be that the existing palette
was sufficient once green stopped doubling as the brand colour. Steps 3–5 (keyboard
shortcuts, scaffolding removal, missing product surface) remain.

## Context / Trigger

The user asked to continue after step 1 (the collision timeline) and to "finish semantics".
The design review's step 2 was scoped as "reserve red/green for verdict only; raise
`--border`; drop the opacity modifiers" — the border work and the timeline bars were already
done in step 1, so this pass was about the meanings those hues carried.

## Scope

**Included:**

- `src/lib/semantics.ts` — the single role-to-hue table
- `Pill` retyped from hue names to roles
- Green demoted from four meanings to one; amber from three to one
- Log severity separated from log category
- `__root.tsx` action buttons, metric cards, invariant checklist, status banner, diff view
- The four `text-muted-foreground/60` and `/70` instances left in `index.tsx`
- `scripts/verify-semantics.ts` + `npm run test:semantics` + `npm run verify`

**Excluded:**

- **A new hue for findings.** The review speculated that demoting green would "make Critical 3
  structurally impossible". Reserving green for the verdict achieved that without inventing a
  fifth colour, so no new hue was needed and none was added.
- **The vendored shadcn components.** 45 files under `src/components/ui` are generated and
  unadopted; the check skips them deliberately rather than flagging noise, with adopting one
  as the trigger to check it.
- **Keyboard shortcuts** (step 3) and the remaining scaffolding (steps 4–5).

## Method

Before editing, I enumerated every colour-bearing expression rather than reviewing views,
because the defect is cross-cutting:

```bash
grep -n "text-primary\|text-destructive\|text-warning\|text-accent\|bg-primary\|tone=" src/routes/index.tsx
```

That produced 42 hits and made the shape of the problem obvious: the `tone` prop was typed as
a list of *colours*, so it was structurally incapable of expressing that two call sites meant
different things by the same value.

The rule chosen was that call sites pick a **role** and the role picks a hue, with the whole
mapping in one file. The second half of the work was making that rule enforceable, because a
convention in a comment does not survive a codebase with 45 unused components in it.

## Decisions & Findings

### Green was doing four jobs, and none of them needed it

Green was the logo, the engine status dot, the Submit button, and the pass verdict. The
review's craft note had flagged that the brand colour being the colour of *not failing* inverts
the product's emphasis.

Demoting it turned out to be cheap and to improve the interface:

- The Submit button became filled foreground (`bg-foreground text-background`, 17.99:1). A
  white button on near-black is a stronger primary action than a green one, and it stops the
  main action from reading as a status.
- The logo went to foreground. Nobody identifies a product by the hue of its wordmark.
- The engine dot went to muted foreground. It means "process alive", not "passed" — and it
  still pulses, with a static ring under `prefers-reduced-motion`.
- `glow-emerald` came off the primary action, which needed no glow once it was white.

Green now means exactly one thing. No new hue was introduced, so nothing had to be measured
against an invented value.

### Amber narrowed from three meanings to one

"Medium" difficulty and "Run Chaos Test" were both amber alongside `warn` severity. Difficulty
became `neutral` metadata. The Run button became `ACTION_SECONDARY` — which is also the
correct hierarchy, since Submit is the main action and Run is secondary. That had been
masked: the amber button looked co-primary with the green one, when the green one was
`bg-primary` and the amber one was outlined. Making Run recessive fixed both the semantics and
a pre-existing hierarchy problem.

### The most consequential find was in the logs

`logTone` returned `text-accent` as the catch-all for every log kind, so all four of `chaos`,
`pool`, `lock` and `idem` rendered blue. The problem is not the hue count, it is that `chaos`
("spawning 500 buyers") and `lock` ("SELECT ... FOR UPDATE SKIP LOCKED engaged") are the
hazard and its prevention respectively. Rendering a cause and its mitigation identically
destroys the signal, and it is precisely the reading a learner needs to make.

Both are now muted. Severity is the only thing that gets a hue, which is what makes `error`
and `warn` legible as the exceptions they are.

### Facts were being coloured as verdicts

Both `judge` log lines took `passed ? primary : destructive`, so in a passing run the
observation "100/100 seats allocated, 0 over-allocation" was painted the same green as the
conclusion "ACCEPTED". Splitting `verdict` out as its own log kind in the data fixed it: facts
render muted, only the conclusion takes the verdict colour.

The same pattern appeared in the metric cards, where "34ms", "0.1%" and "38MB" — measurements,
not passes — were verdict green. Now `text-foreground` on `bg-card`.

### One suspected bug that was not

`INVARIANTS[1]` (deadlocks) is hardcoded as the survivor on a failed run, which looked like
exactly the hand-authored-state bug the timeline had. Checking `FAIL_ROWS` first showed it
independently marks deadlocks as the only passing check, so the index correspondence is
correct today.

It is correct by authoring coincidence rather than construction, so it is recorded as a
follow-up rather than changed. Worth noting as a process point: the instinct to fix it was
wrong, and twenty seconds of reading the data prevented an unnecessary edit to working code.

### A check that cannot fail is not a check

`verify-semantics.ts` was negative-tested by injecting one violation of each class — a
hue-named role, a verdict hue, an opacity modifier — confirming three correctly-located
failures and exit code 1, then restoring the file. Its first two drafts were also wrong in
instructive ways: an initial version scanned whole files and flagged all 45 vendored
components, and reported line numbers computed after stripping exempt regions; the second
attempted to exempt the timeline by region and could not, because the sanctioned hues were
scattered across the component rather than adjacent. That third failure is what pushed the
timeline's marks into named constants in `semantics.ts` — putting the exception in the
reviewable table instead of a lint allowlist, which is where it belonged.

## Changes Made

- **`src/lib/semantics.ts`** (new) — `PillRole`, `PILL_ROLES`, `VERDICT_SURFACE`,
  `VERDICT_TEXT`, `VERDICT_MARK`, `VERDICT_SURFACE_SOFT`, `logTone`, `ACTION_PRIMARY`,
  `ACTION_SECONDARY`, `MARK_COMMIT`, `MARK_CONFLICT_EDGE`, `MARK_CONFLICT_LABEL`.
- **`scripts/verify-semantics.ts`** (new) — four rules over `routes/`, `components/arch` and
  `lib/`, with two documented exemptions.
- **`src/routes/index.tsx`** — `Pill` retyped; top bar, log renderer, status banner, metric
  cards, invariant checklist, matrix, diff view routed through roles; four opacity modifiers
  removed; log data split into `judge` and `verdict`; syntax-highlighting exception documented
  at the definition.
- **`src/routes/__root.tsx`** — both action buttons routed to `ACTION_PRIMARY`.
- **`src/components/arch/collision-timeline.tsx`** — summary line uses `VERDICT_TEXT`; bars
  use `MARK_*`; lane de-emphasis moved from text opacity to track background.
- **`package.json`** — `test:semantics` and `verify` scripts.

## Verification

- `npm run verify` — 10/10 timeline assertions, 3/3 colour-contract checks, `tsc --noEmit`
  clean.
- `npx eslint` on all touched files — clean.
- `npm run build` — succeeds.
- **Contrast re-measured for every new combination**, since a semantics pass changes colours
  wholesale: Submit button 17.99:1, metric values 16.66:1, muted-on-background 6.11:1,
  muted-on-card 5.66:1, all six pill roles 4.71–16.66:1, `border-strong` outline on the
  dimmed lane track 3.59:1, `ACTION_SECONDARY` border 3.44:1. All clear their requirement.
- Negative test of the colour check: three injected violations, three located failures,
  exit 1.

**Process note:** `prettier --write src/` was run too broadly and reformatted seven Supabase
integration files and a README that this work never touched. Reverted. Repo-wide lint is back
to 159 pre-existing errors in the vendored components, down from 208 before this session
because the old timeline block was deleted. Per `AGENTS.md` those files sync to Lovable, so
unrelated churn there is not free.

**Not verified:** rendered output at any viewport width.

## Follow-ups / Deferred

Steps 3–5 of the sequencing:

3. **Keyboard shortcuts** — `⌘↵` run, `⌘⇧↵` submit, `⌘1`–`⌘4` telemetry tabs. Still the
   largest open gap: the focus ring makes focus visible but a keyboard user cannot act.
4. **Scaffolding** — the "Toggle Pass / Fail State" control, the editor's editable/read-only
   overclaim, `react-resizable-panels` sitting unused, and the dead `glow-emerald` utility if
   nothing else adopts it.
5. **Product surface** — scenario selector, Plan/Trace tabs, `schema.sql` editable.

Also:

- **Extend the colour check to the vendored shadcn components** as each is adopted.
- **`MARK_COMMIT` still relies on hue alone.** The conflict band has a hatch and a count; the
  commit bar does not. A learner who cannot distinguish the green hues loses the commit marks
  entirely, and WCAG 1.4.1 covers exactly this.
- **The invariant checklist and the matrix are consistent by coincidence.** They are separate
  hand-authored lists with an implicit index correspondence (`INVARIANTS[1]` ↔ the deadlocks
  row). Correct today; derive one from the other before adding a fifth invariant.
- **The `passed` prop still selects between whole data tables** (`PASS_ROWS`/`FAIL_ROWS`,
  `PASS_LOGS`/`FAIL_LOGS`) and between structural branches. That is acceptable — real runs do
  produce different output — but the Resilience stat at line 138 is a hardcoded `passed ? "1874"
  : "1840"` pair, which is the same hand-authored-per-state pattern the timeline had.
- **No contrast check in CI.** `verify-semantics.ts` is a grep, not a measurement; the
  oklch → WCAG converter is still only in `/tmp` and should be promoted so a token edit that
  breaks a surface fails the build.

## References

- `ARCHCODE-DESIGN-REVIEW.md` — Critical 3 and the craft note on green
- `src/lib/semantics.ts` — the role table
- `scripts/verify-semantics.ts` — the enforcement and its exemptions
- WCAG 2.2 SC 1.4.1 (Use of Color), SC 1.4.11 (Non-text Contrast)
- Apple HIG, *Color* — consistent use of color for status
- `pixel-perfect-replication/AGENTS.md` — respected; nothing committed or pushed in the
  frontend repo
