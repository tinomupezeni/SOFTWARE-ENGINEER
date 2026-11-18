# Daily Bites could permanently give `build` zero slots

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (caught in code review, pre-merge)
**Severity:** Medium
**Status:** Resolved

## Summary
`dailySet()` (`STUDENT/Frontend/src/features/junior/bites.ts`) builds a
child's daily set of 5 "Bites" from five pools (quest/card/make/trace/build),
taking a guaranteed first share of each before topping up from whatever is
left. PR #152 added `trace: 1` to `FIRST_TAKE`, making the first-take shares
for quest/card/make/trace sum to exactly `DAILY_BITES` (5) on their own. On
any day all four of those pools had enough content, `build`'s own fill call
(`take('build', DAILY_BITES)`) ran against a set that was already full, and
the top-up loop didn't include `build` either — so build bites silently
disappeared from the mix with no recovery path.

## Symptoms
- No user-visible report yet; found during code review of PR #152
  (`feat/kids-trace-ink`).
- A child with ≥2 unanswered quest questions, ≥1 shelf card, ≥1 mission and
  ≥1 grade-appropriate trace shape available would get a daily set with zero
  build bites, even though builds existed and were previously guaranteed at
  least one slot.
- The PR's own added test (`takes one trace when the grade has shapes to
  trace...`) didn't catch this because it left `missions`/`shelf` empty,
  keeping the first-take sum for those categories below 5.

## Environment Details
- **Services Affected:** STUDENT/Frontend (React), junior/Kids Bites feature
- **Related Components:** `features/junior/bites.ts` (`dailySet`,
  `FIRST_TAKE`)
- **Time First Observed:** 2026-11-18, during `/code-review` of PR #152

## Investigation Steps

### 1. Initial Diagnosis
Code review flagged that `FIRST_TAKE = { quest: 2, card: 1, make: 1, trace: 1
}` sums to 5, and `take('build', DAILY_BITES)` is called after those four,
guarded by `count() < DAILY_BITES`.

### 2. Root Cause Analysis
Traced `take()`'s guard (`count() < DAILY_BITES`) and confirmed that once the
four first-takes exhaust the daily budget, the `build` fill call is a no-op,
and the top-up loop at the end only iterates `['quest', 'card', 'make',
'trace']` — `build` has no second chance to claim a slot anywhere in the
function.

### 3. Key Findings
- `build` had an implicit, undocumented invariant from before this PR: the
  other three categories' shares summed to 4 (`quest:2 + card:1 + make:1`),
  always leaving at least 1 slot for build to fill.
- Adding a fourth guaranteed category broke that invariant without anyone
  noticing, because the one test exercising the "trace + build together"
  path happened to leave the other two pools empty.

## Root Cause
An implicit cross-field invariant (`FIRST_TAKE`'s other shares must sum to
less than `DAILY_BITES` so `build` always has room) was never stated or
enforced in code, so a later addition to `FIRST_TAKE` silently violated it.

## Prevention / Rule
**Guardrail:** `build` now has its own explicit reserved share in
`FIRST_TAKE` (`build: 1`), taken *before* the other four compete for the
remaining budget, and the doc comment on `FIRST_TAKE` states the invariant
this protects against. A new regression test (`still gives build a slot when
quest, card, make and trace are all well-stocked`) exercises the specific
all-pools-full scenario the original test missed.

Restating the invariant as a reserved share (rather than a comment asking
future editors to "remember" the sum constraint) means a future edit can't
violate it without visibly changing `FIRST_TAKE` itself.

## Solution

### Immediate Fix
`FIRST_TAKE` now reserves `build: 1` first; the take-call order is `build`
(reserved) → `quest` → `card` → `make` → `trace` → `build` (fill) → top-up
for `quest`/`card`/`make`/`trace`. This matches the pre-existing behaviour
for every other combination of pools (verified against all 5 existing tests)
while guaranteeing `build` never drops to zero on a well-stocked day.

```typescript
export const FIRST_TAKE = { build: 1, quest: 2, card: 1, make: 1, trace: 1 } as const;
// ...
take('build', FIRST_TAKE.build);
take('quest', FIRST_TAKE.quest);
take('card', FIRST_TAKE.card);
take('make', FIRST_TAKE.make);
take('trace', FIRST_TAKE.trace);
take('build', DAILY_BITES);
for (const kind of ['quest', 'card', 'make', 'trace'] as const) take(kind, DAILY_BITES);
```

### Long-term Fix
None needed beyond the above; the fix is contained to `bites.ts`.

## Prevention
- [x] Code changes required (done)
- [x] Regression test added
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [ ] Documentation to update — n/a beyond the doc comment added

## Related Issues
- Same file flagged separately in this same review pass for the
  `TraceBoard.tsx` pointer-id race (see
  `HBEC-2026-11-18-traceboard-pointer-id-race.md`).

## References
- PR #152 (`feat/kids-trace-ink`)

---

**Resolved By:** Claude Sonnet 5 (agent session)
**Time to Resolution:** Same session as discovery
