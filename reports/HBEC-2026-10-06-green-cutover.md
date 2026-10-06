# HBEC production cutover to green (sha-e44223f) + what made it rough

**Date:** 2026-10-06
**Project:** HBEC Platform
**Type:** Deployment / Cutover
**Status:** Completed

## Summary
Switched all public traffic (student, admin, payments API, schools) from the uncolored legacy containers to the green color branch (`sha-e44223f`) via Caddy, stepwise with verification per domain, after a full stability sweep showed green healthy and at parity with live. Nothing crash-looping on green; fallback is a one-command Caddyfile restore. The cutover worked, but nothing about the process was smooth — this report is mostly about the seven things that confused it, so the next one is boring.

## Context / Trigger
Green had just been deployed (user's own deploy, ~50 min prior) and a stability sweep (zero restarts, uniform image, clean logs, deep-ready checks) showed it ready. The Redis Sentinel failover earlier in the session had already forced a green-only Redis repoint for notifications, so green was also the only color whose backend could write. User ordered the cutover with ready fallback; Caddy was flipped domain by domain (admin canary first).

## Scope
Included: student, admin, payments API, schools app + API Caddy routes; pre-flip endpoint verification; post-flip public checks; fallback snapshot.
Explicitly excluded: landing page (`hbca.tech` → savanna container), Prometheus/Alertmanager routes, the `bg-*` stack (separate environment, untouched), uncolored + blue containers (left up and warm as the fallback), Qdrant (down for both colors equally — cutover changes nothing there), the shared uncolored worker/beat (already repointed earlier in the session, shared by all colors by design gap).

## Method
Verify-before-flip per domain, in traffic-risk order: snapshot config → prove the green endpoint answers inside the container network → flip one Caddy route → `caddy reload` (zero-downtime) → verify publicly from outside the VPS → next domain. Any failure → restore snapshot + reload (<10s). Backend-chain proof meant exercising a real API path through the green frontend (curriculum subjects returned live data), not just homepage 200s.

## Decisions & Findings
The cutover itself was 7 changed Caddy lines. Everything below is what made it non-smooth:

1. **The color scheme on paper is not the color scheme on the box.** `active_color` says `blue` and the deploy docs describe marker-driven promotion — but Caddy routes to *uncolored legacy* container names, which read no markers. Live was neither blue nor green; both colors were idle staging. Cost: a full discovery loop (markers → compose labels → Caddyfile → frontend env) before the first safe change. Fix: either wire Caddy to the markers or delete the markers; two sources of truth for "what's live" is how the next cutover flips the wrong thing.
2. **Marker contents disagreed with reality.** `.sha_green` read `2804d78` while every green container runs image tag `sha-e44223f`. Markers are currently untrustworthy — actual image digests via `docker inspect` were the only reliable version signal. Same fix as (1), plus: stamp markers from the deploy job, never by hand.
3. **Compose interpolation ritual.** Recreating anything under `/opt/hbec/docker-compose.production.yml` demands `TAG_BLUE/GREEN/ACTIVE` + four `*_ACTIVE` service URLs that `/opt/hbec/.env` does not carry. Values had to be harvested from running containers (`docker inspect` on the live worker for `HARNESS_SERVICE_URL_ACTIVE`, etc.). Fragile, undocumented, and one typo away from pointing a service at the wrong color. Fix: put the ACTIVE set (and TAG set) in `.env` with the rest, or a `.env.cutover` template next to the compose file.
4. **`school-api.hbca.tech` has no public DNS record.** Returned 000 through the whole verification window and burned real investigation time before `nslookup` settled it as pre-existing. Fix: either publish the record or remove the Caddy block so the next verifier doesn't chase it.
5. **No canonical smoke paths.** The payments health check I guessed (`/v1/payments/health`) 404s on *both* colors — resolved by parity comparison, but it shouldn't take analysis to smoke-test a service. Fix: document one smoke URL per public route (the exact list verified this time is in Verification below).
6. **Workers are shared, colors are not.** Green has no worker/beat; notification delivery rides the uncolored pair. "Switch to green" therefore never isolated notifications — and the beat's healthcheck reports healthy while failing 3,420 writes (found earlier this session). Fix: colored workers/beats per the deploy docs' `TAG_ACTIVE` pattern, and a beat probe that publishes.
7. **Side effect in our favor, worth naming:** the uncolored and blue notification backends still point at the dead Redis master, so their write paths are broken. Green (repointed this session) is currently the *only* color that can write notifications — the cutover didn't just move traffic, it restored a broken write path for the admin surface.

## Changes Made
- `/opt/hbec/docker/caddy/Caddyfile`: 7 `reverse_proxy` lines `hbec-<svc>` → `hbec-<svc>-green` (student/admin frontends, payments, schools backend ×2, schools dashboard). Snapshot at `Caddyfile.pre-green-20261006`. Landing, monitoring untouched.
- Reloads via `docker exec hbec-gateway caddy reload` (zero errors each time). No container recreates during cutover; no code changes.
- Prior session work this cutover depended on: green notifications repoint + shared worker/beat repoint (`/tmp/hbec-green-redis-override.yml` on the VPS).

## Verification
- Pre-flip, inside container network: 200s from all five green endpoints (schools-backend `/` 404s on both colors — API-only service, parity confirmed).
- Post-flip, public: `student.hbca.tech` 200 + live curriculum JSON through the green chain; `admin.hbca.tech` 200 with green frontend access-log hits; `school.hbca.tech` 200; `api.hbca.tech` proxy chain proven (backend-identical 404 on guessed path).
- Green: 9/9 up, 0 restarts, uniform `sha-e44223f`, deep-ready healthy on both Djangos, harness 503 identical to live (shared Qdrant cause).
- Fallback tested by inspection (not executed): `sudo cp Caddyfile.pre-green-20261006 Caddyfile && docker exec hbec-gateway caddy reload` — single command, no rebuild.

## Follow-ups / Deferred
- Durable Redis Sentinel support for notifications (app client + Celery broker) — the hostname repoint dies at the next failover. Take up as its own initiative.
- Qdrant FD exhaustion (separate bug entry, still open) — degrades both colors equally.
- Replication-log retention + stream trimming; bulk.sync retry-path coverage (separate entries, still open).
- Decide `school-api.hbca.tech` DNS: publish or remove the block.
- Write the cutover runbook (vars, order, smoke list, fallback) into the repo; reconcile `active_color` markers with Caddy truth.
- Colored worker/beat + honest beat probe.

## References
- Bug entries: `DevOps_and_Infrastructure/HBEC-2026-10-06-notifications-worker-redis-readonly-replica.md`, `...-qdrant-too-many-open-files.md`, `Database_and_State/HBEC-2026-10-06-replication-log-unbounded-retention.md`, `...-bulk-sync-retry-and-dns-failures.md`
- VPS: `/opt/hbec/docker/caddy/Caddyfile[.pre-green-20261006]`, `/tmp/hbec-green-redis-override.yml`
- Stack PRs #53–#57 (reviewed, unmerged — none of this session's code is deployed; prod runs `sha-e44223f`)

---

**Completed By:** Muse Spark (opencode) + Tino
**Duration:** ~1h (stability sweep + stepwise cutover + verification)
