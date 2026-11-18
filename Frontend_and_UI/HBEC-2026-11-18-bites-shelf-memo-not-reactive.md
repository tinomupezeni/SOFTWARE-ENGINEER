# Today's Bites memo doesn't react to newly shelved cards

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (caught in code review, pre-merge)
**Severity:** Low
**Status:** Resolved

## Summary
`useBites`' `useMemo` that builds the day's bite set called `readShelf()`
(a localStorage read) inside its body, but the memo's dependency array was
`[status, quest, day, grade]` — none of which change when a card is shelved
in the Village. A child who shelved a new flashcard and went straight to
Bites in the same session/day would not see it until an unrelated
dependency changed.

## Symptoms
- No user report; found in code review of PR #151.

## Environment Details
- **Services Affected:** STUDENT/Frontend, junior/Bites feature
- **Related Components:** `features/junior/useBites.ts`

## Investigation Steps

### 1. Initial Diagnosis
`useMemo`'s dependency array is the only thing React checks to decide
whether to recompute; a value read inside the memo body but not listed
there is invisible to it.

### 2. Root Cause Analysis
`readShelf()` isn't itself a React-reactive value (it's a plain
localStorage read), so it was never going to "just work" as a dependency —
it needed a derived, comparable key.

### 3. Key Findings
- The bug is silent: no error, no stale-data warning, just a flashcard that
  doesn't show up until something else (status/quest/day/grade) happens to
  change.

## Root Cause
A non-reactive read was used inside a memoized computation without giving
the memo anything reactive to key off.

## Prevention / Rule
**Guardrail:** when a `useMemo`/`useEffect` body reads external mutable
state (localStorage, a ref, a module-level cache) that isn't itself a React
value, derive a cheap, stable key from it (an id list, a count, a hash) and
list *that* in the dependency array — never rely on a bare read inside the
body being "caught" by unrelated dependencies.

## Solution

### Immediate Fix
`useBites.ts`: the shelf is now read once per render (`const shelf =
readShelf()`), a stable `shelfKey` (joined card ids) is derived from it, and
`shelfKey` is added to the memo's dependency array; the memo now reuses the
already-read `shelf` value instead of calling `readShelf()` again inside its
body.

### Long-term Fix
None needed.

## Prevention
- [x] Code changes required (done)

## Related Issues
- Found alongside 3 other #151 bugs in the same review pass.

## References
- `/code-review` of PR #151, 2026-11-18

---

**Resolved By:** Claude (code review + fix)
**Time to Resolution:** Same session
