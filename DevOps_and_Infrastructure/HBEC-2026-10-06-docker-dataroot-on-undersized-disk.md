# Docker data-root lives on the small disk; a 4x-larger disk sits 97% empty

**Date:** 2026-10-06
**Project:** HBEC
**Environment:** Production (`hbca-vps`)
**Severity:** Medium (not yet an outage — root cause of a prior 99%-full incident, and will recur)
**Status:** Workaround Applied (root cause not yet fixed — needs a scheduled window)

## Summary
The VPS has two disks: primary `/dev/sda3` (219GB) and secondary `/dev/sdb1`
(931.5GB, mounted `/sdb-disk`). Docker's data-root (`/var/lib/docker` —
images, containers, volumes, build cache) has always lived on the primary
disk; there is no `daemon.json` override pointing it at the secondary one.
As of this session the primary disk sits at 76% used (159G/219G) while the
secondary disk sits at 3% used (20G/916G). This is what caused an earlier
"disk 99% full, `No space left on device` mid-build" incident this session,
and will recur as more sha-tagged image generations and blue/green pairs
accumulate, since the thing actually consuming the space (Docker) is pinned
to the smaller disk by default, not by any deliberate sizing decision.

## Symptoms
- A deploy round this session failed mid-build (`harness-ml`) with
  `No space left on device` at 99% primary-disk usage.
- User independently questioned an offhand "disk at 73%" status update,
  correctly suspecting a larger, underused disk existed that Docker should
  be using instead — this was verified, not assumed, and confirmed exactly
  right (see Investigation Steps below).

## Environment Details
- **Server/Host:** `hbca-vps`
- **Services Affected:** none directly yet — this is a capacity/configuration
  risk, not an active outage. It already caused one build failure (see
  Symptoms) and will cause another once accumulated image/build-cache growth
  crosses 100% again.
- **Related Components:** Docker daemon data-root (`/var/lib/docker`),
  `/dev/sda3` (primary), `/dev/sdb1` mounted `/sdb-disk` (secondary)
- **Time First Observed:** 2026-10-06 (disk-full incident); root cause
  (data-root/disk mismatch) confirmed same day following the user's question

## Investigation Steps

### 1. Initial Diagnosis
The disk-full incident was fixed in the moment with
`docker builder prune -af && docker image prune -af` (207G -> 108G used),
which restored headroom but didn't address why the primary disk is the one
filling up in the first place.

### 2. Root Cause Analysis
```bash
df -h / /sdb-disk
# /dev/sda3  219G  159G   52G  76% /
# /dev/sdb1  916G   20G  851G   3% /sdb-disk

docker info --format '{{.DockerRootDir}}'
# /var/lib/docker  — on /dev/sda3, confirmed no daemon.json data-root override
```

### 3. Key Findings
- The 219GB primary disk is shared by the OS, Docker's entire data-root, and
  everything the manual deploy process builds (10 service images x 2 colors,
  plus every retained `sha-*` generation).
- The 931.5GB secondary disk holds only the already-isolated blue-green dry
  run work (`/sdb-disk/hbec-bluegreen/`) and a 16GB retired-staging backup
  (`/sdb-disk/HBEC.retired-20261001`) — ~20GB total, 3% of its capacity.
- Moving Docker's data-root to the secondary disk requires **stopping the
  Docker daemon** (a full outage of every service on this host — prod,
  staging if still present, the blue-green dry run) for the duration of the
  move. Not something to do inside a routine deploy session.

## Root Cause
Docker's data-root was never explicitly placed; it defaulted to whichever
disk the OS root filesystem is on. Nobody deliberately chose that — it was
simply never revisited once a second, much larger disk was added to the
host.

## Prevention / Rule
**Guardrail:** none implemented yet — this requires a planned maintenance
window, not a code or config guardrail by itself. The actual fix (move
`/var/lib/docker` via a `daemon.json` `data-root` override, during a declared
outage window) is documented as a runbook in HBEC's own repo per this
project's convention for planning artifacts: see
`HBEC/docs/DOCKER_DATAROOT_MIGRATION.md`. Once executed, the guardrail going
forward is simply that the data-root lives on the disk sized for it; add a
disk-usage alert (Prometheus/Grafana, already present on this host for other
metrics) on whichever disk ends up hosting it, so this is caught well before
99% next time, on either disk.

## Solution

### Immediate Fix
`docker builder prune -af` + `docker image prune -af` during this session's
disk-full incident — a stopgap that bought headroom, not a fix for where
the data-root lives.

### Long-term Fix
Deferred, by design — moving `/var/lib/docker` means stopping the Docker
daemon host-wide. Planned as its own maintenance window; see
`HBEC/docs/DOCKER_DATAROOT_MIGRATION.md` in the HBEC repo for the actual
runbook (pre-flight, the move itself, verification, rollback). Not executed
this session — explicitly deferred pending the user's decision on timing,
per this project's "ask before taking a hard-to-reverse, host-wide action"
discipline.

## Prevention
- [ ] Execute the migration runbook (`HBEC/docs/DOCKER_DATAROOT_MIGRATION.md`)
      during a scheduled window
- [ ] Add a disk-usage alert for whichever disk ends up hosting the data-root
- [ ] Confirm whether `/sdb-disk/HBEC.retired-20261001` (16GB) is still needed
      or can be cleared — raised to the user, not yet answered

## Related Issues
- The disk-full incident this same session (`docker builder prune`/
  `image prune` stopgap) is the direct symptom of this root cause.

## References
- `HBEC/docs/DOCKER_DATAROOT_MIGRATION.md` (the migration runbook —
  HBEC's own repo, per this repo's rule that project-specific planning
  artifacts belong there, not here)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Root cause confirmed same session; actual fix
deferred to a scheduled maintenance window.
