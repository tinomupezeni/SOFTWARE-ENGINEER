# Blue-Green Phase 0: Multi-Service Dry-Run (Student + Admin Backend)

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Architecture Decision Validation
**Status:** Completed

## Summary
Extended the isolated blue-green dry run from a single service pair
(student-backend) to two services (student-backend + admin-backend)
sharing one Postgres instance, to exercise what a single-pair dry run
structurally cannot: same-color peer-URL pinning across services, a
multi-domain Caddy cutover moving more than one upstream atomically in one
event, and a coordinated migration touching two services' separate
databases at once. All three proved out. This is Phase 0 of the
full-platform real-cutover plan — still fully isolated, still zero contact
with real production, with Phases 1–4 (the real compose/Caddy/CD rework,
each requiring its own separate approval) deliberately not started.

## Context / Trigger
After the dry-run's single-pair mechanics (shared-DB coexistence,
expand/contract migrations, real secrets, a genuinely differing code
version) were fully proven, the user asked to plan the real cutover and —
given the CD/Caddy rework needed has no existing single-service
shortcut — chose to design the entire platform (~15 services) at once
rather than pilot with just Student Backend. Research into the real
infrastructure (Caddy routing, both compose files, the CD pipeline) found
no existing atomic-switch mechanism anywhere and tooling built entirely
around two fixed, differently-named slots rather than an arbitrary color
pair — a genuinely new architecture, not a generalization of something
already half-built. The resulting plan scoped its concretely-approved work
to Phase 0 only: proving the multi-service mechanics in the same isolated,
disposable sandbox Phase 1 already validated for one service, before any
real routing or CD tooling is touched.

## Scope
**Included**: adding `admin-backend-blue`/`admin-backend-green` to the
existing dry-run compose file, same-color-pinning admin's
`STUDENT_SERVICE_URL` to the matching student-backend color, extending the
dry-run Caddy config to a second domain, extending `cutover.sh` to flip
both domains in one reload, and a coordinated migration test touching both
services' databases.

**Explicitly excluded**: anything from Phases 1–4 of the full-platform
plan (real compose/Caddy/CD changes, public DNS, the resource-capacity and
maintenance-window decisions that gate Phase 1). Harness, payments,
schools, and notifications were not added to this dry run — admin and
student were sufficient to exercise cross-service pinning and multi-domain
cutover, which don't need a third service to prove.

## Method
1. Read `docker-compose.production.yml`'s real `admin-backend` block to
   copy its actual env var shape (`STUDENT_SERVICE_URL`,
   `REPLICATION_HMAC_KEY`, `PAYMENTS_INTERNAL_SECRET`, etc.) rather than
   inventing one — the same discipline used for student-backend's own
   dry-run config originally.
2. Recognized that `REPLICATION_HMAC_KEY` and `PAYMENTS_INTERNAL_SECRET`
   are **shared** signing secrets between admin and student — giving
   admin-backend a separately-generated "fresh" value for these would make
   admin↔student signed calls fail verification regardless of which value
   was "more real." Reused the same real values already fetched into this
   dry run for student-backend in the prior step; every other admin secret
   (`ADMIN_SECRET_KEY`, `MODEL_SETTINGS_ENCRYPTION_KEY`,
   `SCHOOLS_ADMIN_SECRET`) got a fresh dry-run-only value, since nothing
   else in this dry run needs to agree with them.
3. Verified same-color pinning wasn't just a correct env var, but a real
   effect: a genuine HTTP call from inside `admin-backend-blue` to
   `student-backend-blue`'s health endpoint succeeded, and the matching
   green↔green call succeeded independently — confirmed via each target
   container's own access log showing the hit, not just a 200 status.
4. Extended the Caddy dry run to a second domain/port and a single `sed` +
   `caddy reload` that rewrites both upstreams together — verified the
   "atomic, all-or-nothing, whole-platform event" property the full-
   platform plan's design relies on actually holds when there's more than
   one domain, not just asserted it would.
5. Ran one additive migration against each service's database
   **concurrently** (backgrounded shell jobs, `wait`), simulating one
   coordinated deploy event touching two services at once, then verified:
   the correct column landed on each service's correct table, student's
   database was untouched by admin's migration (and vice versa — they are
   separate logical databases sharing one Postgres instance), and blue
   (both services, unmodified) stayed completely healthy throughout.
6. Reverted both migrations, removed the injected files, confirmed clean
   schema on both databases.
7. Re-ran the same zero-impact checks on real production as every prior
   step in this series.

## Decisions & Findings

### Shared secrets must stay shared, even across a "fresh dry-run value" default
The instinct to give every new service in a dry run a fresh, isolated
secret is right for secrets nothing else needs to agree with, but wrong
for secrets two services use to verify *each other's* requests. Getting
this wrong wouldn't have failed loudly in an obvious way — it would have
made admin↔student signed calls fail signature verification, a
confusing-to-debug symptom if it had been discovered later rather than
reasoned through up front.

### Same-color pinning is a configuration property, not a network-isolation one
Docker's embedded DNS resolves every container name for every container on
a shared network regardless of "which color" is asking — `admin-backend-
blue` can resolve `student-backend-green` just fine at the network level.
The actual pinning lives entirely in which URL each color's *application
config* is given (`STUDENT_SERVICE_URL`), not in anything preventing
cross-color reachability. Verifying this needed a real HTTP call checked
against the target's access log, not a DNS-resolution check, which would
have reported a false "problem" (both colors are always mutually
reachable) while missing the actual thing under test.

### A coordinated two-service migration event has no special failure mode beyond each service's own
Running both services' migrations at the same moment, against the same
underlying Postgres instance, produced no cross-service interaction
effects — they're separate logical databases, Django's own
`django_migrations` bookkeeping is per-database, and nothing in Postgres
couples unrelated databases' DDL operations against each other. This is a
useful negative result for the full-platform plan: "deploy several
services at once" doesn't introduce a new class of migration risk beyond
"each service's own migrations must individually be expand-safe," already
established.

### Caddy's one-reload-many-domains property holds, not just plausible
The full-platform design (from this session's research/design work)
depends on a single `caddy reload` being atomic across every public domain
at once. This phase is the first time that was actually exercised with
more than one domain in the dry run, and it held: both `:8080` (student)
and `:8090` (admin, moved off `:8081` after discovering an unrelated
pre-existing container already using that port — see below) flipped
together on every cutover, in both directions.

## Changes Made
On the VPS only, inside the existing disposable dry-run directory
(`/sdb-disk/hbec-bluegreen/`) — no changes to the HBEC repository:
- `docker-compose.bluegreen.yml`: added `admin-backend-blue`/
  `admin-backend-green` service blocks, an `&admin_env` anchor mirroring
  the real `admin-backend` env shape, and a second published port
  (`127.0.0.1:8090`) on `caddy-dryrun`.
- `.env.bluegreen`: gained 3 new lines (fresh dry-run-only admin secrets).
- `docker/caddy-dryrun/Caddyfile`: gained a second site block (`:8090` →
  `admin-backend-<color>`).
- `cutover.sh`: extended to rewrite both domains' upstreams in the same
  `sed` pass before the single `caddy reload`.
- Two throwaway migration files existed only inside the green containers'
  filesystems for the duration of the test, applied and reverted against
  the isolated databases, then deleted.

## Verification
- `admin-backend-blue`/`-green` both reported `healthy`.
- A real HTTP call from `admin-backend-blue` to `student-backend-blue`
  (and the matching green↔green call) succeeded, confirmed via each
  target's own access log.
- Multi-domain cutover flipped both `:8080` and `:8090` together, in both
  directions (blue→green→blue), confirmed via `X-Deploy-Color` on each.
- Coordinated migration: correct column landed on `admin_users` (admin's
  real table name — note, not the Django app-label-derived default, a
  detail worth getting right rather than assumed) and `accounts_user`
  (student); each database confirmed free of the other's column; both
  blue containers stayed healthy and unmodified throughout; both reverted
  cleanly afterward.
- Zero impact on real production: `hbec-student-backend`/
  `hbec-admin-backend`/`hbec-postgres` container start timestamps
  unchanged, primary disk usage unchanged (152G/73%),
  `https://student.hbca.tech/` and `https://admin.hbca.tech/` both
  returned `HTTP/2 200`.

## Follow-ups / Deferred
- **Port collision found and avoided, not fixed at the source**: a
  pre-existing, unrelated container (`prod-test-proxy`) already holds
  `8081`–`8082` on the VPS. Not part of this work and not touched — picked
  `8090` instead. Worth someone eventually confirming what
  `prod-test-proxy` is and whether it's still needed, since its name
  suggests it may itself be stale, but that's out of scope for this dry
  run to investigate or touch.
- Phases 1–4 of the full-platform plan remain exactly as previously
  scoped, each gated on its own future approval: the real compose/Caddy/CD
  rework (Phase 1, needs a scheduled maintenance window), shadow-verifying
  against real infra without cutting over (Phase 2), the first real
  cutover as a rehearsed event (Phase 3), and retiring the old tooling
  only after several clean cycles (Phase 4). The resource-capacity and
  maintenance-window open decisions named in the plan still need answers
  before Phase 1 can be scheduled.

## References
- [`HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md`](HBEC-2026-10-01-blue-green-phase1-isolated-dry-run.md)
- [`HBEC-2026-10-01-blue-green-expand-contract-migration-test.md`](HBEC-2026-10-01-blue-green-expand-contract-migration-test.md)
- [`HBEC-2026-10-01-blue-green-differing-code-version-cutover.md`](HBEC-2026-10-01-blue-green-differing-code-version-cutover.md)
- [`HBEC-2026-10-01-blue-green-phase2-step1-real-secrets.md`](HBEC-2026-10-01-blue-green-phase2-step1-real-secrets.md)

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session (2026-10-01), continuing directly from the full-platform cutover plan's approval.
