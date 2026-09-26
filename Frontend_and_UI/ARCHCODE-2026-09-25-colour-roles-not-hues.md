# Colour was chosen by hand at every call site, so meanings collided silently

**Date:** 2026-09-25
**Project:** ArchCode (`pixel-perfect-replication`)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary

Every coloured element in the ArchCode cockpit chose its hue with a hand-written Tailwind
class, against a `Pill` component whose `tone` prop was typed as a list of *colours*
(`"green" | "red" | "amber" | "blue" | "zinc"`). Nothing connected a colour to a meaning, so
nothing could object when two unrelated meanings landed on the same hue. Green carried four
meanings simultaneously — brand mark, engine liveness, primary action, and run verdict — and
amber carried two that were still live after the previous fix.

## Symptoms

- The ArchCode logo, the engine status dot, the "Submit Architecture" button and every
  "passed" pill were all the same green.
- "Medium" difficulty and the "Run Chaos Test" button were both amber, as was every `warn`
  log line.
- Every log line that was neither `error` nor `warn` was blue, so the injected hazard
  (`chaos`, the thing that causes the failure) was rendered identically to its own mitigation
  (`lock`, the row lock that prevents the failure).
- Both `judge` log lines were coloured by the `passed` boolean, so in a passing run the factual
  observation "100/100 seats allocated, 0 over-allocation" was painted the same green as the
  verdict "ACCEPTED".
- Metric cards showed measurements — "34ms", "0.1%", "38MB" — in verdict green.
- The 404 page's "Go home" and "Try again" buttons were green.

## Environment Details

- **Server/Host:** Local development
- **Services Affected:** Every view; the whole app shares one palette
- **Related Components:** `Pill`, `TopBar`, `__root.tsx` 404, log renderer, status banner,
  metric cards, invariant checklist, `collision-timeline.tsx`
- **Time First Observed:** 2026-09-25, during the semantics pass following the design review

## Investigation Steps

### 1. Initial Diagnosis

Enumerated every colour-bearing expression rather than reviewing views, since the defect is
cross-cutting by nature.

```bash
grep -n "text-primary\|text-destructive\|text-warning\|text-accent\|bg-primary\|tone=" src/routes/index.tsx
```

### 2. Root Cause Analysis

`Pill` accepted a colour name. The type made every collision type-correct:

```ts
tone?: "zinc" | "green" | "red" | "amber" | "blue" | "outline";
```

The prop documented *how the element should look* rather than *what it means*, so a caller
expressing "this difficulty is medium" and a caller expressing "this run failed" were
passing values from the same five-slot namespace with nothing to distinguish them.

A second, quieter instance of the same root cause sat outside `Pill`: raw
`passed ? "text-primary" : "text-destructive"` ternaries in the banner, the invariant
checklist, the matrix and the diff view.

### 3. Key Findings

- **Green: four meanings.** Brand mark (`CircuitBoard text-primary`), engine liveness
  (`pulse-dot bg-primary`), primary action (`bg-primary` + `glow-emerald`), verdict (pills,
  banner, `VERDICT_TEXT`). The brand colour being the colour of *not failing* means the most
  saturated colour in the palette marks the absence of the thing the product exists to detect.
- **Amber: two live collisions after the previous fix.** "Medium" difficulty and the "Run
  Chaos Test" action both remained amber alongside `warn` log severity. The earlier fix
  addressed the `Pill` collision but not these two call sites, because the fix was scoped to
  the component that had been noticed rather than to the meaning.
- **Blue: hazard and mitigation rendered identically.** `logTone` returned `text-accent` as
  the catch-all for every log kind, so `chaos` ("spawning 500 buyers") and `lock` ("SELECT
  ... FOR UPDATE SKIP LOCKED engaged") were the same colour. One is the cause of the failure
  and one is its prevention.
- **Facts were coloured as verdicts.** Both `judge` lines took `passed ? primary :
  destructive`. A judge *observation* is a fact; only its *conclusion* is a verdict.
- **Measurements wore the verdict colour.** "34ms", "0.1%", "38MB" are measurements, not
  passes, and were rendered in verdict green.
- **One thing checked out.** `INVARIANTS[1]` (deadlocks) is hardcoded as the survivor on a
  failed run, and `FAIL_ROWS` independently marks deadlocks as the only passing check, so the
  index correspondence is currently correct. It is correct by authoring coincidence rather
  than by construction, which is a latent risk but not a present defect.

## Root Cause

The design system specified colours and left semantics to call sites. A colour token answers
"what hue is this"; it cannot answer "what does this mean", so every call site had to supply
the mapping independently, and two call sites supplied conflicting ones. Nothing in the type
system, the build, or review could see the collision, because the collision existed in the
*choice* of values rather than in any single expression.

## Prevention / Rule

**Guardrail:** Call sites choose a *role* (`pass`, `fail`, `notice`, `info`, `neutral`,
`emphasis`), never a hue, and the role-to-hue mapping lives in exactly one table. Enforce it
with a check that fails when a verdict hue or a text opacity modifier appears outside that
table.

This closes the gap because the defect is a missing indirection rather than a wrong value: no
choice of `tone` string could have been both correct and distinct, because the namespace
itself was the problem. Naming the role moves the decision to a single reviewable place where
collisions are visible side by side, and the check makes a hand-written `className` — the
route by which the mapping was previously bypassed entirely — a build failure rather than
something a reviewer has to notice.

## Solution

### Immediate Fix

- Added `src/lib/semantics.ts` as the single role-to-hue table: `PILL_ROLES`,
  `VERDICT_SURFACE`, `VERDICT_TEXT`, `VERDICT_MARK`, `VERDICT_SURFACE_SOFT`, `logTone`,
  `ACTION_PRIMARY`, `ACTION_SECONDARY`, and `MARK_COMMIT` / `MARK_CONFLICT_*` for event marks.
- `Pill` now takes `PillRole`. The old hue-named values no longer type-check, so the
  collisions are unrepresentable rather than merely discouraged.
- **Green demoted to confirmation only.** Logo mark and engine dot → foreground/muted;
  "Submit Architecture" → filled foreground (`bg-foreground text-background`, 17.99:1); both
  `__root.tsx` action buttons → `ACTION_PRIMARY`; `glow-emerald` dropped from the primary
  action. Green now means "this passed" and nothing else.
- **Amber narrowed to notice.** "Medium" difficulty → `neutral`; "Run Chaos Test" →
  `ACTION_SECONDARY` (recessive outlined, which is also the correct hierarchy — Submit is the
  main action). Amber now means "warning" only.
- **Log severities de-confused.** Split `judge` from `verdict` in the log data so facts render
  muted and only the conclusion takes the verdict colour. `chaos`, `pool`, `lock` and `idem`
  are all muted — a hazard and its mitigation no longer share a hue, and four hues of "nothing
  is wrong" became one.
- **Measurements de-verdicted.** Runtime / Lock Contention / Memory cards are now
  `text-foreground` on `bg-card`, not verdict green.
- **Fixed the four remaining `text-muted-foreground/60` and `/70` instances** left in
  `index.tsx` by the previous pass (line-number gutter, `RO` badge, log timestamps, the
  syntax `C` constant).
- The timeline's summary line now uses `VERDICT_TEXT`; its bars use `MARK_COMMIT` and
  `MARK_CONFLICT_EDGE`, with a comment explaining that the bars are event semantics and the
  summary is the verdict.

### Long-term Fix

- Added `scripts/verify-semantics.ts` and `npm run test:semantics`, plus `npm run verify`
  chaining the timeline assertions, the colour-contract check and `tsc --noEmit`.
- The check was negative-tested: injecting a hue-named role, a verdict hue and an opacity
  modifier produced three correctly-located failures and exit code 1.
- One documented exception remains: the Python syntax-highlighting constants (`K`, `S`, `C`,
  `F`, `T`) reuse hues for grammatical roles, as every editor does, in a region with its own
  implicit legend. It is called out in a comment at the definition and enforced as an explicit
  exemption by the check, so it stays a decision rather than drifting into an oversight.

## Prevention

- [x] Single role-to-hue table in `src/lib/semantics.ts`
- [x] `Pill` accepts roles; hue names no longer compile
- [x] Green reserved for verdict; amber for notice only
- [x] Log severity separated from log category
- [x] `npm run test:semantics` enforces the contract; negative-tested
- [x] Remaining text opacity modifiers removed
- [ ] Extend the check to the 45 vendored shadcn components as they are adopted
- [ ] Give `MARK_*` a hatch or glyph channel too, so event marks do not rely on hue alone
      (the conflict band already has one; the commit bar does not)

## Related Issues

- `ARCHCODE-2026-09-25-pill-tone-colour-semantic-collisions.md` — the previous pass; fixed the
  `hard`/`soft` `Pill` collision but not the difficulty, action, brand or log collisions,
  because it was scoped to the component that had been noticed
- `ARCHCODE-2026-09-25-design-tokens-nontext-contrast-unmeasured.md` — includes a correction
  note about the opacity modifiers this entry completes

## References

- `ARCHCODE-DESIGN-REVIEW.md` — Critical 3, and the craft note on green as brand and verdict
- `src/lib/semantics.ts` — the role table
- `scripts/verify-semantics.ts` — the enforcement
- WCAG 2.2 SC 1.4.1 (Use of Color) — colour must not be the only means of conveying information
- Apple HIG, *Color* — consistent use of color for status

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~1.5 hours
