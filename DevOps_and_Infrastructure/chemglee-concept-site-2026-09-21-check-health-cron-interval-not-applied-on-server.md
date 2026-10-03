# check_health Cron Interval "Fix" Never Reached the Server's Actual Crontab

**Date:** 2026-09-21
**Project:** chemglee-concept-site
**Environment:** Production VPS (93.127.143.153)
**Severity:** Low (noisy alerting, not an outage) but confusing — the team
believed this was already fixed.
**Status:** Resolved

## Summary
Commit `a57cfab` ("chore: adjust check_health cron interval to 2 days") was
believed to have relaxed the `check_health --notify` alert interval from
every 15 minutes to every 2 days. The Shop Manager admin is still receiving
alerts every 15 minutes after that commit was deployed.

## Symptoms
- Admin user reports still getting `check_health --notify` alerts every 15
  minutes, despite a commit that was supposed to change this to every 2 days.

## Environment Details
- **Server/Host:** VPS at `93.127.143.153` (`administrator@` user,
  `/opt/webapps/chemglee`), deployed via `deploy.sh`.
- **Services Affected:** `check_health --notify` alert cadence (Notifications
  channel), not the health check logic itself.
- **Related Components:** `backend/apps/common/management/commands/check_health.py`,
  `deploy.sh`.

## Investigation Steps

### 1. Initial Diagnosis
Checked what commit `a57cfab` actually changed:
```bash
git show a57cfab
```

### 2. Root Cause Analysis
The diff touches exactly two lines, both **comments/echo strings**, no
executable logic:
```diff
--- a/backend/apps/common/management/commands/check_health.py
-    */15 * * * * docker compose exec -T backend python manage.py check_health --notify
+    0 0 */2 * * docker compose exec -T backend python manage.py check_health --notify
--- a/deploy.sh
-echo "     */15 * * * * cd $REMOTE_APP_DIR && \\"
+echo "     0 0 */2 * * cd $REMOTE_APP_DIR && \\"
```
`deploy.sh`'s "POST-DEPLOY STEPS" section (step 6, around line 95) only
*prints* the recommended crontab line for whoever set up the server to copy
in by hand — the script never runs `crontab` itself. There is no automation
anywhere in this repo that installs or updates the server's crontab.

### 3. Key Findings
- Re-running `deploy.sh` (or shipping this commit) changes zero runtime
  behavior on the server — it only changes what text a human would see if
  they re-read the post-deploy instructions.
- The VPS's actual crontab still has whatever was typed in when the health
  check was first set up (`*/15 * * * *`), because nothing re-applies it on
  deploy.
- This is a process gap, not a code bug: `check_health.py` and the alerting
  logic behave correctly; the interval is fully controlled by a manually
  maintained crontab entry outside version control.

## Root Cause
`deploy.sh` documents the intended cron schedule but never installs it. The
team edited the documentation and assumed the fix was live, but the
schedule is real server state that nothing in the deploy pipeline
synchronizes with the repo.

## Prevention / Rule
**Guardrail:** Either (a) have `deploy.sh` manage the cron entry itself —
e.g. `ssh $REMOTE_USER_HOST "(crontab -l | grep -v check_health; echo '0 0 */2 * * ...') | crontab -"`
idempotently on every deploy, so the schedule in the repo is always what's
actually running, or (b) move the schedule into the container itself (e.g. a
`cron`/`supervisord` entry baked into the backend image) so it ships with
the code instead of living as a manually-typed line on the host. Either way,
"the crontab example in a comment changed" must never again be mistaken for
"the deployed schedule changed."

## Solution

### Immediate Fix
Confirmed the live crontab still had `*/15 * * * *`:
```bash
ssh administrator@93.127.143.153 "crontab -l"
```
Replaced just the `check_health` line, leaving the `backup-db.sh` line
untouched:
```bash
ssh administrator@93.127.143.153 "crontab -l | sed 's|^\*/15 \* \* \* \* cd /opt/webapps/chemglee|0 0 */2 * * cd /opt/webapps/chemglee|' | crontab -"
```
Verified the new crontab:
```
0 2 * * * /opt/webapps/chemglee/scripts/backup-db.sh >> /opt/webapps/chemglee/backups/backup.log 2>&1
0 0 */2 * * cd /opt/webapps/chemglee && docker compose exec -T backend python manage.py check_health --notify --quiet
```

### Long-term Fix
Automate cron installation from `deploy.sh` (or move the schedule inside the
container) per the guardrail above.

## Prevention
- [x] Configuration changes needed — live crontab on the VPS updated.
- [ ] Code changes required — make `deploy.sh` apply the cron schedule
      instead of only printing it.
- [ ] Documentation to update — note in `deploy.sh`'s post-deploy section
      that this step is manual and not re-applied by future deploys, until
      it's automated.

## Related Issues
- None yet logged for this project's DevOps category.

## References
- `git show a57cfab`
- `backend/apps/common/management/commands/check_health.py`
- `deploy.sh` (post-deploy step 6, ~line 95)

---

**Resolved By:** tinomupezeni + Claude Sonnet 5
**Time to Resolution:** Same session (~30 min from report to server fix)
