# Maricho production domain cutover to maricho.restk.tech

**Date:** 2026-11-11
**Project:** MARITCHO
**Type:** Architecture Decision / Deployment Change
**Status:** Completed

## Summary
Added `maricho.restk.tech` as a public domain for the Maricho production
stack, routed through the shared `caddy-proxy` on the restk VPS alongside
the existing `maricho.restksolutions.co.zw` host, and rebuilt the frontend
with the new websocket origin baked in. Also committed a dockerized,
image-based deploy pipeline for MARITCHO that had been sitting uncommitted
in the working tree from an earlier session.

## Context / Trigger
User asked to point Maricho at `maricho.restk.tech` via the VPS's central
Caddy, dockerize if needed, and then actually commit and deploy the change
to the passwordless-SSH VPS alias `restk-vps`.

## Scope
Included: central Caddy routing for the new domain, the VPS's live
`NEXT_PUBLIC_WS_URL` env value, rebuilding/restarting the `maricho-frontend`
container, reconciling the drifted local copy of the central Caddyfile, and
committing MARITCHO's already-dockerized deploy assets.

Excluded: switching the live VPS stack onto the new image-based deploy
pipeline (`deploy.sh`/`deploy_upload.sh`). The VPS still runs the original
build-on-VPS `docker-compose.yml` (full source tree synced to
`~/apps/maricho`, `build:` context per service); cutting that over to the
build-locally/upload-image flow is a separate, riskier change and was left
for a deliberate follow-up rather than bundled into a live DNS/domain change.
Removing the old `maricho.restksolutions.co.zw` host was also excluded —
added the new host alongside it rather than replacing it, since nothing
asked for the old one to stop working.

## Method
Before touching anything, pulled the live `~/core/Caddyfile` from the VPS
and diffed it against the repo's tracked copy
(`TESE-MARKET---BFF-ARCHITECTURE/infrastructure/caddy/Caddyfile`): the
tracked copy had drifted significantly (missing the entire Maricho block,
a Swap-O-Sell block, and other hosts; several hosts had different routing
than what's actually live). Treated the live file as source of truth,
pulled it into the repo, then applied the domain edit on top of that — this
avoided overwriting the production proxy config with a stale local file.
Checked DNS for the new hostname against the VPS's public IP before
touching Caddy, so the TLS cert issuance wouldn't silently fail.

## Decisions & Findings
- MARITCHO is dockerized already (backend/frontend Dockerfiles,
  `deploy/production/docker-compose.yml`) and already runs behind the
  shared VPS Caddy on an external `proxy-tier` network — no new
  dockerization work was needed, contrary to the initial ask.
- The project's `frontend` service is a Next.js BFF that itself serves
  `/api`, the mobile API passthrough paths, and the websocket upgrade, so
  one public hostname is sufficient; no extra subdomain needed for the API.
- Found an uncommitted, apparently prior-session rewrite of the deploy
  pipeline (new `deploy.sh`/`deploy_upload.sh`, `docker-compose.yml`
  switched from `build:` to `image:`) sitting in the working tree,
  unrelated to this session's own edits. It's coherent and worth keeping,
  but untested against the live stack, so it was committed but not used
  for this deploy.
- `websocket` origin is a Next.js build-time arg
  (`NEXT_PUBLIC_WS_URL`), so changing the domain required a full rebuild
  of the frontend image on the VPS, not just an env/restart.

## Changes Made
- VPS `~/core/Caddyfile`: `maricho.restksolutions.co.zw` block's host list
  changed to `maricho.restk.tech, maricho.restksolutions.co.zw` (backup
  taken as `Caddyfile.backup.<timestamp>` before editing); validated with
  `caddy validate` inside the running container, then `docker restart
  caddy-proxy`.
- VPS `~/apps/maricho/deploy/production/.env`: `NEXT_PUBLIC_WS_URL` updated
  to `wss://maricho.restk.tech`; ran `docker compose build frontend` then
  `docker compose up -d --no-deps frontend` to roll the new image.
- Repo `TESE-MARKET---BFF-ARCHITECTURE/infrastructure/caddy/Caddyfile`:
  resynced to the live VPS file plus the new Maricho host (commit
  `c82113a`). Pre-existing unrelated staged deletions in that repo
  (customer-store cleanup) were deliberately left untouched/uncommitted.
- Repo `MARITCHO`: committed `deploy/production/.env.example`,
  `README.md`, `deploy.sh`, `deploy_upload.sh`, and the `docker-compose.yml`
  image-based rewrite, all updated to reference `maricho.restk.tech`
  (commit `037f192`).

## Verification
- `caddy validate --config /etc/caddy/Caddyfile` passed before restart.
- `curl -I https://maricho.restk.tech/` → `200`, with page `<title>Maricho</title>`.
- `docker compose ps frontend` on the VPS shows `maricho-frontend` healthy
  on the rebuilt image.

## Follow-ups / Deferred
- Decide whether to retire `maricho.restksolutions.co.zw` once
  `maricho.restk.tech` is confirmed as the canonical domain everywhere
  (marketing links, mobile app `API_BASE_URL` dart-define, etc.).
- Separately validate and cut the VPS over to the new image-based deploy
  pipeline (`deploy.sh`) instead of the current build-on-VPS compose file,
  so future deploys don't require manual SSH steps like this one.
- The repo's central Caddyfile copy will drift again the next time anyone
  edits the live VPS file directly without pushing the change back to
  `TESE-MARKET---BFF-ARCHITECTURE`; worth a reminder/process note for
  whoever owns that shared infra file.

## References
- `MARITCHO/deploy/production/README.md` (new "Central Caddy" section)
- `TESE-MARKET---BFF-ARCHITECTURE/infrastructure/caddy/Caddyfile`

---

**Completed By:** tinomupezeni (with Claude Sonnet 5)
**Duration:** ~1 session
