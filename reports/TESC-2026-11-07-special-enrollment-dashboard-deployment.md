# TESC Special Enrollment dashboard deployment

**Date:** 2026-11-07
**Project:** TESC
**Type:** Deployment Verification
**Status:** Completed

## Summary
Pushed the main Special Enrollment dashboard enhancement and deployed the exact
commit to the idle green color on `tesc-prod`. The updated dashboard is
available through the main staging Host route while blue remains active.

## Context / Trigger
The main portal dashboard was enhanced with five support cards, separate
normal/ISEOP Top-5 disability charts, and a Work-for-Fees chart. The user
requested that the change be pushed and deployed to the idle color.

## Scope
Included committing and pushing the main frontend change, checking out the
exact commit on `tesc-prod`, rebuilding all four green services, migration
validation, artifact identity checks, nginx validation, and main/institution
staging smoke routes. Excluded traffic cutover and authenticated business
actions.

## Method
Pushed commit `615926834db3ff045a3d14703b3f518aab43aed4`, checked it out on the
VM, ran `scripts/bluegreen-deploy.sh`, then verified green image tags and
digests, migration plan, nginx syntax, Host-header routes, feature-specific
bundle markers, and recent container logs.

## Decisions & Findings
- GitHub `staging` advanced to `6159268`.
- Blue remains active at `94bf94e`.
- Green backend, worker, main frontend, and institution frontend all run tag
  `6159268`.
- Green migration plan reports no pending operations.
- Main staging bundle contains:
  - `Combined Support Students`
  - `Total Allocation Hours`
  - `Top 5 Disabilities (Normal)`
  - `Top 5 Disabilities (ISEOP)`
  - `Work-for-Fees by Service Area`
- Main and institution staging Host routes return HTTP 200.
- No recent green container errors were observed.

## Changes Made
- Pushed `frontend/src/modules/admissions/SpecialEnrollment.tsx` to GitHub.
- Rebuilt and recreated the green application tier on `tesc-prod`.
- Recorded `.sha_green=6159268`.
- Left public traffic on blue; no nginx cutover was performed.

## Verification
- `scripts/check_compose_colors.py`: passed during deployment.
- `scripts/verify_expand_contract.py`: passed during deployment.
- Green container identity: all four services tagged `6159268`.
- `python manage.py migrate --plan`: no planned operations.
- nginx configuration test: passed.
- `tesc-staging.zchpc.ac.zw`: HTTP 200 with all new dashboard markers.
- `tesc-inst-staging.zchpc.ac.zw`: HTTP 200.
- `tesc.zchpc.ac.zw`: HTTP 200 while blue remained active.

## Follow-ups / Deferred
- Perform a browser-level dashboard smoke test with real authenticated API
  data.
- Cut over to green only after explicit approval and any required user-path
  verification.

## References
- `frontend/src/modules/admissions/SpecialEnrollment.tsx`
- `scripts/bluegreen-deploy.sh`
- `docker-compose.bluegreen.yml`
- `TESC-2026-11-07-special-enrollment-dashboard-enhancement.md`

---

**Completed By:** Copilot
**Duration:** Approximately 10 minutes
