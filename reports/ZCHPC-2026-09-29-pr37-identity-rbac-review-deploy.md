# PR #37 identity/RBAC rollout: review, merge, deploy

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Type:** Review + Deployment (third-party PR)
**Status:** Completed

## Summary

Reviewed, merged, and deployed Richard's `audit/identity-rbac`
(+12.7k/−1.3k, 152 files): per-module authorization rollout, temporary-
password confinement (REM-07), auth-route tightening (REM-08), recruitment
throttles (REM-04), token revocation on password change. Merged
(`c7e5f41`) only after reading the load-bearing diffs; verified on
staging with login/token/list + flagged-user confinement proofs; promoted
to prod. Zero prod accounts flagged; all testers must re-login once.

## Context / Trigger

Only open PR on the repo, by another developer, touching the auth core
every current deploy depends on. Blind merge declined; review-first
chosen.

## Scope

- Included: diff review (migrations, middleware, settings, portal auth
  flow, compose), merge, staging build + migration + e2e verification,
  prod promote + verify, tester comms notes.
- Excluded: the two committed resume PDFs (flagged to author, harmless);
  changing any PR content (merged as-is).

## Method

1. `gh pr view/diff`: file list → focused read of identity migrations,
   `middleware.py`, `route_access.py`, `settings.py`, portal
   `AuthContext`/`auth.service` 403 handling, `docker-compose.prod.yml`.
2. Merged only on CLEAN + review pass. Staging: fresh-build api/portal/
   frontend, watched migration logs, then proved behavior over real HTTP
   with throwaway accounts (never printed creds).
3. Prod: retag-promote (no prod rebuild), migration-watch, counts.

## Decisions & Findings

- 0004 additive (safe); 0005 idempotent surname-password flag with
  documented hasher cost — trivial at this user count.
- Middleware tightens `/api/v2/auth/` exemption to token endpoints and
  confines `must_change_password` holders pre-superuser-bypass (correct,
  intended).
- `CHECK_REVOKE_TOKEN` invalidates ALL pre-deploy tokens: every tester
  re-logs-in once. No way around it; communicated, not a bug.
- Portal handles the flow (`ChangePasswordPage`, context updates).
- `DRF_NUM_PROXIES` default 0 + direct `:8000` publishing means throttles
  key on REMOTE_ADDR — safe direction (over- not under-throttle);
  `docker-compose.prod.yml` sets 1 for its nginx-only topology. Our VM
  prod file untouched deliberately.
- Staging proofs: normal login 200 → list 200 (EMP0001 + H059 rows);
  flagged login 200 → employees 403 `PASSWORD_CHANGE_REQUIRED` →
  `/users/me/` 200. Exact spec behavior.
- Prod: migrations 0004/0005 + hr 0019/0020 clean; flagged count 0/7
  (no tester locked out); 8/8 healthy.

## Changes Made

- Merge commit `c7e5f41` (no local edits). VM: rebuilt staging images,
  retagged to `tinotenda762/*:latest`, recreated prod api/portal/frontend.

## Verification

- Staging e2e (above) + prod health/migrations/counts/bundles. Prod
  login-as-user not re-proven (no valid creds post-revocation — expected;
  staging proof covers identical images).

## Follow-ups / Deferred

- Tell Richard: drop the two resume PDFs from git.
- Consider split `VITE_API_URL_*` compose vars (standing item).
- Tester comms: re-login required; password-change prompt appears only
  for surname-password accounts (none on prod).

## References

- PR: https://github.com/tinomupezeni/ZCHPC-ERP/pull/37

---

**Completed By:** Muse Spark (opencode)
**Duration:** ~1h (review, merge, staging proofs, prod)
