# Full-backup cron executable bit regressed

**Date:** 2026-10-31
**Project:** HBEC
**Environment:** Production (`hbca-vps`)
**Severity:** High
**Status:** Workaround Applied

## Summary
The root cron entry for the full disaster-recovery backup again failed every night with `Permission denied`. The deployed script was mode `644` despite cron invoking it directly. A manual production install restored mode `755`, and a full backup completed on 2026-10-31. The next scheduled cron execution has not yet been observed.

## Symptoms
- `/opt/hbec/backups/backup.log` repeated `/bin/sh: 1: /opt/hbec/scripts/backup-hbec.sh: Permission denied`.
- The latest full archive before intervention was dated 2026-10-11.
- The first external mirror had no full archives; the second held only October 11 archives.

## Environment Details
- **Server/Host:** `hbca-vps`
- **Services Affected:** Root cron and full disaster-recovery backup.
- **Related Components:** `/opt/hbec/scripts/backup-hbec.sh`, root crontab, two external mirrors.
- **Time First Observed:** Re-discovered 2026-10-31 during a production backup preflight.

## Investigation Steps

### 1. Initial Diagnosis
Read root's crontab, script permissions, backup log, and local/mirror archive directories.

### 2. Root Cause Analysis
The cron command executes the script path directly, but its deployed file mode was `-rw-r--r--`. The previous October 11 repair had not made the executable bit durable through subsequent script copies.

```bash
ssh hbca-vps 'sudo -n crontab -l'
ssh hbca-vps 'ls -l /opt/hbec/scripts/backup-hbec.sh; tail -35 /opt/hbec/backups/backup.log'
```

### 3. Key Findings
- The same failure class was recorded on 2026-10-11 and recurred by 2026-10-31.
- The job runs as root at 02:00 UTC and requires an executable script.
- Reinstalling the updated script with mode `755` allowed a complete manual run.

## Root Cause
The deployment path can replace the cron script without preserving its executable bit; cron has no preflight or alert that would catch the resulting failure.

## Prevention / Rule
**Guardrail:** Deploy cron scripts with an explicit executable mode and make the backup schedule fail an automated executable-bit and last-success check. This closes the exact gap that allowed an earlier repair to regress silently.

## Solution

### Immediate Fix
Kept a copy of the previous deployed script, installed the updated script with mode `755`, and ran it successfully. A 2,002,721,459-byte archive reached both external VPSes with matching SHA-256 hashes.

```bash
ssh hbca-vps 'sudo -n install -m 755 /tmp/hbec-backup-20261031.sh /opt/hbec/scripts/backup-hbec.sh'
ssh hbca-vps 'sudo -n /opt/hbec/scripts/backup-hbec.sh'
```

### Long-term Fix
Add an automated check of the executable bit and last successful full archive after every deploy and scheduled run.

## Prevention
- [x] Production script installed executable and manual backup verified.
- [ ] Verify the next scheduled cron run.
- [ ] Add a deployment or monitoring guard for the executable bit and last-success age.

## Related Issues
- `DevOps_and_Infrastructure/HBEC-2026-10-11-full-dr-backup-script-never-ran-five-bugs.md`
- `DevOps_and_Infrastructure/HBEC-2026-10-31-full-backup-omitted-service-databases.md`

## References
- `scripts/backup-hbec.sh`
- `/opt/hbec/backups/backup.log`

---

**Resolved By:** Codex manual production repair; durable guard pending
**Time to Resolution:** Same session for manual backup; recurrence prevention pending
