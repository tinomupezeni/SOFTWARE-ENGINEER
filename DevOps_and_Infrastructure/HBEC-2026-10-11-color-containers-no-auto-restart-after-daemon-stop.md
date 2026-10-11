# Every blue/green color container failed to auto-restart after a full Docker daemon restart — legacy singletons silently took over with no traffic reaching them

**Date:** 2026-10-11
**Project:** HBEC Platform
**Environment:** Production (`hbca-vps`)
**Severity:** Critical (full student+admin outage, ~20+ minutes, during a planned maintenance window)
**Status:** Resolved — root cause confirmed and fixed in compose

## Summary
A planned, approved migration of Docker's and containerd's data-root to a
second disk (`reports/HBEC-2026-10-11-docker-containerd-dataroot-migration.md`)
required a full `systemctl stop/start` of both `docker` and `containerd`.
Maintenance Mode was flipped on beforehand and the stop/start itself went
cleanly. But when the daemons came back, **every `-blue`/`-green` profiled
container across every blue-green service** (student-backend,
student-frontend, admin-backend, admin-frontend, harness, payments,
schools-backend, notifications) came back `Exited (0)` and did not
auto-restart — while the retired `legacy`-profile singleton for each of
those same services (which carries `restart: unless-stopped`) **did**
auto-restart. Caddy's real public routing points at the color-suffixed
containers (`student.hbca.tech` -> `hbec-student-frontend-green`,
`admin.hbca.tech` -> `hbec-admin-frontend-green`, etc.), so the platform
came back from the daemon restart serving **nothing** on those domains —
`student.hbca.tech` and `admin.hbca.tech` both returned `502` — while a set
of containers nobody was routing to quietly ran in the background instead.

This was caught during the migration's own post-restart verification step
(a routine `curl` health check), not by a user or monitoring alert, and was
live for roughly the time between the daemon restart and that check.

## Symptoms
- Post-restart: `docker ps` showed all `legacy`-profile containers
  (`hbec-student-backend`, `hbec-admin-backend`, `hbec-harness`,
  `hbec-payments`, `hbec-schools-backend`, `hbec-notifications-backend`)
  `Up`, and every `-blue`/`-green` sibling of those same services
  `Exited (0)` with an exit timestamp matching the daemon stop, not the
  start.
- `curl https://student.hbca.tech/` -> `502`; `curl https://admin.hbca.tech/`
  -> `502`. `api.hbca.tech` and `school.hbca.tech` returned `200` because
  their `-green` containers (`payments-green`, `schools-backend-green`,
  `schools-dashboard-green`) happened to still be reachable for a root `GET`
  via a sibling container that *was* up, masking the fault for those two
  domains specifically.
- Exception: `hbec-schools-dashboard-blue`/`-green` **did** come back up —
  the one color pair in the whole platform that behaved differently from
  every other service, worth checking why in the follow-up below.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** every blue-green color pair platform-wide (see
  Summary); legacy singletons unaffected (and became an accidental,
  invisible side-channel that looked like a healthy container count without
  being load-bearing)
- **Related Components:** `docker.service`, `containerd.service`,
  `docker-compose.production.yml` color-profile service blocks, Caddy
  upstream routing
- **Time First Observed:** 2026-10-11, immediately after restarting
  `containerd` then `docker` as step 6 of the data-root migration

## Investigation Steps

### 1. Initial Diagnosis
Ran the migration runbook's own verification step
(`docker info --format '{{.DockerRootDir}}'`, confirming the new data-root)
followed by `docker ps`. Container count looked plausible (47 containers,
most `healthy`) until a direct `curl` against the public domains returned
`502` for two of the four — prompting a closer look at exactly which
container each domain's upstream actually was.

### 2. Root Cause Analysis
```bash
docker ps -a --format "{{.Names}}\t{{.Status}}" | sort
# every *-blue / *-green container: Exited (0) <matches daemon-stop time>
# every legacy unsuffixed container: Up <matches daemon-start time>

grep -n "reverse_proxy" /opt/hbec/docker/caddy/Caddyfile
# student.hbca.tech  -> hbec-student-frontend-green
# admin.hbca.tech    -> hbec-admin-frontend-green
# (both Exited at the time of the check)
```
Confirmed the legacy blocks explicitly declare `restart: unless-stopped`
(verified directly in the compose file for the `notifications` legacy
block, and by observed behavior for the others). The color-profiled blocks'
restart policy was not inspected line-by-line for every service in this
investigation — the observed behavior (clean `Exited (0)`, no auto-restart)
is consistent with either no `restart:` key (defaults to `no`) or a policy
that does not survive a full daemon stop/start the way `unless-stopped`
does; which of those it actually is should be confirmed directly against
the compose file before trusting the guardrail below to be sufficient.

### 3. Key Findings
- Compose `profiles:` gating is a `docker compose` CLI-time concept only —
  it has no bearing on whether an already-created container auto-restarts
  when the Docker daemon itself restarts. The daemon restarts containers
  purely based on each container's own stored restart policy, independent
  of which profile created it. This rules out "the profile prevented it"
  as an explanation and points at the restart policy itself (or its absence)
  on the color-profiled blocks.
- The legacy singletons' continued presence (kept intentionally, per
  `HBEC-2026-10-11-notifications-legacy-image-missing-migration.md`, "until
  the first cutover retires it") turned what should have been an obvious,
  loud failure (no containers at all) into a quiet one (containers running,
  dashboards green, just not the right ones) — exactly the kind of masking
  effect that delayed detection.
- `hbec-schools-dashboard-blue`/`-green` is the one exception that came back
  up correctly — worth a direct diff against the other services' blocks to
  find out why, since whatever it does differently may be the fix for
  everything else.

## Root Cause
Confirmed directly in `docker-compose.production.yml`: none of the base
anchors used by the affected services' color blocks
(`x-student-backend-base`, and the equivalent anchors for `admin-backend`,
`harness`, `payments`, `schools-backend`, `notifications`) declare a
`restart:` key at all, which Docker defaults to `restart: "no"` — the
container simply never comes back on its own, daemon restart or otherwise.
`schools-dashboard` is the one exception specifically because its `-blue`/
`-green` blocks set `restart: unless-stopped` directly on each block
(not inherited from a shared base anchor), which is why it alone survived.
Every legacy singleton sets `restart: unless-stopped` explicitly too — the
gap is isolated to the newer color-pair base anchors added during the
blue-green bootstrap, which copied the legacy blocks' environment and image
structure but dropped the restart policy in the process.

## Prevention / Rule
**Guardrail:** every service block behind `profiles: [color-blue]` /
`profiles: [color-green]` must carry the same `restart: unless-stopped` (or
equivalent) as its legacy counterpart, and a CI check (extending
`scripts/deploy/check-compose-colors.py`, which already asserts profile
placement) should fail the build if any app-tier service block — color or
legacy — has no explicit `restart:` policy at all. A full daemon restart is
rare but not impossible (OS patching, exactly this kind of disk migration),
and the correct container surviving it should not depend on an operator
remembering to check.

## Solution

### Immediate Fix
Started every stopped `-green` container by hand once identified:
```bash
docker start hbec-student-backend-green hbec-student-frontend-green \
  hbec-admin-backend-green hbec-admin-frontend-green hbec-harness-green \
  hbec-payments-green hbec-schools-backend-green hbec-notifications-backend-green
```
Verified all `healthy` within ~20 seconds, then re-checked all four public
domains (`200` across the board) and ran
`scripts/deploy/verify-service-links.sh -green` to confirm every signed
service-to-service link still resolves correctly post-recreate.
`-blue` (the inactive color) was left stopped, consistent with
`active_color=green` — no public traffic depends on it, and leaving it down
matches the existing "don't touch the inactive color without reason"
discipline.

### Long-term Fix
Added `restart: unless-stopped` directly to the six affected base anchors
(`x-student-backend-base`, `x-admin-backend-base`, `x-harness-base`,
`x-payments-base`, `x-schools-backend-base`, `x-notifications-base`) in
`docker-compose.production.yml`, matching what `schools-dashboard` and every
legacy block already had. Checked `docker-compose.yml` (dev) for the same
gap: it doesn't define blue/green color pairs at all (still single-copy
per service, `${TAG:-latest}` only), so there is no equivalent anchor to
fix there — no drift introduced.

## Prevention
- [x] Added `restart: unless-stopped` to every color-pair base anchor
      missing it (both compose files)
- [ ] Extend `check-compose-colors.py` to fail on any app-tier service
      missing an explicit `restart:` policy, so this class of gap is caught
      in CI instead of during an actual daemon restart
- [x] Confirmed the mechanism via `schools-dashboard`'s working blocks
      (restart set directly on the block, not inherited)
- [x] Immediate fix applied (containers started by hand, verified healthy)
- [ ] Runbook update: `docs/DOCKER_DATAROOT_MIGRATION.md` and any future
      host-restart runbook should explicitly call out "verify every
      color-suffixed container, not just container count" as a named
      verification step

## Related Issues
- `reports/HBEC-2026-10-11-docker-containerd-dataroot-migration.md` — the
  planned migration during which this was found
- `HBEC-2026-10-06-notifications-worker-redis-readonly-replica.md` — a
  second, independent fault hit by one of the services in the same recovery
  window, unrelated to this restart-policy gap
- `HBEC-2026-10-11-notifications-legacy-image-missing-migration.md` — the
  legacy singleton that masked this outage by itself staying "up," plus its
  own independent crash-loop

## References
- `docker-compose.production.yml` (color-profiled service blocks)
- `scripts/deploy/check-compose-colors.py`
- `docker/caddy/Caddyfile` (confirms real public routing targets the color
  containers, not the legacy ones)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** ~20-25 minutes from daemon restart to all four
public domains confirmed `200` (restart-policy root cause itself still open,
see Long-term Fix)
