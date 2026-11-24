# PostJobScreen fetched /jobs/ on every non-edit mount

**Date:** 2026-11-24
**Project:** MARITCHO
**Environment:** Development (caught in PR review)
**Severity:** Low
**Status:** Resolved

## Summary
`PostJobScreen` called `useJob(props.editJobId ?? "")` unconditionally even
when not editing (`editJobId` undefined), and `useJob`/`fetchJob` had no
`enabled` guard, so every "Post a job" (non-edit) mount fired a spurious
`GET /jobs/` request and populated the query cache with a bogus
`job("")` entry.

## Symptoms
- Caught during code review of PR #14, not yet reproduced in production.
- Any buyer opening the normal "Post a job" screen (not the edit route)
  triggered an extra network request to `/jobs/` on every mount, wasting a
  request/data bundle against this project's offline-first, small-data-
  bundle constraint (see AGENTS.md "General Architectural Rules").

## Environment Details
- **Server/Host:** N/A (code review, pre-merge)
- **Services Affected:** "Post a job" screen (non-edit path)
- **Related Components:** `frontend/src/features/jobs/PostJobScreen.tsx`,
  `frontend/src/features/jobs/hooks.ts` (`useJob`)
- **Time First Observed:** 2026-11-24

## Investigation Steps

### 1. Initial Diagnosis
`/code-review` run against PR #14 flagged the unconditional `useJob` call
at the top of `PostJobScreen`.

### 2. Root Cause Analysis
Read `useJob` in `hooks.ts`: it called `useQuery` with no `enabled` option,
so it always fires regardless of whether `jobId` is a real id or the `""`
fallback used for the non-edit path.

### 3. Key Findings
- This is distinct from the normal `useMyJobs`-style hooks elsewhere in the
  file, which do pass `enabled: isEnabled`.

## Root Cause
`useJob` was written assuming it would only ever be called with a real job
id; `PostJobScreen` then called it unconditionally with an empty-string
sentinel for the non-edit case, with nothing to suppress the resulting
fetch.

## Prevention / Rule
**Guardrail:** any hook built on `useQuery` with an optional/sentinel id
argument must pass `enabled: <id is present>` — matching the existing
pattern already used by `useMyJobs` in the same file. This closes the class
of bug where a "maybe present" id silently still fires a query.

## Solution

### Immediate Fix
Added `enabled: jobId.length > 0` to `useJob` in
`frontend/src/features/jobs/hooks.ts`.

### Long-term Fix
None further needed; covered by the immediate fix.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (done, commit 319e337)

## Related Issues
- GitHub PR Rest-creator/MARITCHO#14

## References
- Commit 319e337 on branch `experimental`

---

**Resolved By:** Claude Code (code review + fix)
**Time to Resolution:** Same session
