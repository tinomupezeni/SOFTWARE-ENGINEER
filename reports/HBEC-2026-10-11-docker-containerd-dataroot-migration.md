# Docker + containerd data-root migration to the secondary disk

**Date:** 2026-10-11
**Project:** HBEC Platform
**Type:** Infrastructure migration
**Status:** Completed

## Summary
Moved both Docker's (`/var/lib/docker`) and containerd's
(`/var/lib/containerd`) storage roots on `hbca-vps` from the primary,
near-full disk (`/dev/sda3`, 219GB) to the mostly-empty secondary disk
(`/dev/sdb1`, 916GB, mounted `/sdb-disk`), per the plan in
`docs/DOCKER_DATAROOT_MIGRATION.md`. Executed during an explicitly
pre-arranged maintenance window. The migration itself succeeded cleanly;
the forced full daemon restart it required surfaced two independent,
previously-latent production bugs that turned what should have been a
clean restore into a ~20-25 minute additional outage on top of the planned
one. Both are fixed and logged separately (see References).

## Context / Trigger
The primary disk was at 79% used, driven almost entirely by
`/var/lib/containerd` (130GB of unpacked image layers and blobs — Docker
20.10+ delegates image/container storage to containerd by default, so most
of what looks like "Docker's disk usage" actually lives there, not under
`/var/lib/docker`, which was only 11GB). This had already caused one
mid-deploy `No space left on device` failure earlier in the week. The user
confirmed the team was in an active, pre-arranged maintenance window and
asked to plan and then execute the migration.

A cheaper alternative was considered and explicitly discussed first: pull
`master` and rebuild every blue-green image set from source instead of
physically moving data. Rejected because it doesn't avoid the outage itself
(changing `data-root`/`root` still requires stopping both daemons) and a
10-image rebuild had taken 20-40+ minutes elsewhere this session with no
fallback if a build failed, versus a disk-to-disk copy that produces an
exact, already-proven-working replica.

## Scope
**Included:** both `/var/lib/docker` and `/var/lib/containerd` (the original
version of the plan only covered the former, which would have freed 11GB
and left 92% of the real problem untouched — corrected before execution).
Build-cache pruning first (`docker builder prune -f`, 58.84GB reclaimed,
zero downtime) to shrink the data actually needing to move. Maintenance
Mode toggling around the outage window. Post-restart verification of every
public domain and every signed service-to-service link.

**Excluded:** the `savanna-learning-main-hbca` image (confirmed by the user
to be the unrelated real HBCA public website — left untouched). The
leftover `bg-*` blue-green dry-run stack (flagged during investigation, not
acted on — separate decision). `/sdb-disk/HBEC.retired-20261001` (still
unresolved from an earlier session, not touched). Deleting the old
`/var/lib/docker`/`/var/lib/containerd` contents on the primary disk — kept
as a rollback safety net for a bake period, per this project's standing
"don't decommission the old thing until the new thing has baked" discipline.

## Method
1. Pruned disposable build cache first (safe, zero-downtime) before
   touching anything that required an outage, to shrink the actual data
   volume and re-measure real sizes rather than trusting stale numbers.
2. Flipped Maintenance Mode on via the admin API (confirmed enforcing with
   a live `curl` showing `503 {"maintenance": true, ...}`), understanding
   up front — and documenting in the runbook — that it does **not** cover
   the daemon-stop window itself, since Caddy and the student backend are
   themselves Docker containers and go down with everything else.
3. Stopped `docker`/`docker.socket` then `containerd` (dependency order),
   confirmed both `inactive`.
4. `rsync -aHAX` each directory to its new home on `/sdb-disk`, run in the
   background and watched to completion via a polling monitor rather than
   blocking foreground calls.
5. Pointed both daemons at the new roots (`/etc/docker/daemon.json`
   `data-root`; `/etc/containerd/config.toml` `root`, leaving `state` on
   its ephemeral default) and started `containerd` then `docker` (reverse
   of the stop order).
6. Verified the new root via `docker info`, confirmed the *old* containerd
   directory stopped growing (proof the daemon is reading the new location,
   not silently recreating data at the old default).
7. Checked which containers came back, found the two faults described
   below, fixed both, then ran the full verification suite before declaring
   done.

## Decisions & Findings

### The migration mechanics themselves were clean
Both `rsync` passes completed with matching sizes (`containerd-data`: 89GB
source and destination exactly; `docker-data`: 11GB source vs 13G
destination, consistent with normal drift during a live copy — not
re-verified byte-for-byte beyond size, which is a reasonable gap for a
non-corruption-sensitive, rollback-able move but worth noting). Both
daemons started cleanly on the new roots on the first attempt; no rollback
was needed.

### Finding 1: every blue-green color container failed to auto-restart
Full write-up: `DevOps_and_Infrastructure/HBEC-2026-10-11-color-containers-no-auto-restart-after-daemon-stop.md`.
In short: the base anchors for six blue-green services
(`student-backend`, `admin-backend`, `harness`, `payments`,
`schools-backend`, `notifications`) carried no `restart:` policy at all,
defaulting to `no`. A full daemon restart left every `-blue`/`-green`
container `Exited (0)` while the retired `legacy`-profile singletons (which
do set `restart: unless-stopped`) came back and ran — serving no real
traffic, since Caddy's real public routing targets the color-suffixed
containers exclusively. `student.hbca.tech` and `admin.hbca.tech` 502'd
until this was caught by the runbook's own post-restart health check and
fixed by starting the correct containers by hand. Root-caused to the exact
missing compose key by diffing against `schools-dashboard`, the one service
whose blocks set the policy directly and survived unaffected. Fixed in
compose for all six services (commit `adcd9cc0`), closing the gap for any
future daemon restart, not just this one.

### Finding 2: two independent, unrelated notifications faults in the same window
Full write-ups:
`DevOps_and_Infrastructure/HBEC-2026-10-06-notifications-worker-redis-readonly-replica.md`
(updated) and
`DevOps_and_Infrastructure/HBEC-2026-10-11-notifications-legacy-image-missing-migration.md`
(new).

- A five-day-old Redis-failover bandage (`docker/redis-failover-20261006.override.yml`)
  was still hardcoding `REDIS_URL=redis://redis-replica:6379/3` for four
  notifications containers, even though the real master had been back on
  `redis` (the original node) the whole time — Sentinel's own log shows the
  2026-10-06 failover attempt never actually completed. This had zero
  effect for five days because none of the four containers had been
  recreated since the override was applied; the forced daemon restart
  recreated their startup path and the Celery worker's lock-acquire write
  immediately failed with `ReadOnlyError`. Fixed by recreating the three
  real (non-legacy) notifications containers without the stale override.
- Separately, the retired legacy `hbec-notifications-backend` container
  crash-looped on `Can't locate revision identified by '0007'` — its
  pinned image (`TAG=prod-promote-6a151782`) only ships Alembic migrations
  through `0006`, but the shared database had already been migrated to
  `0007` by a newer build at some point without `.env`'s `TAG` ever being
  advanced for this specific, already-superseded container. No real
  traffic depended on it (not referenced in Caddy, not called by any live
  peer), so it was stopped outright rather than repaired.

Both faults were only discoverable because the data-root migration forced
every container through its startup path at once — a useful, if
unplanned, exercise of code paths that normally only run once at initial
deploy and are never re-exercised afterward.

## Changes Made
- `/etc/docker/daemon.json` created on `hbca-vps`: `{"data-root":
  "/sdb-disk/docker-data"}`.
- `/etc/containerd/config.toml` on `hbca-vps`: `root` uncommented and set to
  `/sdb-disk/containerd-data` (`state` left on its ephemeral default).
- `docker-compose.production.yml` (commit `adcd9cc0`): added `restart:
  unless-stopped` to six base anchors missing it.
- VPS-only (not in git): recreated `notifications-green`,
  `notifications-worker`, `notifications-beat` without the stale
  `redis-failover-20261006.override.yml`; stopped the legacy
  `hbec-notifications-backend` container; started all eight `-green`
  containers that had failed to auto-restart.
- `SOFTWARE-ENGINEER/DevOps_and_Infrastructure/HBEC-2026-10-11-color-containers-no-auto-restart-after-daemon-stop.md` (new)
- `SOFTWARE-ENGINEER/DevOps_and_Infrastructure/HBEC-2026-10-11-notifications-legacy-image-missing-migration.md` (new)
- `SOFTWARE-ENGINEER/DevOps_and_Infrastructure/HBEC-2026-10-06-notifications-worker-redis-readonly-replica.md` (updated with the 2026-10-11 recurrence)

## Verification
- `docker info --format '{{.DockerRootDir}}'` reports the new path; the
  *old* `/var/lib/containerd` stopped growing after the daemon switch
  (confirmed static at 89GB across multiple checks), proving containerd is
  reading from the new root rather than silently recreating data at the
  default.
- All four public domains (`student`, `admin`, `api`, `school`) returned
  `200` after both fixes were applied; `student.hbca.tech/api/curriculum/subjects/`
  returned real data (`200`, not the `503` maintenance response) after
  Maintenance Mode was flipped back off.
- `scripts/deploy/verify-service-links.sh -green` passed every signed
  service-to-service link, including `notifications -> student`, the one
  that had just been fixed.
- Disk usage confirmed: primary `/` now 60% used (125G, down from 79%
  before the build-cache prune); `/sdb-disk` holds 101G with 770G free.
- Maintenance Mode confirmed off via the real sync endpoint response
  (`{'success': True, 'enabled': False}`) and the live `200` on the data
  endpoint above.

## Follow-ups / Deferred
- Diff `schools-dashboard`'s restart-policy pattern was already done as
  part of root-causing Finding 1 — no further action needed there.
- Extend `scripts/deploy/check-compose-colors.py` to fail CI on any
  app-tier service block missing an explicit `restart:` policy, so this
  class of gap can't reappear silently (tracked in the Finding 1 entry).
- Remove the superseded `notifications` legacy compose block entirely
  (tracked in the Finding 2b entry) — not done here to avoid touching more
  than necessary mid-recovery.
- Retire `docker/redis-failover-20261006.override.yml` once notifications
  gets a durable Sentinel-aware client/broker (tracked in the updated
  Finding 2a entry) — the override has now caused a production fault in
  both directions (forward and reverse failover) and has no expiry
  mechanism of its own.
- Delete the old `/var/lib/docker`/`/var/lib/containerd` contents on the
  primary disk after the proposed ≥24h bake period — not done yet,
  deliberately, per the runbook.
- The leftover `bg-*` blue-green dry-run stack (still running, found during
  this same investigation) and `/sdb-disk/HBEC.retired-20261001` remain
  open, smaller decisions from earlier sessions — not acted on here.

## References
- `docs/DOCKER_DATAROOT_MIGRATION.md` — the executed runbook
- `DevOps_and_Infrastructure/HBEC-2026-10-11-color-containers-no-auto-restart-after-daemon-stop.md`
- `DevOps_and_Infrastructure/HBEC-2026-10-11-notifications-legacy-image-missing-migration.md`
- `DevOps_and_Infrastructure/HBEC-2026-10-06-notifications-worker-redis-readonly-replica.md`
- Commit `adcd9cc0` (restart-policy fix)

---

**Completed By:** Tinotenda Mupezeni
**Duration:** ~1 hour end to end (prune → migrate → reconfigure → restart →
diagnose and fix two unrelated faults → verify), within one scheduled
maintenance window
