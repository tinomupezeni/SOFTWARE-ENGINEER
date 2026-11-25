# RoleGate.test.tsx was flaky under `npm run coverage` (asserted on async side-effects synchronously)

**Date:** 2026-11-25
**Project:** ZIMPHOS
**Environment:** CI (GitHub Actions `frontend.yml`) and local, reproducible with `--coverage`
**Severity:** Medium
**Status:** Resolved

## Summary
`frontend/src/app/RoleGate.test.tsx` intermittently failed under `vitest run
--coverage` (exactly what CI's `npm run coverage` step runs), with a different
test failing each run. Root cause: two tests asserted on an async side-effect
synchronously right after an unrelated `findByRole()` resolved, instead of
using `waitFor`. Fixed by wrapping both assertions in `waitFor`.

## Symptoms
Two different failures observed across repeated runs of the exact same file,
same command, same codebase state:
```
Error: expect(element).toHaveTextContent()
Expected: /^\/$/
Received: /statement/1/2026-10
 ❯ src/app/RoleGate.test.tsx:207:41
```
```
AssertionError: expected [...] to deeply equal [...]
- Expected
+ Received
  [ "/api/dispatches", "/api/me", - "/api/messages", "/api/stocktakes" ]
 ❯ src/app/RoleGate.test.tsx:142:43
```

## Investigation Steps

### 1. Initial Diagnosis
PR #15 (a 3-line fix: regenerate `schema.d.ts`, add `start_window_minutes: 120`
to two unrelated mutation calls) failed CI's coverage step three times in a
row, twice on the same assertion (line 142), once on a different one (207).

### 2. Root Cause Analysis
```bash
# Same file, same command, run back to back on the SAME branch:
npx vitest run --coverage src/app/RoleGate.test.tsx   # pass (14/14)
npx vitest run --coverage src/app/RoleGate.test.tsx   # pass (14/14)
npx vitest run --coverage src/app/RoleGate.test.tsx   # FAIL (13/14)

# Reproduced identically on bare main (zero diff) — ruled out this PR's own change.
```
Read the two failing tests directly (`RoleGate.test.tsx:142` and `:207`):
- Line 142: `expect([...new Set(requests)].sort()).toEqual([...])` ran immediately
  after `await screen.findByRole('heading', ...)` resolved — but `findByRole`
  only waits for the *heading* to commit, not for every screen's own
  TanStack Query fetch (`/api/messages` here) to have actually fired yet.
- Line 207: `expect(screen.getByTestId('where')).toHaveTextContent(/^\/$/)` ran
  immediately after the sign-in heading appeared — but the heading comes from
  the `/me` re-fetch turning 401, a separate async chain from the logout
  mutation's own `onSettled` → `navigate('/')` callback.

Both are a classic "commit happened, but the *other* async chain I care about
hasn't necessarily finished yet" race. `--coverage`'s instrumentation overhead
just shifts scheduling enough to flip which one wins, often enough to matter
in CI specifically (close to every third run there).

### 3. Key Findings
- Not tied to any specific code change — reproduced on `main` with zero diff.
- Different assertion failed each run — consistent with two independent
  unawaited races in the same file, not one deterministic bug.
- Only manifested under `--coverage`; plain `vitest run` was never observed
  to fail across many runs.

## Root Cause
Two tests used a bare synchronous `expect(...)` for something that is
genuinely asynchronous relative to the one `await findByRole(...)` the test
had actually waited for. This project's own testing rule
(`react/testing.md`: "`waitFor` for async expectations on side effects or
other matchers") already says not to do this — these two tests just didn't
follow it.

## Prevention / Rule
**Guardrail:** this exact pattern (`findBy*` followed by a bare `expect` on
something that isn't the thing `findBy*` waited for) is exactly what
`react-testing`/`react/testing.md`'s "Async Assertions" section already
guards against. No new guardrail needed — the existing rule was simply not
applied to these two assertions; worth a quick grep (`expect\(.*\)\.to` not
preceded by `await waitFor`/`findBy` on the same logical assertion) across
other test files if this class of flake resurfaces elsewhere.

## Solution

### Immediate Fix
Wrapped both assertions in `await waitFor(() => expect(...))`
(`frontend/src/app/RoleGate.test.tsx`, PR #15). Verified with 5 consecutive
clean `--coverage` runs of the file (previously failing roughly 1 run in 3),
then a full-suite run (280/280).
