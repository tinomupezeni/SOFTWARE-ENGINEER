# Shared VPS (`smepulse-vm`) root filesystem went read-only from disk I/O errors, breaking Postgres for two unrelated projects

**Date:** 2026-09-29
**Project:** Club Zero (found while deploying its backend; affected other projects sharing the same VM)
**Environment:** Production (shared VPS, `10.50.101.11`, alias `smepulse-vm`)
**Severity:** High (kernel had already emergency-remounted the root filesystem read-only, and two other projects' Postgres containers — `topshelf-bot-postgres`, `smepulse-bot-postgres` — were already `unhealthy` as a result, before this was even discovered)
**Status:** Resolved

## Summary
While preparing to deploy Club Zero's backend to a VPS the user pointed to
for hosting, an initial SSH login and `ssh-copy-id` attempt failed with
`cannot create .ssh/authorized_keys: Read-only file system`. Investigation
found the root filesystem (`/dev/xvda2`, ext4) had been automatically
remounted read-only by the kernel (`emergency_ro`) following real block-
device I/O errors — not just filesystem metadata corruption. This VM is
shared: it also runs `topshelf-bot` (webhook, admin, Postgres) and
`smepulse-bot`/`labflow-ai-main` containers, unrelated to Club Zero. Both
Postgres containers on the box were already showing `unhealthy` in `docker
ps` — almost certainly because they couldn't write to their data
directories once the filesystem went read-only.

## Symptoms
- `ssh-copy-id` failed: `cannot create .ssh/authorized_keys: Read-only
  file system`.
- `mount | grep ' / '` showed `/dev/xvda2 on / type ext4
  (rw,relatime,emergency_ro)` — the `emergency_ro` flag present despite
  `rw` also being listed; any real write (even after an explicit `mount -o
  remount,rw /`) still failed with "Read-only file system." The remount
  request was silently not honored by the kernel, which is expected:
  `emergency_ro` is a one-way safety trip, not a toggle.
- `topshelf-bot-postgres-1` and `smepulse-bot-postgres-1` both showed
  `(unhealthy)` in `docker ps`, pre-dating this investigation.
- `dmesg` (needed `sudo`, not readable as a normal user) showed the actual
  chain of events: `I/O error, dev xvda, sector 4096 op 0x1:(WRITE)` →
  `Buffer I/O error on dev xvda2 ... lost sync page write` →
  `EXT4-fs (xvda2): I/O error while writing superblock` → repeated
  `EXT4-fs error ... Detected aborted journal` (from `gunicorn`, `cron`,
  `postgres` — i.e. real application processes hitting it) →
  `EXT4-fs (xvda2): Remounting filesystem read-only`. A second, separate
  batch of I/O errors (this time on **read**) appeared much later in the
  buffer, suggesting the underlying issue wasn't a single one-off glitch.

## Environment Details
- **Server/Host:** VPS `10.50.101.11` (private/internal address; reached
  in production via a separate cPanel-managed public domain + gateway,
  not directly). SSH alias added: `smepulse-vm` in
  `~/.ssh/config` on the deploying machine.
- **Services Affected:** The entire VM — `topshelf-bot-webhook`,
  `topshelf-bot-admin`, `topshelf-bot-postgres`, `smepulse-bot-postgres`,
  `labflow-ai-main-ml_engine`/`frontend`/`backend`, plus blocked the new
  Club Zero deployment before it could even start.
- **Time First Observed:** 2026-09-29, during the first SSH/deployment
  attempt for Club Zero's backend.

## Investigation Steps

### 1. Initial Diagnosis
`ssh-copy-id`'s failure looked at first like a permissions issue specific
to the `user` account, until `mount` revealed the whole root filesystem
was affected, not just one directory.

### 2. Root Cause Analysis
```
# mount showed the emergency flag
/dev/xvda2 on / type ext4 (rw,relatime,emergency_ro)

# a remount request didn't clear it — confirmed with a real write test
sudo mount -o remount,rw /
touch /forcefsck   # still: Read-only file system

# dmesg (sudo) showed the actual trigger
I/O error, dev xvda, sector 4096 op 0x1:(WRITE) ...
Buffer I/O error on dev xvda2, logical block 0, lost sync page write
EXT4-fs (xvda2): I/O error while writing superblock
EXT4-fs error (device xvda2): ext4_journal_check_start:86: comm postgres: Detected aborted journal
EXT4-fs (xvda2): Remounting filesystem read-only
```
`tune2fs -l /dev/xvda2` confirmed `Filesystem state: clean with errors` —
the error flag was set, which (independent of the legacy `/forcefsck`
mechanism, which also couldn't be used here since the disk that needed the
marker file was itself the one that was read-only) is enough on its own to
make Ubuntu's boot-time `e2fsck` perform a real check-and-repair pass
before the root filesystem is mounted read-write for normal use.

### 3. Key Findings
- This is a genuinely shared production box, not a dedicated one for
  Club Zero — any fix here had blast radius on three other live projects.
  All their containers were confirmed `unless-stopped` before proceeding,
  which meant a reboot was safe to attempt (Docker restarts them
  automatically once the daemon comes back).
- The classic `sudo touch /forcefsck && reboot` fix for a read-only root
  filesystem doesn't work when the filesystem that needs the marker file
  is the one that's already read-only — a chicken-and-egg problem. The
  correct fallback is: check whether the superblock's error flag is
  already set (`tune2fs -l`), which independently guarantees a boot-time
  check will run without needing to write anything first.
- No separate `/boot` partition existed on this VM (`xvda1` is a 1MB BIOS
  boot partition with no filesystem, `xvda2` holds everything) — there was
  no alternate writable partition to stage a fix from either.

## Root Cause
The underlying virtual disk (`xvda`) threw real write and (later, read)
I/O errors at the block-device level — not just filesystem-level
corruption — which caused ext4 to abort its journal and the kernel to
safety-trip the root filesystem into `emergency_ro`. No new I/O errors
have recurred since the reboot/fsck, so this may have been a transient
host-side storage hiccup rather than ongoing hardware failure, but that
can't be fully ruled out from inside the VM alone.

## Prevention / Rule
**Guardrail:** Before attempting any write-based fix (`/forcefsck`, log
rotation, app writes) on a filesystem reported as read-only or
`emergency_ro`, check `tune2fs -l <device>`'s `Filesystem state` first —
if it already shows `error` or `clean with errors`, a plain reboot alone
is sufficient to trigger a real check-and-repair pass; don't waste time on
write-based workarounds that will fail identically to the original
symptom.

Longer-term, for this specific box: since block-device I/O errors
recurred in two separate bursts in the dmesg buffer, it's worth watching
`dmesg`/`journalctl` for recurrence — a repeat means this needs escalating
to whoever manages the underlying VPS/hypervisor storage (the fix here
was reactive, not a guarantee the underlying disk is healthy long-term).

## Solution

### Immediate Fix
1. Confirmed all running containers used `restart: unless-stopped`
   (`docker inspect --format='{{.Name}}: {{.HostConfig.RestartPolicy.Name}}' $(docker ps -q)`)
   before proceeding, so a reboot wouldn't strand the other projects.
2. `sudo reboot` — Ubuntu's boot-time fsck detected the superblock error
   flag and ran automatically (confirmed via
   `journalctl -b | grep fsck`, which showed `systemd-fsck-root.service`
   was *skipped* because the initramfs-level check had already handled
   it — the actual check happens before systemd/journald starts, so it's
   not visible in `journalctl -b` itself, only its aftermath is).
3. Verified post-reboot: `mount | grep ' / '` → `ext4 (rw,relatime)`, no
   `emergency_ro`; a real write to `/tmp` succeeded;
   `tune2fs -l /dev/xvda2` → `Filesystem state: clean`; `dmesg` showed no
   new I/O errors since boot; all 7 containers (including the two
   previously-unhealthy Postgres ones) came back up automatically, with
   both Postgres containers transitioning through `health: starting` to
   healthy shortly after.

### Long-term Fix
None applied — this was a reactive fix for an already-tripped safety
mechanism, not a guaranteed permanent resolution of the underlying
storage. If the I/O errors recur, the next step is outside this VM
(provider/hypervisor-level storage investigation), not another in-VM
fsck.

## Verification
Post-fix: `mount`, a real write test, `tune2fs -l`, and `dmesg` all
confirmed clean; `docker ps` showed all 7 pre-existing containers back up
(including the two that had been `unhealthy`); Club Zero's own deployment
(SSH key install, code sync, `docker compose up -d --build`, `pytest`
inside the running container — 36 passed) then proceeded successfully on
the same, now-healthy filesystem.

## Prevention
- [x] Fix applied (reboot triggered automatic boot-time fsck)
- [ ] Configuration changes needed — consider a monitoring alert on ext4
      errors/`emergency_ro` for this VM, so this doesn't need to be
      discovered incidentally by an unrelated deployment again
- [ ] Monitoring/alerts to add — see above
- [ ] Documentation to update — none beyond this entry
- [ ] Code changes required — none, infrastructure-only

## Related Issues
- None filed yet.

## References
- Report: `SOFTWARE-ENGINEER/reports/CLUBZERO-2026-09-29-backend-deployed-to-shared-vps.md`

---

**Resolved By:** Claude (Sonnet 5), with the user's explicit authorization to fix the VM and proceed, for tinotendamupezeni@thuthuka.tech.
**Time to Resolution:** Same session, 2026-09-29.
