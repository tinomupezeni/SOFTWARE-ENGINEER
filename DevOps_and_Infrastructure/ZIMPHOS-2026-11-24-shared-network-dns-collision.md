# Multi-homed container resolved "backend" to a different client's container on shared hbca-vps network

**Date:** 2026-11-24
**Project:** ZIMPHOS
**Environment:** Production (hbca-vps, shared multi-tenant host)
**Severity:** High
**Status:** Resolved

## Summary
While standing up an isolated presentation deployment of Zimphos on hbca-vps
(a shared host also running HBEC/agricredit/vlabs production infrastructure),
the Zimphos frontend container was joined to HBEC's shared gateway network
(`hbec_edge-net`) so it could be reached through the existing Caddy reverse
proxy. Once on that network in addition to its own stack's network, its
internal nginx config's `proxy_pass http://backend:8000` started resolving
to **`agricredit-backend-blue`** (a different client's Django backend)
instead of Zimphos's own backend container. Every `/api/*` request —
including a real login attempt with real demo credentials — was silently
proxied to the wrong tenant's service for part of the setup window.

## Symptoms
- `GET /api/csrf` via the new `zimphos.restk.tech` hostname returned `404`,
  then (on a retry) `400`, neither of which Zimphos's own Django process
  ever logged.
- Direct backend logs (`docker logs zimphos_demo_api`) showed no record of
  these requests at all, despite them clearly reaching *some* Django app
  (the response had Django's own security headers).

## Environment Details
- **Server/Host:** hbca-vps (209.209.42.142), shared production host
- **Services Affected:** `zimphos_demo_frontend` (nginx), unintentionally
  `agricredit-backend-blue` (received misdirected requests)
- **Related Components:** Docker embedded DNS (127.0.0.11), the
  `hbec_edge-net` Docker network, nginx's `resolver`-based lazy upstream
  resolution
- **Time First Observed:** 2026-11-24, within minutes of joining the shared
  network

## Investigation Steps

### 1. Initial Diagnosis
Compared nginx's access log (which *did* show the requests, with status
404/400) against the Django backend's own log (which showed nothing for
those requests) — proof the requests reached some server, but not ours.

### 2. Root Cause Analysis
```bash
docker exec zimphos_demo_frontend getent hosts backend
# -> 172.21.0.27  backend  backend

docker network inspect hbec_edge-net \
  --format '{{range $id, $c := .Containers}}{{$c.Name}} {{$c.IPv4Address}} {{end}}' \
  | tr ' ' '\n' | grep -B1 172.21.0.27
# -> agricredit-backend-blue 172.21.0.27/16
```
`172.21.0.27` belonged to `agricredit-backend-blue`, not Zimphos's backend.

### 3. Key Findings
- A Docker container attached to **multiple networks** resolves a bare
  service name across **all** of them via the embedded DNS server
  (127.0.0.11), not just the network where the lookup was intended.
- `agricredit-backend-blue` carries the network alias `backend` on
  `hbec_edge-net` (presumably for its own internal routing). Zimphos's
  compose file *also* auto-generates an implicit `backend` alias for its own
  backend service on its own network. Once the frontend container joined
  both networks, the two identically-named aliases collided.
- This is a generic risk on any shared multi-tenant Docker host: a newly
  deployed stack using conventional internal names (`backend`, `api`, `db`,
  `redis`, `cache`) is one network-join away from silently talking to
  another tenant's container of the same conventional name.

## Root Cause
Relying on Docker Compose's implicit, generic per-service DNS alias
(`backend`) for a container that also needed to join an external,
shared, multi-tenant network to reach a reverse-proxy gateway.

## Prevention / Rule
**Guardrail:** Any service in a compose stack that may ever join an
external/shared Docker network must have an explicit, globally-unique
network alias (e.g. `zimphos-backend-internal`), and nothing in that
stack may reference services by generic conventional names like
`backend`/`api`/`db` once cross-network attachment is possible. Code
review for any new deployment compose file on this host should check for
a `networks: default: aliases:` entry on every service a gateway/ingress
container needs to reach, not bare `container_name` or default aliasing.

This closes the gap because the collision is structurally impossible once
every cross-network-reachable name is unique — no amount of "be careful"
discipline prevents two unrelated teams from independently picking the
same common word.

## Solution

### Immediate Fix
`docker-compose.prod.yml`'s `backend` service now declares:
```yaml
networks:
  default:
    aliases:
      - zimphos-backend-internal
```
and `frontend/nginx.conf`'s upstream variable was changed from
`http://backend:8000` to `http://zimphos-backend-internal:8000`. Verified
by `getent hosts zimphos-backend-internal` resolving to the correct
`zimphos_default`-network IP, and a full login round-trip through
`https://zimphos.restk.tech` landing in Zimphos's own backend logs.

### Follow-up
No indication agricredit's service was harmed (it just 404/400'd on
routes it doesn't have), but this is worth a heads-up to whoever manages
`hbec_edge-net`/agricredit that a differently-configured newcomer stack
could have caused real cross-tenant request leakage, not just harmless
404s.
