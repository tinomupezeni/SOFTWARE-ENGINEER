# The honesty-failure reporter referenced an undeclared variable, so it crashed on its first finding

**Date:** 2026-09-26
**Project:** ArchCode (pixel-perfect-replication scaffold)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The loop that reports honesty violations incremented `honestyFailures`, a variable that was
never declared anywhere in the file. The line only executes when a rule actually matches, so
the counter was unreachable dead code for the entire life of the check. The suite therefore
had two behaviours and no third: with zero violations it ran to completion and reported
`all assertions passed`; with one or more violations it threw `ReferenceError:
honestyFailures is not defined` and aborted on the first hit, discarding the rest.

## Symptoms
- The project's honesty backstop could not report a violation. It threw instead.
- A `ReferenceError` traceback buried the actual `FAIL` lines, so the one thing a developer
  needed to see was the hardest thing to find.
- Only the *first* violation was ever reachable; the loop aborted before checking the
  remaining rules and files.
- It never surfaced during development because the suite was green — the bug lived in the
  failure path of a check that had not yet failed.

## Environment Details
- **Server/Host:** local dev (`npx tsx scripts/verify-semantics.ts`)
- **Services Affected:** `scripts/verify-semantics.ts` (honesty rule reporting block)
- **Related Components:** `HONESTY_RULES`, `files`
- **Time First Observed:** 2026-09-26, on the first `bun run verify` after switching package
  managers

## Investigation Steps

### 1. Initial Diagnosis
`bun run verify` failed with a `ReferenceError` pointing at the honesty loop, not at any
`FAIL` line. The reported cause was unrelated to what the check was supposed to detect.

### 2. Root Cause Analysis
```bash
grep -n 'honestyFailures' scripts/verify-semantics.ts
# 569:      honestyFailures++;
# one hit: a use, no declaration
```
TypeScript did not catch it. `tsx` transpiles without type-checking, and the project's real
typecheck is `tsc --noEmit` — which runs *after* the semantics script in the `verify` chain,
so the script crashed before the thing that would have flagged it ever executed.

### 3. Key Findings
- Assignment to an undeclared identifier is a `ReferenceError` in any module, so this was not
  a silent-corruption bug; it was a hard crash on the failure path.
- The failure path is the only path that had ever been untested, because the suite had been
  green since it was written.
- `verify` chains with `&&`, so the crash still failed the build — the gate was fail-closed.
  The damage was to diagnosability and to reporting completeness, not to correctness of the
  pass/fail verdict.

## Root Cause
A counter was incremented for symmetry with the neighbouring `failures++` and never
declared. The deeper cause is ordering: the assertion script that contains the type error
runs *before* `tsc --noEmit` in the `verify` chain, so the tool that would have caught the
mistake never got to run. A check is only as trustworthy as its failure path, and this one
had never been exercised.

## Prevention / Rule
**Guardrail:** Run `tsc --noEmit` (or at minimum typecheck the scripts directory) *before* the
assertion scripts in the `verify` chain, and give `scripts/` its own `tsconfig` so the
verification tooling is typechecked rather than only transpiled.

Ordering matters more than the individual check here: a type error in a script can only be
caught by a typechecker, and a typechecker placed after the script cannot catch it. Putting
`tsc` first means a mistake in the verification tooling is reported as a type error rather
than as an unexplained runtime crash inside an assertion run.

## Solution

### Immediate Fix
Removed the undeclared `honestyFailures++`. The loop now reports every violation it finds,
across all rules and all in-scope files, and still increments `failures` so the exit code is
unchanged.

The fix was found only because the suite was made to fail legitimately: adding the generated
file exclusion and the narrow-window fix produced real `FAIL`s for the first time, and the
reporter's failure path ran for the first time.

### Long-term Fix
Reorder `verify` so typechecking precedes the assertion scripts, and typecheck `scripts/`.

## Prevention
- [x] Undeclared variable removed
- [x] All violations now reported, not just the first
- [ ] Move `tsc --noEmit` to the front of the `verify` chain
- [ ] Add a `tsconfig` for `scripts/` so the tooling is typechecked, not just transpiled
- [ ] Exercise each assertion suite's failure path deliberately at least once

## Related Issues
- `Frontend_and_UI/ARCHCODE-2026-09-26-guardrails-that-could-not-fail.md`
- `Frontend_and_UI/ARCHCODE-2026-09-26-generated-types-scanned-as-hand-written-ui.md`

## References
- `scripts/verify-semantics.ts` (honesty reporting block)
- `package.json` (`verify` script ordering)

---

**Resolved By:** Claude (Anthropic), on behalf of the user
**Time to Resolution:** ~15 minutes
