# Deployment Pipeline Robustness & Permission Fixes

**Date:** 2026-05-09
**Project:** CRM
**Environment:** Production / VPS
**Severity:** High
**Status:** Resolved

## Summary
Encountered multiple critical failures during deployment to the VPS:
1. PermissionError when collecting static assets due to volume ownership conflicts.
2. Missing database migrations for the 'quotations' app.
3. False-positive "Success" messages in the deployment script despite remote command failures.
4. Final SSH timeouts causing confusion during the cleanup phase.

## Symptoms
- PermissionError: [Errno 13] Permission denied: '/app/staticfiles/admin/css/dashboard.css'
- App models out-of-sync with migrations in production.
- Script reporting "DEPLOYMENT SUCCESSFUL" even when critical setup steps failed.

## Root Cause
- **Permissions**: The staticfiles volume was populated/locked with root-owned files from previous runs, preventing the unprivileged 'app' user from overwriting them.
- **Migrations**: Local model changes in 'quotations' were not migrated before building/pushing images.
- **Script Logic**: The RunRemote helper in crm.ps1 lacked error checking for remote ssh exit codes.

## Solution

### Immediate Fix
1. Generated missing migrations locally (pps/quotations/migrations/0007...).
2. Modified crm.ps1 to force-clear and re-own the static files volume as oot before execution of collectstatic.
3. Added a migration check to the Preflight function to block builds if migrations are pending.
4. Implemented strict exit-on-error logic in RunRemote to ensure deployment halts on any failure.

`powershell
# crm.ps1 improvement
function RunRemote($cmd) {
    ssh $VPS_SSH $cmd
    if ($LASTEXITCODE -ne 0) {
        LogErr "Remote command failed: $cmd"
        exit 1
    }
}
`

## Prevention
- [x] Pre-flight migration checks added.
- [x] Volume permission automated fix added to deploy logic.
- [x] Strict error handling enforced in deployment automation.

---

**Resolved By:** Gemini CLI
**Time to Resolution:** 20 minutes
