# TESC Inclusivity edit availability check

**Date:** 2026-11-07
**Project:** TESC
**Type:** Deployment Verification
**Status:** Completed

## Summary
Checked whether the Inclusivity report table edit update is available in the
local codebase and at the requested staging URL. The implementation is present
locally and builds successfully, but staging still serves an older artifact
without the feature.

## Context / Trigger
The user requested verification of the Inclusivity report update at
`https://tesc-inst-staging.zchpc.ac.zw/dashboard/inclusivity`.

## Scope
Included the local institution frontend page, edit dialog, update service
usage, git history, local production build, staging route response, and
staging JavaScript bundle markers. No staging or production deployment was
performed, and no authenticated save action was attempted.

## Method
Inspected the local commit and source implementation, built `inst/`, fetched
the staging route and hashed bundle, and searched the deployed bundle for
feature-specific strings.

## Decisions & Findings
- Local commit `14ccc2c` adds the requested functionality.
- The table has a permission-gated pencil action using `student.edit`.
- The dialog edits the inclusivity category and persists through
  `updateStudent`.
- The local frontend build passes.
- Staging serves an October 26 bundle and lacks the new dialog strings.
- Conclusion: the update is available in the local codebase but not yet
  available at the staging URL.

## Changes Made
No TESC source or deployment files were changed. Added the issue log
`TESC-2026-11-07-staging-missing-inclusivity-edit.md`.

## Verification
- `cd inst && npm run build`: passed.
- Staging route: HTTP 200.
- Staging bundle feature markers: absent.
- Local feature commit: present and reachable from `HEAD`.

## Follow-ups / Deferred
- Deploy the feature-bearing commit to staging.
- Verify the pencil action with an authorized institution user.
- Save a category change and confirm the table refreshes with the persisted
  value.

## References
- `inst/src/pages/Inclusivity.tsx`
- `inst/src/components/EditInclusivityCategoryDialog.tsx`
- Commit `14ccc2c1da6655c177236c175cfc36d3e3cd262f`
- `TESC-2026-11-07-staging-missing-inclusivity-edit.md`

---

**Completed By:** Copilot
**Duration:** 2026-11-07
