# TESC Inclusivity edit staging deployment

**Date:** 2026-11-07
**Project:** TESC
**Type:** Deployment Verification
**Status:** Completed

## Summary
Pushed the local `staging` branch and deployed commit `1561e6a` to the idle
green color on `tesc-prod`. The Inclusivity edit bundle is now available
through `tesc-inst-staging.zchpc.ac.zw`; blue remained active and no traffic
cutover was performed.

## Context / Trigger
The local Inclusivity inline-edit feature was present but missing from the
staging bundle. The user requested that the code be pushed to GitHub and
deployed to the VM's idle color.

## Scope
Included pushing `staging`, checking out the exact commit on `tesc-prod`,
building all four green application services, migration safety validation,
container identity checks, nginx validation, and inactive-color smoke tests.
Excluded production cutover and authenticated data mutation.

## Method
Pushed commit `1561e6acfc9f002e0c3ae9001d7a63b049c27869`, checked it out on
the VM, ran `scripts/bluegreen-deploy.sh`, then verified all green image tags,
migration plan, nginx syntax, staging Host routes, and feature-specific
frontend bundle markers.

## Decisions & Findings
- `staging` was pushed from `c6bac5c` to `1561e6a`.
- Blue remains active at `94bf94e`.
- Green now consistently runs `1561e6a` for backend, worker, client, and admin.
- Green migration plan reports no pending operations.
- Both inactive staging Host routes return HTTP 200.
- The institution staging bundle contains `Edit Inclusivity Category` and
  `Inclusivity category updated`.
- No recent green container errors were observed.

## Changes Made
- GitHub branch `staging` advanced to `1561e6a`.
- Green containers rebuilt and recreated on `tesc-prod`.
- Green marker recorded as `.sha_green=1561e6a`.
- Updated the related staging-drift issue to resolved.

## Verification
- `scripts/check_compose_colors.py`: passed during deployment.
- `scripts/verify_expand_contract.py`: passed during deployment.
- Green services: all running with tag `1561e6a`.
- `python manage.py migrate --plan`: no planned operations.
- nginx configuration test: passed.
- `tesc-staging.zchpc.ac.zw`: HTTP 200.
- `tesc-inst-staging.zchpc.ac.zw`: HTTP 200 with both Inclusivity edit
  markers present.
- Public hosts remained HTTP 200 and blue remained active.

## Follow-ups / Deferred
- Perform an authenticated edit/save journey on the institution staging page.
- Cut over to green only after that user journey passes and the release is
  explicitly approved.

## References
- `scripts/bluegreen-deploy.sh`
- `docker-compose.bluegreen.yml`
- `inst/src/pages/Inclusivity.tsx`
- `inst/src/components/EditInclusivityCategoryDialog.tsx`
- `TESC-2026-11-07-staging-missing-inclusivity-edit.md`

---

**Completed By:** Copilot
**Duration:** Approximately 10 minutes
