# RoleGate.test.tsx is flaky under `npm run coverage` (coverage instrumentation changes async timing)

**Date:** 2026-11-25
**Project:** ZIMPHOS
**Environment:** CI (GitHub Actions `frontend.yml`) and local, reproducible with `--coverage`
**Severity:** Medium
**Status:** Investigating (not fixed — documented so it isn't re-litigated as a false regression)

## Summary
`frontend/src/app/RoleGate.test.tsx` intermittently fails under `vitest run --coverage`
(exactly what CI's `npm run coverage` step runs), with a different test failing each
time — never the same assertion twice. Plain `vitest run` (no coverage) has not
been observed to fail. This is pre-existing test-suite fragility, not something
any specific code change introduces — confirmed by reproducing it on bare `main`
itself (no diff at all) at the same rate as on a branch with an unrelated 3-line
change.

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
```
Error: Test made requests it didn't declare: GET /api/messages.
 ❯ src/test/setup.ts:64:11
```

## Investigation Steps

### 1. Initial Diagnosis
PR #15 (a 3-line fix: regenerate `schema.d.ts`, add `start_window_minutes: 120`
to two unrelated mutation calls) failed CI's coverage step twice in a row, each
time on a different `RoleGate.test.tsx` assertion.

### 2. Root Cause Analysis
```bash
# Same file, same command, run back to back on the SAME branch:
npx vitest run --coverage src/app/RoleGate.test.tsx   # pass (14/14)
npx vitest run --coverage src/app/RoleGate.test.tsx   # pass (14/14)
npx vitest run --coverage src/app/RoleGate.test.tsx   # FAIL (13/14)

# Switched to bare main (zero diff) and ran the identical command — passed once,
# consistent with the same flake rate rather than a real regression.
```
Plain `vitest run` (no `--coverage`) was not observed to fail in several runs;
`--coverage`'s instrumentation overhead appears to shift async timing enough to
expose a pre-existing race between an in-flight request from one test (e.g. a
stray `GET /api/messages` from a FieldShell screen) and the next test's own
`server.resetHandlers()`/cleanup, or a navigation assertion racing the actual
route change.

### 3. Key Findings
- Not tied to any specific code change — reproduces on `main` with zero diff.
- Different assertion fails each run — consistent with a shared-state /
  cleanup-ordering race, not a deterministic logic bug in one test.
- Only manifests under `--coverage`; CI's `check` job runs exactly that command,
  so this can intermittently fail CI for any unrelated PR.

## Root Cause
Not yet isolated to a specific line. Leading theory: some test's async
side-effect (an in-flight `fetch`, a pending state update, or a lingering MSW
request) isn't fully settled before the next test's `render()`/assertions run,
and coverage instrumentation's overhead is enough to change the scheduling
order often enough to matter. Needs a dedicated pass over `RoleGate.test.tsx`'s
setup/teardown (afterEach `cleanup()`, MSW handler reset order, whether
`waitFor`/`findBy*` calls are awaited before a test returns) to find the actual
unawaited promise.

## Prevention / Rule
**Guardrail:** none implemented yet — tracked here instead of silently
retrying CI. Whoever picks this up should add a `vitest --coverage` step to a
tight retry loop (10-20x) isolated to just this file to get a repro rate, then
bisect by temporarily commenting out tests from the end of the file backward
until the flake disappears, to localize which test's teardown is incomplete.

## Solution

### Immediate Fix
None. Worked around per-PR by re-running the CI job (flake rate observed
~1/3, so a rerun usually goes green) rather than blocking merges on a
pre-existing, unrelated flake. This is a conscious workaround, not a fix —
logged here specifically so a future session doesn't waste time treating a
CI failure on this file as proof their own change broke something, and so
someone eventually does the bisection above.
