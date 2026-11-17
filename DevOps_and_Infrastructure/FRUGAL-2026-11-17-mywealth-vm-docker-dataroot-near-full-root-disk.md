# mywealth-vm's Docker data-root sat on a near-full 49GB root disk despite a 1TB disk being attached

**Date:** 2026-11-17
**Project:** FRUGAL
**Environment:** Development/shared (mywealth-vm also runs the unrelated
production `swaposell` stack)
**Severity:** Medium
**Status:** Resolved

## Summary
`mywealth-vm`'s root disk (`/`, 49GB) reached 96% usage during the Wazuh
stand-up, which would have made OpenVAS's stand-up (heavier images, a
large feed sync) impossible without intervention. The VM already had a
separate 1TB disk attached at `/mnt/disk2` (910GB free) that Docker
simply wasn't configured to use — its entire data-root was on the small
root disk by default.

## Symptoms
- `df -h /` showing 96% used, ~2-4GB free, immediately after standing up
  Wazuh's three containers.
- About to start OpenVAS, which needs significantly more than that for
  images plus its NVT/SCAP/CERT feed data.

## Environment Details
- **Server/Host:** `mywealth-vm`
- **Services Affected:** Docker daemon (data-root), indirectly every
  container on the host, including the unrelated production `swaposell`
  stack (frontend/backend/admin/db) sharing the same Docker daemon
- **Related Components:** `/etc/docker/daemon.json`, `/var/lib/docker`,
  `/mnt/disk2`
- **Time First Observed:** 2026-11-17, while preparing to stand up OpenVAS

## Investigation Steps

### 1. Initial Diagnosis
```bash
df -h /          # 49G total, 92-96% used depending on the moment checked
lsblk            # revealed xvdb, a separate 1TB disk mounted at /mnt/disk2, 910GB free
```
The assumption that "disk is full" meant "the VM is nearly out of space"
was wrong — the VM has plenty of space, just not where Docker was
pointed. Caught this before acting further, rather than proceeding to
free space on the wrong disk.

### 2. Root Cause Analysis
`docker info --format '{{.DockerRootDir}}'` confirmed Docker's data-root
was the default `/var/lib/docker`, on the root filesystem, with no
`daemon.json` override pointing elsewhere. The 1TB disk was mounted and
available but never wired into Docker's configuration.

### 3. Key Findings
- This VM also runs an unrelated, pre-existing production stack
  (`swaposell-*`, up 12 days at the time) on the same Docker daemon.
  Moving the data-root meant briefly stopping Docker entirely, which
  would also stop that stack — this was flagged and confirmed with the
  user before proceeding, rather than assumed acceptable because it
  "should" come back via its restart policy.
- Captured a full before/after inventory (containers, images, volumes,
  networks, and each container's restart policy) before touching
  anything, so the migration could be verified against a concrete
  baseline instead of "looks fine."
- Containers with `restart: always`/`unless-stopped` (all of Wazuh's
  three, all four of `swaposell-*`) came back automatically after Docker
  restarted on the new data-root. `frugal-victim` (no restart policy)
  needed a manual `docker start`, and its Wazuh agent daemons (killed
  when the container stopped, not a volume-backed state) needed a manual
  `wazuh-control start` — expected, not a failure, since those daemons'
  PIDs aren't persisted.
- The Wazuh agent's own enrollment (`client.keys`, inside the container's
  writable layer, not a named volume) and the container's two network
  attachments both survived the migration intact, confirmed by checking
  `agent_control -l` on the manager and `docker inspect`'s network list
  afterward rather than assumed.

## Root Cause
Docker's data-root was never configured to use the larger disk that was
already attached to the VM; nothing forced this until a task (Wazuh, then
OpenVAS) finally needed enough space to expose it.

## Prevention / Rule
**Guardrail:** on any host with more than one disk, check
`docker info --format '{{.DockerRootDir}}'` against the actual disk
layout (`lsblk`/`df -h`) before any task that will pull multi-GB images
or sync large feeds — don't infer available space from `df -h /` alone
when other mounted disks exist.

This specifically closes the gap that nearly caused an OpenVAS stand-up
to fail partway through a multi-hour sync from lack of disk space that
was, in fact, available elsewhere on the same host.

## Solution

### Immediate Fix
1. Captured a before-inventory of every container/image/volume/network
   and each container's restart policy.
2. Stopped Docker, `rsync`'d `/var/lib/docker` to `/mnt/disk2/docker`,
   set `data-root` in `/etc/docker/daemon.json`, restarted Docker (user
   ran the privileged steps; no passwordless sudo on this host).
3. Verified every container against the before-inventory; manually
   restarted the one without a restart policy and its in-container
   daemons.
4. Only after full verification, removed the old `/var/lib/docker` to
   actually reclaim the root disk (96% -> 75% used, 12GB free).

### Long-term Fix
None needed beyond the one-time migration; `/mnt/disk2` is now Docker's
permanent data-root on this host.

## Prevention
- [x] Configuration changes needed (`/etc/docker/daemon.json`)
- [ ] Monitoring/alerts to add — worth considering given this host runs
      production services alongside dev/lab work
- [x] Documentation to update (`Frugal/lab/docker-migration/README.md`)
- [ ] Code changes required — none, this was host configuration

## Related Issues
- `DevOps_and_Infrastructure/FRUGAL-2026-11-17-vm-disk-full-and-cert-check-bug.md`
  (same underlying disk-pressure symptom, smaller scope, same day).

## References
- `Frugal/lab/docker-migration/` (migration script + redacted
  before-inventory).

---

**Resolved By:** Claude (Sonnet 5), with tinomupezeni (ran all privileged
steps directly, since this VM has no passwordless sudo configured)
**Time to Resolution:** ~20 minutes
