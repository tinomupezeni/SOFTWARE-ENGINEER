# Presentation deployment to hbca-vps (zimphos.restk.tech)

**Date:** 2026-11-24

## What happened
Deployed an isolated copy of Zimphos to hbca-vps for a presentation,
reachable at https://zimphos.restk.tech. First audited restk-vps and
chemglee-vps as alternatives (see `2026-11-24-pr7-pr5-merge.md`'s
companion session notes); hbca-vps was chosen for its much larger
RAM/CPU headroom and a 1TB secondary disk (`/sdb-disk`) already present,
despite being otherwise dedicated to HBEC's own production infrastructure.

Built from scratch: `backend/Dockerfile` existed already, but there was
no `frontend/Dockerfile` at all (frontend only ever ran via `npm run
dev`). Added a multi-stage build (Node build → static nginx serve) plus
an nginx config that proxies `/api`, `/admin`, `/static`, `/media` to the
backend container so the SPA's same-origin API calls need no CORS setup.
`docker-compose.prod.yml` is a separate, self-contained stack from the
repo's local-dev `docker-compose.yml` — own container names/network,
bind-mounted volumes under `./data` (so pointing the checkout at
`/sdb-disk` is enough to use the big disk, no Docker data-root
reconfiguration needed), secrets generated on the VPS itself via
`openssl rand` into a gitignored `.env.prod` rather than committed.

Routed through HBEC's existing Caddy gateway (`hbec-gateway`) via a new
hostname-based site block for `zimphos.restk.tech`, rather than opening a
new firewall port — the gateway only has 80/443 published, and the box's
iptables rules (`DOCKER-USER`/`DOCKER-FORWARD`, default-`DROP`) explicitly
allow-list container IP:port pairs, so a new raw port wouldn't have been
reachable anyway without either editing that allow-list (same category of
risk as editing the gateway) or extending the gateway's own port mapping.

## Why this is worth a change-history entry
The real "how" isn't obvious from the Caddyfile diff or the compose file
alone:
- The frontend container had to join HBEC's shared `hbec_edge-net`
  Docker network (via `docker network connect ... --alias
  zimphos-frontend`) to be reachable by the gateway container at all —
  this isn't expressed in Zimphos's own compose file since it's an
  external, host-level step, not part of the stack definition. It must be
  redone after any `docker compose up` that recreates the frontend
  container (recreating drops a manually-attached network).
- That network join caused a real cross-tenant DNS collision (full
  writeup in `DevOps_and_Infrastructure/ZIMPHOS-2026-11-24-shared-network-dns-collision.md`):
  the generic alias `backend` resolved to a different client's
  (agricredit's) backend container instead of ours, because a
  multi-homed container's DNS lookups search every network it's
  attached to, not just the one the name was meant for. Fixed with an
  explicit unique alias (`zimphos-backend-internal`) instead of the
  implicit compose-generated `backend` alias — now committed in
  `docker-compose.prod.yml` and `frontend/nginx.conf`, so this doesn't
  need to be rediscovered on a redeploy.
- `DEBUG=True` is intentional here, not an oversight: there's no
  domain-specific TLS termination at the Zimphos backend layer itself
  (Caddy terminates TLS; the backend only ever sees plain HTTP from
  nginx), and `production.py`'s `SESSION_COOKIE_SECURE`/
  `CSRF_COOKIE_SECURE` are gated on `not DEBUG` (see PR #8's own
  change-history entry) — so login would break with `DEBUG=False` here
  specifically because of how the TLS boundary is drawn, not because the
  presentation genuinely needs debug mode.

## Verification
- Full login round-trip over HTTPS through `https://zimphos.restk.tech`
  (CSRF prime → login with a seeded demo account → `GET /me`), confirmed
  landing in Zimphos's own backend logs (not another tenant's), after the
  DNS-collision fix.
- `caddy validate` run before every `caddy reload` on the shared gateway
  config, to avoid syntax-breaking every other HBEC site fronted by the
  same Caddy instance.

## Follow-ups
- PR #9 (seed_demo_logins + the deployment artifacts) not yet merged.
- Flagged to whoever manages `hbec_edge-net`/agricredit: the DNS collision
  this session hit was harmless (agricredit's backend just 404'd on
  routes it doesn't have), but a differently-shaped newcomer stack could
  have caused real cross-tenant request leakage, not just a 404.
- This deployment is temporary/presentation-only; no teardown plan has
  been written yet for after the presentation.
