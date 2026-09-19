# Check Health Cron Interval Adjustment

**Date:** 2026-09-19
**Project:** chemglee-concept-site
**Environment:** Production (Configuration Recommendation)
**Severity:** Low
**Status:** Resolved

## Summary
The recommended cron job interval for the `check_health` script in the deployment documentation (`deploy.sh`) and the Python script's docstring (`check_health.py`) was set to run every 15 minutes (`*/15 * * * *`). The user requested to decrease the frequency to once every 2 days.

## Symptoms
- The health check job would run every 15 minutes and send an email to admins if failures occurred.
- User found the frequency too high and requested adjusting it to once every 2 days.

## Environment Details
- **Server/Host:** VPS (configured via `deploy.sh`)
- **Services Affected:** `backend` container (`check_health` management command)
- **Related Components:** `deploy.sh`, `backend/apps/common/management/commands/check_health.py`
- **Time First Observed:** N/A (Requested change)

## Investigation Steps

### 1. Initial Diagnosis
Searched the codebase for occurrences of "15" and "minutes" or "cron" to locate the job configuration. 

### 2. Root Cause Analysis
The job is not managed by an automated cron system in the codebase but rather is a manual post-deployment step recommended to the user in `deploy.sh` and documented in `check_health.py`. 

### 3. Key Findings
- Found `*/15 * * * * cd $REMOTE_APP_DIR && docker compose exec -T backend python manage.py check_health --notify --quiet` in `deploy.sh`.
- Found `*/15 * * * * docker compose exec -T backend python manage.py check_health --notify` in `backend/apps/common/management/commands/check_health.py`.

## Root Cause
The default frequency for the health check task in the documentation was every 15 minutes, which was too noisy/frequent for the user's preference.

## Prevention / Rule
**Guardrail:** Ensure that default alert intervals align with user expectations, and make cron intervals easily configurable rather than hardcoded in documentation if they need to be updated across multiple files.

If a project's manual post-deploy steps recommend a specific schedule, consider providing an environment-variable-driven scheduling mechanism (like Celery Beat) for easier updates instead of relying on manually configuring system cron tabs.

## Solution

### Immediate Fix
Updated the cron interval in both `deploy.sh` and `check_health.py` from `*/15 * * * *` (every 15 minutes) to `0 0 */2 * *` (at 00:00 on every 2nd day-of-month).

### Long-term Fix
N/A. This is a configuration preference.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [ ] Code changes required

## Related Issues
- None

## References
- None

---

**Resolved By:** Antigravity
**Time to Resolution:** 5 minutes
