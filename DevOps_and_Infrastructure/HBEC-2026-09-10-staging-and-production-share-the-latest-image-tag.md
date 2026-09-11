# Staging and Production Resolve the Same Image Tag — No Environment Separation

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Staging + Production
**Severity:** High
**Status:** Investigating

## Summary
Found while auditing readiness for a staging→production promotion.
`docker-compose.production.yml` and `docker-compose.staging.yml` both resolve
every app image as `${DOCKER_REGISTRY:-ghcr.io/rest-creator}/hbec-<service>:${TAG:-latest}`,
and both `/opt/hbec/.env` (production) and `/home/winstontino/HBEC/.env.staging`
explicitly set `TAG=latest`. There is no per-environment tag. Both stacks
share the exact same tag pointer on the exact same Docker host.

## Symptoms
No direct incident yet — found proactively. The mechanism: rebuilding an
image on staging immediately moves what `:latest` points to, which is the
same tag production's compose file resolves, on the same host's local image
store.

## Environment Details
- **Server/Host:** hbca-vps (shared by both `/opt/hbec` production and
  `/home/winstontino/HBEC` staging)
- **Services Affected:** every service in both compose files that uses the
  `${TAG:-latest}` pattern (admin-backend, admin-frontend, student-backend,
  student-frontend, harness, harness-ml, payments, schools-backend,
  schools-dashboard)
- **Time First Observed:** 2026-09-10, during a pre-promotion readiness audit

## Investigation Steps

### 1. Initial Diagnosis
`grep -n 'image:' docker-compose.production.yml` showed every app image using
`${TAG:-latest}`; `grep -E '^TAG=' /opt/hbec/.env` and
`/home/winstontino/HBEC/.env.staging` both returned `TAG=latest` explicitly.

### 2. Root Cause Analysis
Confirmed live: after rebuilding `hbec-admin-backend` on staging today,
`docker images ghcr.io/rest-creator/hbec-admin-backend` showed `latest`
pointing at the brand-new staging build, while production's *running*
container was still pinned (by image ID, not tag) to its old August 31
image — safe for now, but only because nothing recreated that container in
the interim.

### 3. Key Findings
- The old production image ID had already fallen out of the tag history
  entirely: 90+ orphaned `sha-XXXXXXX` tags exist for `hbec-admin-backend`
  alone (going back 5+ days), none matching what production is actually
  running. There is no tag anyone could use today to explicitly say "this is
  what production runs" — only the live container's image ID, which
  disappears the moment that container is recreated without a deliberate
  pin.
- Any future container recreate on production that isn't explicitly
  pinned — a host reboot, a stray `docker compose up -d`, an unrelated config
  change that forces a recreate — would silently pull in whatever staging
  built most recently, untested.
- `docker system df` on the same host: 772 images / 91.4GB, only 285 in use,
  37GB reclaimable — the tag sprawl this causes is also a real disk-usage
  problem, not just a correctness one.

## Root Cause
Both environments' compose files and env files were configured with the same
default tag (`latest`) and no environment-scoped override was ever
introduced, so "build on staging" and "what production will run next restart"
became the same action without anyone deciding that on purpose.

## Solution

### Immediate Fix
None yet this session — production was promoted today by explicitly
retagging staging's current, verified-stable images and pointing production
at those specific tags for this one promotion (see the companion "everything
was using sha tag" execution in this session's history), not by leaving
`:latest` to race.

### Long-term Fix
Give production a stable, non-`latest` pointer: after each verified staging
build, tag the resulting image with something durable (a commit sha or a
dated promotion tag) and point `/opt/hbec/.env`'s `TAG` at that value instead
of `latest`. This turns "promote" into an explicit, auditable action (retag +
pin) instead of an implicit side effect of the next staging rebuild.

## Prevention
- [ ] Change `/opt/hbec/.env`'s `TAG` away from `latest` to a pinned value,
      updated only on deliberate promotion
- [ ] Consider the same for staging's own `.env.staging` (`TAG=staging` or a
      per-build sha) so staging itself isn't also silently racing prod for
      the same pointer
- [ ] Prune the orphaned `sha-XXXXXXX` tag backlog (37GB reclaimable) so a
      real "what's currently deployed" answer is easier to find later

## Related Issues
- Found during the same audit that surfaced `.last_good_sha` being stale
  (pointed at an Aug 20 commit while production's actual image was built
  Aug 31 — see companion entry on `/opt/hbec` drift)

## References
- `docker-compose.production.yml`, `docker-compose.staging.yml`
- `/opt/hbec/.env`, `/home/winstontino/HBEC/.env.staging`

---

**Resolved By:** In progress — worked around for this promotion, systemic fix not yet applied
**Time to Resolution:** In progress
