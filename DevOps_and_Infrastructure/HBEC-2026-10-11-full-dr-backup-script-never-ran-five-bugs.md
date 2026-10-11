# Full disaster-recovery backup script never ran successfully — five stacked bugs

**Date:** 2026-10-11
**Project:** HBEC Platform
**Environment:** Production (`hbca-vps`)
**Severity:** High (no vector-store/media/config backup existed for at least 2 days, silently)
**Status:** Resolved

## Summary
`scripts/backup-hbec.sh` is the broader of two backup scripts on `hbca-vps`
— unlike `scripts/pg_backup.sh` (plain Postgres SQL dumps only, already
working and already synced to two remote VPS), this one is meant to cover
Postgres (custom format), Redis, **Qdrant** (the vector store — not backed
up anywhere else), media volumes and configs. Its root cron entry
(`0 2 * * * /opt/hbec/scripts/backup-hbec.sh`) had been firing nightly since
at least Oct 9 and failing every single time with `Permission denied` —
investigated after the user asked about backup status following an
unrelated disk migration. Fixing the permission bit alone would not have
produced a working backup: four more bugs were stacked underneath it, each
hidden by the one before it.

## Symptoms
- `backup.log`: two lines, every night, identical:
  `/bin/sh: 1: /opt/hbec/scripts/backup-hbec.sh: Permission denied`
- `/opt/hbec/backups/` contained only a handful of stale manual dumps dated
  `20260720` — no evidence the cron had ever produced a real backup.
- No user-facing symptom; found by directly auditing backup health, not by
  a failure report.

## Investigation Steps

### 1. Initial Diagnosis
`ls -la /opt/hbec/scripts/backup-hbec.sh` showed `-rw-r--r--` — not
executable, despite being invoked directly (no `bash` prefix) by cron.

### 2. Root Cause Analysis
Found the companion installer, `scripts/setup-cron.sh`, whose entire job is
to `chmod +x` the backup script before installing its cron line. The cron
line existed; the executable bit didn't — meaning either the cron entry was
added by hand without running the installer, or (matching this project's
established pattern of manually re-copying files to `/opt/hbec` since `git
push` never reaches it) the script file was overwritten by a later copy
that reset the bit, with nobody re-running `setup-cron.sh` afterward since
the cron line was already present and nothing prompted a re-run.

Fixing just the permission bit and running it manually surfaced four more
bugs in sequence, each only visible once the previous one stopped masking
it:

1. **Wrong Postgres role.** `pg_dump -U hbca` — the real database role is
   `hbec` (confirmed via `\du` on the live DB). Would have failed on the
   very first dump.
2. **Qdrant unreachable at the configured address.** The script targeted
   `http://localhost:6033/collections` on the host. `docker port
   hbec-qdrant` returns nothing — Qdrant publishes **no host port at all**;
   it's reachable only inside `hbec_db-net`, and only on `6333`, not
   `6033`. Its own image also has no `curl`/`wget` to `docker exec` into.
3. **Permission-denied writing the downloaded snapshot (curl exit 23).**
   Fixed #2 by running a throwaway `curlimages/curl` container on
   `hbec_db-net` — but that image runs as a non-root UID by default, which
   cannot write into the root-owned backup directory bind mount.
4. **Config backup targeted the wrong files entirely.** `docker-compose.yml`
   (the dev-only file, which happens to also exist on the VPS) instead of
   `docker-compose.production.yml` (what's actually running), and a dead
   `~/caddy-proxy/sites/hbca-portals.caddy` path that no longer matches the
   real Caddy config location (`docker/caddy/`).

A sixth, latent issue was caught before it could bite: the script requests
a fresh Qdrant snapshot every run via `POST .../snapshots` but never
deleted it from Qdrant's own disk after downloading — harmless while the
script never ran, but would have grown Qdrant's storage by a full snapshot
per collection every night once fixed.

### 3. Key Findings
- None of this was caught by any test or healthcheck — a cron job that
  silently fails every night produces no alert by default (same class of
  gap as the notifications `ReadOnlyError` found the same day: a broker/DB
  write failure needs to be watched for explicitly, not inferred from
  container health).
- The script was also never wired to leave the box at all — `pg_backup.sh`
  already syncs to two remote VPS (`restk-vps` / `chemglee-vps`, aliases
  added this session) but `backup-hbec.sh` had no remote step, so even a
  working run would have left the vector-store/media/config backup as a
  single point of failure on the source host itself.

## Root Cause
A file that is both an operational artifact (deployed by hand to `/opt/hbec`,
not by CI) and has a non-obvious activation step (its own execute bit, set
by a separate installer script rather than being executable in git) is a
file that silently breaks the moment either assumption is violated once.
Four further bugs (wrong DB role, wrong network/port assumption for a
container with no published port, wrong default user in a pulled image,
wrong file paths) had evidently never been exercised against the real
environment before being committed — the script was written against an
assumed topology, not the actual one.

## Prevention / Rule
**Guardrail:** any cron-invoked script deployed by hand to a VPS should be
checked into git with its execute bit tracked (`git update-index
--chmod=+x`), so a `git` based re-copy can't silently reset it the way a
plain `scp`/`cp` did here — and a monitoring check on `backup.log`'s last
line (or exit code) should alert if a backup cron produces an error on two
consecutive nights, rather than requiring someone to go looking.

## Solution

### Immediate Fix
- `chmod +x` the script on the VPS; fixed `-U hbca` → `-U hbec`; switched
  the Qdrant interaction to a throwaway `curlimages/curl:8.10.1` container
  on `hbec_db-net` targeting `qdrant:6333` with `--user root`; added a
  `DELETE` of each snapshot from Qdrant after download; corrected the
  config backup to `docker-compose.production.yml` and `docker/caddy/`.
- Added a remote-sync step sending the full tarball to `restk-vps`
  (`159.198.42.231`) and `chemglee-vps` (`93.127.143.153`) with
  `rsync --delete`, mirroring local's 14-day retention remotely.
- Root's crontab had no SSH identity on either remote box (unlike
  `pg_backup.sh`, which runs as `winstontino`, whose key was already
  authorized there). Generated a dedicated `ed25519` keypair for root on
  `hbca-vps` and installed the public key in `authorized_keys` on both
  remotes.
- Verified end to end **twice**, the second time clean: a 1.33GB tarball
  landed locally and on both remote hosts with matching byte sizes.

### Long-term Fix
- Track the execute bit in git for this file (see Guardrail).
- Add alerting on backup cron failures (both `pg_backup.sh` and
  `backup-hbec.sh` logs) rather than relying on someone asking.
- `setup-cron.sh` could be made idempotent-safe to re-run on every deploy
  of `/opt/hbec/scripts/` (it already guards against duplicate cron lines),
  closing the exact gap that let the permission bit drift silently.

## Prevention
- [x] Script fixed and verified running clean end to end (local + 2 remotes)
- [x] Execute bit set; root SSH identity provisioned for the two remote
      backup targets
- [ ] Track the execute bit in git (`chmod` mode on the blob)
- [ ] Alert on backup cron failure (either script) after 2 consecutive bad
      nights
- [ ] Make `setup-cron.sh` safe/cheap to re-run after every manual file copy
      to `/opt/hbec/scripts/`

## Related Issues
- `reports/HBEC-2026-10-11-docker-containerd-dataroot-migration.md` — the
  unrelated disk migration whose status check prompted this backup audit
- `project_zchpc_backup` memory — the existing pull-based backup to
  `zchpc-hbca-vps`, unaffected by this; this entry adds the two
  previously-undocumented push destinations (`restk-vps`, `chemglee-vps`)
  to the picture

## References
- `scripts/backup-hbec.sh`, `scripts/setup-cron.sh`, `scripts/pg_backup.sh`
- Commit `80563871`

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** ~45 minutes (diagnosis through two verified clean runs)
