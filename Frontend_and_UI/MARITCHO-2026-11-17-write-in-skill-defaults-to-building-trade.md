# Unmatched write-in skill silently defaults to BUILDING trade, affecting real worker routing

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** Medium
**Status:** Confirmed — not yet fixed (found during verification of a candidate code-review finding)

## Summary
`composeSkillWithWriteIn` (`frontend/src/core/format/trades.ts:392-418`) falls back to the literal
string `"BUILDING"` for the `trade` field whenever a write-in skill description doesn't match any
known skill (`matched?.trade ?? "BUILDING"`). This is not cosmetic: `PostJobScreen.tsx` sends this
`trade` value straight to the backend as the job's real `trade` field, and
`frontend/src/features/workers/hooks.ts` uses the same `trade` value to query `nearbyWorkers(suburb, trade, query)`
for actual worker matching. A write-in like "babysitter" — a real job need, not a construction
trade — with no keyword match gets silently created and routed as a BUILDING-trade job, sending it to
bricklayers/tilers/painters instead of an appropriate worker pool, with no indication to the employer
that their input was reinterpreted.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- Posting a job with a write-in skill that has no `SKILL_GROUPS` keyword match (confirmed example:
  "babysitter") creates a job with `trade: "BUILDING"` and routes worker-matching accordingly, with no
  warning to the employer.

## Environment Details
- **Server/Host:** N/A (Next.js frontend)
- **Services Affected:** Job posting (`PostJobScreen`), worker-proximity/trade matching
- **Related Components:** `trades.ts` (`composeSkillWithWriteIn`, `predictSkills`),
  `workers/hooks.ts` (`nearbyWorkers`)
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding claimed the write-in resolution's unmatched branch defaults `trade` to the literal
`"BUILDING"` rather than leaving it unresolved, and that this default is consumed downstream for real
worker routing, not just display.

### 2. Root Cause Analysis
- Exact code confirmed verbatim: `trade: matched?.trade ?? "BUILDING"` (line 418).
- For a write-in with no matching skill (e.g. "babysitter" — no trade-bearing `SKILL_GROUPS` entry's
  label/keywords prefix-matches it in `predictSkills`), `matched` is `undefined`, so `trade` defaults
  to `"BUILDING"` and `id` to `"custom"`.
- `PostJobScreen.tsx` computes `effectiveSkill = composeSkillWithWriteIn(skill, writeInSkill)` then
  builds `const input = { trade: effectiveSkill.trade, ... }` sent straight to `createJob.mutate(input)` —
  i.e. it becomes the job's real backend `trade` field.
- `frontend/src/features/workers/hooks.ts` (~lines 101-104) uses that same `trade` value to query
  `nearbyWorkers(suburb, trade, query)` — actual worker routing/matching, not just a display label.
- Side note found during verification: the specific example "car washer" actually escapes this
  fallback and resolves to "Welder" instead, because `wordMatches` lets the word "car" match welder's
  keyword "carport" via `term.startsWith(word)` — a separate, related keyword-overmatch quirk in
  `matchSkills`/`wordMatches`, not itself part of this finding, but worth noting since it means the
  BUILDING-default path is reached less often than a naive reading suggests, while still being
  reachable and wrong when it is (as "babysitter" demonstrates cleanly).

### 3. Key Findings
- There is no "unresolved/unknown trade" representation in the domain — the code was forced to pick
  some literal trade string, and picked the first/most common one (`BUILDING`) rather than
  null/unresolved.

## Root Cause
`composeSkillWithWriteIn`'s return type requires a non-null `trade` field, but the function has no way
to express "we don't know this skill's trade" — so when no match is found, it substitutes an arbitrary
concrete trade (`"BUILDING"`) instead of surfacing that uncertainty to the caller, which then silently
propagates into real worker-matching logic.

## Prevention / Rule
**Guardrail:** Change `composeSkillWithWriteIn`'s return type to allow `trade: Trade | null` for the
unmatched case, and make `PostJobScreen.tsx` block submission (or route to the existing backend
semantic trade classifier / vector skill search already wired into this screen for suggestions) when
`trade` is null, rather than defaulting to any concrete trade.

This targets the Root Cause directly: the bug exists because the type system currently forces a
concrete trade value even when none is known; making "unknown" representable in the type removes the
need for an arbitrary default and forces every caller to handle the unresolved case explicitly.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed, currently-reachable job-routing bug found during
review of PR #12; it has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Resolve unmatched write-ins via the existing backend semantic trade classifier
  (`infer_best_trade`/`rank_skills_by_query` in `shared_kernel/embeddings.py`, already reused by
  `ListNearbyWorkersUseCase`) instead of a client-side keyword-only fallback, since the screen already
  calls a backend vector skill search (`useSearchSkills`) for suggestions.
- Until then, at minimum stop defaulting to `"BUILDING"`; surface an explicit "we're not sure what
  trade this is — please pick one" prompt instead.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — consider alerting/logging when the unmatched-write-in fallback fires,
      to measure how often non-construction write-ins are mislabeled
- [ ] Documentation to update — none yet; depends on chosen fix
- [x] Code changes required — stop defaulting unmatched write-ins to `"BUILDING"` (not yet implemented)

## Related Issues
- Found while reviewing MARITCHO PR #12 (branch `pr-12`), the same PR that introduced this function.
- Related: `Frontend_and_UI/MARITCHO-2026-11-17-write-in-skill-label-not-updated-after-match.md` —
  same function, a different bug in the matched branch's `label` field.

## References
- `frontend/src/core/format/trades.ts:392-418` (`composeSkillWithWriteIn`)
- `frontend/src/features/jobs/PostJobScreen.tsx` (sends `effectiveSkill.trade` to `createJob`)
- `frontend/src/features/workers/hooks.ts:~101-104` (`nearbyWorkers(suburb, trade, query)`)
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)
