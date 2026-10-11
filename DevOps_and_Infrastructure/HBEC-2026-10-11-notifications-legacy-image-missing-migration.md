# Legacy notifications-backend crash-loops: running image predates a migration already applied to the shared DB

**Date:** 2026-10-11
**Project:** HBEC Platform
**Environment:** Production (`hbca-vps`)
**Severity:** Medium (no real traffic depended on this container; it had been silently stale for an unknown period)
**Status:** Resolved (container stopped; not fixed forward, since it is superseded)

## Summary
`hbec-notifications-backend` (the retired, `profiles: [legacy]` singleton,
`image: ...:${TAG:-latest}`) crash-looped on every restart with
`alembic.util.messaging: Can't locate revision identified by '0007'`. The
database was already stamped at Alembic revision `0007`
(`0007_draft_reply_email_status.py`), but the image currently resolved by
`.env`'s `TAG=prod-promote-6a151782` only ships migrations `0001`-`0006`. A
newer image was deployed and ran against the shared DB at some point, then
whatever process stamped `TAG` back down to `prod-promote-6a151782` did so
without anyone noticing this container was now behind its own database.

This had zero live impact until today: this container doesn't run its
entrypoint migration step unless it (re)starts, and it hadn't restarted since
whenever the drift was introduced — it just kept serving on stale code
silently. It only crash-looped once an unrelated planned migration
(`reports/HBEC-2026-10-11-docker-containerd-dataroot-migration.md`) forced a
full `docker`/`containerd` daemon restart, recreating every container's
startup path at once.

## Symptoms
- `hbec-notifications-backend` status `Restarting (255)`, loop interval a few
  seconds.
- Log: `ERROR [alembic.util.messaging] Can't locate revision identified by
  '0007'` / `FAILED: Can't locate revision identified by '0007'`, repeating.
- No user-facing impact found: this container is not referenced anywhere in
  the live Caddyfile, and the real traffic-serving pair
  (`notifications-green` + `notifications-worker`/`notifications-beat`, both
  on `TAG_ACTIVE`) was unaffected by this specific fault (they hit a
  different, unrelated Redis fault in the same window — see
  `HBEC-2026-10-06-notifications-worker-redis-readonly-replica.md`).

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** `hbec-notifications-backend` only (legacy singleton)
- **Related Components:** `.env`'s `TAG` variable, `main-pgbouncer` ->
  `hbec_notifications` database, Alembic
- **Time First Observed:** 2026-10-11, during recovery from the planned
  data-root migration outage

## Investigation Steps

### 1. Initial Diagnosis
`docker logs hbec-notifications-backend --tail 50` showed the same two-line
Alembic failure repeating in a tight restart loop.

### 2. Root Cause Analysis
```bash
docker exec hbec-postgres psql -U hbec -d hbec_notifications -c "SELECT * FROM alembic_version;"
# version_num: 0007

docker run --rm --entrypoint sh ghcr.io/rest-creator/hbec-notifications-backend:prod-promote-6a151782 \
  -c "ls /app/alembic/versions/"
# 0001 .. 0006 only — no 0007 file in this image
```
Checked the two newer images already cached locally
(`sha-0dce184`, `sha-b374c3a` — both from this session's recent commits) and
both contain `0007_draft_reply_email_status.py`, confirming the DB was
migrated by one of those (or an equivalent build) at some point, and `TAG`
in `/opt/hbec/.env` was never advanced to match for this service.

### 3. Key Findings
- This is the exact gap CLAUDE.md already names for this service: "A new
  service image must be added to `scripts/deploy/image-tags.sh` *and* the
  production fallback build — notifications was missing from both." This is
  a second, distinct symptom of that same tracking gap — not image-tags.sh
  this time, but the plain legacy `TAG` var never being bumped for this
  particular container while other services' tags moved forward.
- The legacy container is explicitly documented as retired cruft
  ("kept only until the first cutover retires it") — real traffic and the
  Celery worker/beat already run on `TAG_ACTIVE`, which does carry the
  correct, current code.

## Root Cause
`.env`'s single `TAG` variable is shared by every still-present `legacy`
profile service (`student-backend`, `student-frontend`, `admin-backend`,
`admin-frontend`, `harness`, `payments`, `notifications`, `schools-backend`,
`schools-dashboard`). Nothing re-validates that a legacy container's image
still matches the schema version of the database it's pointed at before
restarting it — the entrypoint assumes forward-only migrations and refuses
to start rather than silently reapplying or skipping, which is correct
behavior for Alembic but left this container permanently unable to boot
until an operator intervened.

## Prevention / Rule
**Guardrail:** retire the `legacy` profile services for good once their
first real color cutover has happened, rather than leaving them present
(even if not publicly routed) indefinitely — a container nobody is
maintaining the tag for is a container that will eventually fail to boot
against a database that moved on without it. `check-compose-colors.py`
already flags an unprofiled service; it should also flag (or a separate
script should) a `legacy`-profiled service that has been present for more
than some bake period after its color pair went live, as a prompt to delete
the block.

## Solution

### Immediate Fix
Stopped the container outright rather than repairing it, since nothing
depends on it:
```bash
docker stop hbec-notifications-backend
```
Confirmed the real notifications path (`notifications-green`,
`notifications-worker`, `notifications-beat`) was unaffected by this
specific fault and, once the unrelated Redis override issue was also fixed,
verified healthy via `scripts/deploy/verify-service-links.sh -green`
(`notifications -> student`, `200`).

### Long-term Fix
Remove the `notifications` legacy service block from
`docker-compose.production.yml` entirely in a follow-up commit — it has
already been superseded by `notifications-green`/`-blue` for an unknown
number of days and serves no traffic. Out of scope for this entry to do
unilaterally mid-outage-recovery; flagged as a follow-up.

## Prevention
- [ ] Delete the `notifications` legacy compose block (and audit the other
      `legacy`-profiled services for the same "already fully superseded,
      never removed" state)
- [ ] `check-compose-colors.py` (or a sibling check): flag a long-lived
      `legacy`-profiled service as a removal candidate
- [x] Immediate fix applied (container stopped)
- [ ] Code changes required: none — this is a deployment/retirement gap,
      not an application bug

## Related Issues
- `HBEC-2026-10-06-notifications-worker-redis-readonly-replica.md` — the
  separate, unrelated fault hit by the real (non-legacy) notifications
  containers in the same recovery window
- `reports/HBEC-2026-10-11-docker-containerd-dataroot-migration.md` — the
  planned migration whose forced restart surfaced this

## References
- `docker-compose.production.yml` (`notifications` legacy block, ~line 1774)
- VPS: `/opt/hbec/.env` (`TAG` variable)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** ~10 minutes (diagnosis to decision to stop, during active outage recovery)
