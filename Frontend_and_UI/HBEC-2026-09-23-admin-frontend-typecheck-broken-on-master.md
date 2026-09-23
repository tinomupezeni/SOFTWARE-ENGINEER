# Admin Frontend Failed to Typecheck on Master — Missing Component, Duplicated Imports

**Date:** 2026-09-23 (found and fixed, same session)
**Project:** HBEC
**Environment:** Master branch, pre-deploy — found while extending the
System Errors feature cross-service; `npm run typecheck` was run as a
matter of course before committing and failed on files unrelated to the
change being made
**Severity:** High — the entire admin frontend failed `tsc -b`, meaning
no confidently-clean build existed on `master` at all, for any feature
**Status:** Resolved

## Summary
Two independent, unrelated bugs in the same batch of already-pushed
"Technical" nav section commits both broke `npm run typecheck`
project-wide:

1. `SystemErrorsPage.tsx` imported `PageHeader` from
   `@/components/layout/PageHeader` — a component that does not exist
   anywhere in this codebase. Every sibling page in the same feature
   (`AuditLogPage.tsx`, etc.) builds its header inline instead; nothing
   ever created this component.
2. `Sidebar.tsx` and `MobileSidebar.tsx` each had the same three import
   lines — `useQuery`, `getReplicationStats`, `apiFetch` — written twice,
   verbatim, back to back (`TS2300: Duplicate identifier`).

## Symptoms
Not yet reported by an end user — this is a build-time failure, not a
runtime one, so it would have surfaced the next time anyone ran
`npm run typecheck` or a production build, not from clicking around a
running dev server (Vite's dev server tolerates some type errors that
`tsc -b` does not).

## Investigation Steps

### 1. Initial Diagnosis
Ran `npm run typecheck` before committing new work (standard practice
this session) and got 13 errors across 3 files that this session's own
changes had not touched.

### 2. Root Cause Analysis
- `grep -rn "PageHeader"` across `src/components/` and
  `src/features/technical/` found the import but no definition anywhere
  in the repo — not a wrong path, a component that was never created.
- `sed -n '1,30p'` on both sidebar files showed the identical three-line
  import block appearing twice in immediate succession.

### 3. Key Findings
- `AuditLogPage.tsx` and `ReplicationPage.tsx`, built in the same nav
  section, don't reference `PageHeader` at all and use plain
  `<h1>`/`<p>` markup — this was never a shared pattern to begin with,
  just one file's wrong assumption.
- The duplicated sidebar imports are unrelated to any specific page —
  they broke the whole app's typecheck regardless of what else was being
  worked on, since `Sidebar`/`MobileSidebar` are always-mounted layout
  components.

## Root Cause
Two unrelated authoring mistakes landed in the same commit batch: one
file assumed a shared component existed without checking, and two files
each had the same three-line import block pasted in twice.

## Prevention / Rule
**Guardrail:** `npm run typecheck` must pass before any frontend commit
in this repo — this specific incident is exactly what that check exists
to catch, and it would have caught both of these bugs immediately if run
before the commits that introduced them landed.

## Solution

### Immediate Fix
- `SystemErrorsPage.tsx`: removed the `PageHeader` import and usage,
  replaced with the same inline `<h1>`/`<p>` header markup
  `AuditLogPage.tsx` already uses.
- `Sidebar.tsx` / `MobileSidebar.tsx`: removed the duplicated
  `useQuery`/`getReplicationStats`/`apiFetch` import lines (kept one copy
  of each).

### Long-term Fix
None beyond the guardrail above.

## Verification
- `npm run typecheck`: clean (was failing with 13 errors before this
  fix).
- Full vitest suite: 261/261 passing.
- `eslint` on every touched file: clean (one pre-existing
  `no-explicit-any` warning on `SystemErrorLog.payload`, left as-is —
  genuinely unstructured JSON from the backend).

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a
- [x] Documentation to update — this entry
- [x] Code changes required — done, see Immediate Fix

## Related Issues
Found in the same investigation as
`HBEC-2026-09-23-system-errors-page-completely-unreachable.md` (separate
root cause: URL wiring and a base-path mismatch, specific to the System
Errors feature rather than the whole app).

## References
- `ADMIN/adminFrontend/src/features/technical/pages/SystemErrorsPage.tsx`
- `ADMIN/adminFrontend/src/shared/components/Sidebar.tsx`
- `ADMIN/adminFrontend/src/shared/components/MobileSidebar.tsx`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Found and fixed same session, 2026-09-23.
