# Graduates page crashed with "ReferenceError: User is not defined"

**Date:** 2026-10-13
**Project:** TESC
**Environment:** Staging
**Severity:** Critical
**Status:** Resolved

## Summary
The Graduates page threw an uncaught `ReferenceError: User is not defined`
on load and crashed entirely. Two `lucide-react` icons (`User`,
`Accessibility`) were used as `StatsCard` `icon` props without being
imported. The error was only visible at runtime because the project's
`tsc --noEmit -p .` invocation - used throughout this session to "verify"
frontend changes - was silently a no-op against the whole app, giving false
confidence that the page type-checked cleanly.

## Symptoms
- Browser console: `Uncaught ReferenceError: User is not defined`, full
  page crash on `/graduates`.

## Environment Details
- **Server/Host:** tesc-staging VM, `tesc-frontend_client-1` container
- **Services Affected:** `frontend/src/pages/Graduates.tsx`
- **Related Components:** `tsconfig.json` / `tsconfig.app.json`
- **Time First Observed:** 2026-10-13, user-reported

## Investigation Steps

### 1. Initial Diagnosis
The stack trace pointed at a minified bundle frame with no further detail
beyond "`User` is not defined." Grepped `Graduates.tsx` for `User` usage and
found two `StatsCard icon={User}` props, but the file's `lucide-react`
import list only included `UserCheck` - not `User`.

### 2. Root Cause Analysis
Ran `npx tsc --noEmit -p .` (the command used for "verification" earlier
this session) against the project - it reported **zero errors**, including
for this exact file, despite the undefined identifier. Inspected
`tsconfig.json` and found:
```json
{ "files": [], "references": [{ "path": "./tsconfig.app.json" }, ...] }
```
`"files": []` with only project references means `tsc -p .` (without
`--build`) compiles **nothing** - it's not an error, just silently checks
an empty file set. Re-ran against the actual app project config:
```bash
npx tsc --noEmit -p tsconfig.app.json
```
This immediately surfaced `error TS2552: Cannot find name 'User'. Did you
mean 'Users'?` and the same for `Accessibility` at the same lines.

### 3. Key Findings
- The undefined-identifier bug itself came from earlier work in this
  session (commit `d19c528`, "Refactor: bypass ReportBuilder and download
  PDF directly on Graduates, Staff, and ISEOP pages") that added these
  `StatsCard` icon usages without importing them.
- Vite's dev/build pipeline uses esbuild to strip TypeScript without
  type-checking, so `npm run build` succeeding never would have caught
  this either - only a real `tsc` pass against `tsconfig.app.json` (or an
  IDE with the right project context) would.
- A full `tsc --noEmit -p tsconfig.app.json` run surfaced ~40 pre-existing,
  unrelated type errors scattered across the app (`Facilities.tsx`,
  `Settings.tsx`, `Regional.tsx`, `Innovation.tsx`, duplicate interface
  declarations in `academic.types.ts`, etc.) - none fixed here, as they're
  long-standing and out of scope for this specific crash, but worth noting
  since they represent real (if mostly non-crashing) type drift.

## Root Cause
Two `lucide-react` icons (`User`, `Accessibility`) were referenced as JSX
values in `Graduates.tsx` without being imported, introduced in an earlier
commit this session. Nothing caught it before deploy because the project's
`tsc --noEmit -p .` command - the one actually run for verification -
silently checks zero files due to the root `tsconfig.json`'s `"files": []`
+ project-references-only setup, and Vite's build doesn't type-check at
all.

## Prevention / Rule
**Guardrail:** always type-check this project with
`npx tsc --noEmit -p tsconfig.app.json` (or `-p tsconfig.node.json` for
the node-side config), never bare `-p .` or no `-p` flag at all - the root
`tsconfig.json` has no files of its own and will report a clean pass
regardless of real errors in `src/`. Add a `"typecheck"` script to
`package.json` (`tsc --noEmit -p tsconfig.app.json`) so this isn't a
command a future session has to rediscover, and consider wiring it into
CI so an undefined-identifier crash like this can't reach staging at all.

This closes the gap because the actual defect (a missing import) is
exactly the class of error `tsc` exists to catch - the only reason it
didn't was pointing it at the wrong project file, not a limitation of
type-checking itself.

## Solution

### Immediate Fix
Added `User` and `Accessibility` to `Graduates.tsx`'s `lucide-react`
import. Also added the missing `inclusivity_category?: string` field to
the `StudentGraduate` TypeScript interface (read on the page, used safely
via `&&` short-circuiting so it wasn't a runtime crash, but was flagged by
the real typecheck once pointed at the correct config).

```bash
# Verified via the correct invocation:
npx tsc --noEmit -p tsconfig.app.json  # Graduates.tsx: 0 errors
npm run build  # succeeds
```

### Long-term Fix
Add the `"typecheck"` npm script and CI step described in the guardrail
above.

## Prevention
- [ ] Configuration changes needed — add a `typecheck` npm script (see
      guardrail).
- [ ] Monitoring/alerts to add — none specific.
- [ ] Documentation to update — note the correct `tsc` invocation in the
      project's CONTRIBUTING/README if one exists.
- [x] Code changes required — done (see Solution).

## Related Issues
- Caused by commit `d19c528` (earlier this session, prior to this entry's
  timestamp): "Refactor: bypass ReportBuilder and download PDF directly on
  Graduates, Staff, and ISEOP pages."

## References
- `frontend/src/pages/Graduates.tsx`
- `frontend/tsconfig.json`, `frontend/tsconfig.app.json`
- `frontend/src/lib/types/academic.types.ts`
- Commit: `c167d51` on `staging`.

---

**Resolved By:** tinomupezeni (with Claude Sonnet 5)
**Time to Resolution:** ~20 minutes
