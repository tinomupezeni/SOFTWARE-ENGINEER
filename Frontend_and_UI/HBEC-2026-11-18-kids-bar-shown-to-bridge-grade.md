# KidsBar shown to Grade 6-7 ("bridge") students on sub-pages

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (caught in code review, pre-merge)
**Severity:** Medium
**Status:** Resolved

## Summary
`KidsScreen` (the shared wrapper used by every Kids sub-page: Village, Build,
Bites, Quests, Make, Me) unconditionally rendered the bottom `<KidsBar />`,
with no grade/mode check — even though the product's own home-screen rule
(`KidsHomeView`'s `bar` prop, gated `mode === 'junior'`) states "Grade 6-7
have no bar."

## Symptoms
- No user-visible report yet; found during code review of PR #151
  (`feat/kids-make-me-curriculum`).
- A Grade 6/7 ("bridge") student navigating to `/village`, `/build`,
  `/bites`, `/quests`, `/make` or `/me` would see the ECD-Grade-5-only
  bottom bar, contradicting the documented design rule and the home screen's
  own behaviour.

## Environment Details
- **Services Affected:** STUDENT/Frontend (React), junior/Kids feature
- **Related Components:** `features/junior/QuestViews.tsx` (`KidsScreen`),
  `features/junior/KidsHomeView.tsx`, `features/junior/kidsHome.ts`
- **Time First Observed:** 2026-11-18, during `/code-review` of PR #151

## Investigation Steps

### 1. Initial Diagnosis
Code review flagged that `KidsScreen` renders `<KidsBar />` with no
condition, while `kidsHome.ts`'s own doc comment for `kidsDoors()` explicitly
states "Grade 6-7 have no bar."

### 2. Root Cause Analysis
`KidsHomeView` receives `bar` as an explicit prop from `JuniorHome.tsx`,
computed there via `experienceMode(grade) === 'bridge' ? 'bridge' : 'junior'`.
But `KidsScreen` — the wrapper used by every *other* Kids page — has no
access to that computation at all; it was written before the bridge/junior
split existed and never updated when it was introduced in this PR's sibling
work.

### 3. Key Findings
- `KidsScreen` is used by Village, Build, Bites, Quests, Make and Me — six
  pages that would all have shown the bar to bridge students.
- The home screen alone got the gating right, because it alone already
  computed `mode` for other reasons (building `kidsDoors`).

## Root Cause
A UI rule ("bar is junior-only") was encoded once, on the one screen whose
caller already happened to need `mode` for something else, instead of being
enforced by the shared wrapper that every screen actually uses.

## Prevention / Rule
**Guardrail:** the rule now lives in `KidsScreen` itself — it reads
`personalization.grade` via `useAuth()` and computes
`experienceMode(grade) !== 'bridge'` directly, so every current and future
page that renders through `KidsScreen` gets the gating for free, with
nothing for a caller to remember to pass in.

A shared layout invariant ("X renders only for mode Y") belongs in the one
component every consumer shares, not duplicated per caller.

## Solution

### Immediate Fix
`features/junior/QuestViews.tsx`: `KidsScreen` now calls `useAuth()` +
`experienceMode()` itself and only renders `<KidsBar />` (and the matching
`pb-32` bottom padding) when the learner is not in `bridge` mode.

### Long-term Fix
None needed — the fix removes the per-caller responsibility entirely.

## Prevention
- [x] Code changes required (done)
- [ ] Consider a lint rule / review checklist item for "bottom-bar visibility
      changed" whenever a Kids page is added, as a reminder this is enforced
      centrally and should not be re-added locally.

## Related Issues
- Same review surfaced 3 other #151 bugs (stale question state in MakePage,
  non-reactive shelf memo in useBites, orphaned localStorage tick entries —
  the last left unfixed, noted on the PR as a cleanup item).

## References
- `/code-review` of PR #151 (`feat/kids-make-me-curriculum`), 2026-11-18

---

**Resolved By:** Claude (code review + fix)
**Time to Resolution:** Same session
