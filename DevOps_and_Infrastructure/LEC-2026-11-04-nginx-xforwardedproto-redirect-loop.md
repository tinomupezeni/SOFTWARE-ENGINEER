# nginx overwrote Caddy's X-Forwarded-Proto, would 301-loop every real API call

**Date:** 2026-11-04
**Project:** LEC Virtual Labs
**Environment:** Production (`hbca-vps`, caught before cutover — no public traffic affected)
**Severity:** High (would have broken every API request from real users, not just a healthcheck)
**Status:** Resolved

## Summary
While verifying `vlabs-backend-blue`/`vlabs-frontend-blue` directly (before pointing any
public traffic at them, per ADR-004's pre-cutover verification step), a plain request to
`/api/subjects/` through the frontend's own nginx returned `301 Moved Permanently` →
`https://127.0.0.1/api/subjects/`. This is the same `SECURE_SSL_REDIRECT` mechanism as the
healthcheck bug logged earlier today, but this instance would have hit **every real
browser request**, not just an internal healthcheck — nginx's `/api/` location block set
`proxy_set_header X-Forwarded-Proto $scheme;`, and nginx's own `$scheme` is always `http`
(it only ever `listen`s on port 80, never terminates TLS itself) — so it silently
overwrote whatever correct `X-Forwarded-Proto: https` Caddy had already set on its own hop
to nginx, with the literal string `http`, on every single proxied request.

## Symptoms
- `docker exec vlabs-frontend-blue wget -S --spider http://127.0.0.1/api/subjects/`
  returned `301` with `Location: https://127.0.0.1/api/subjects/` — a redirect to a URL
  the client (a real browser, going through Caddy) could never usefully follow, since the
  request was already over HTTPS by the time it reached Caddy.

## Environment Details
- **Server/Host:** `hbca-vps`, `vlabs-frontend-blue` / `vlabs-backend-blue`
- **Services Affected:** none in production yet — caught during pre-cutover verification,
  before `hbca.tech/vlabs` ever pointed at this color
- **Related Components:** `frontend/nginx.conf.template`'s `/api/` location,
  `backend/config/settings.py`'s `SECURE_SSL_REDIRECT`/`SECURE_PROXY_SSL_HEADER`
- **Time First Observed:** 2026-11-04, same session as the healthcheck `DisallowedHost`/301
  findings — this is the general-case version of that same narrow bug

## Investigation Steps

### 1. Initial Diagnosis
After fixing the backend healthcheck's own 301 (by sending `X-Forwarded-Proto: https`
directly in the Dockerfile's `curl`), it was worth checking whether the *real* request
path (through nginx, not a bare loopback curl) had the same problem — it did.

### 2. Root Cause Analysis
`nginx.conf.template` was modeled on HBEC's own `STUDENT/Frontend/nginx.conf.template`,
which has the identical `proxy_set_header X-Forwarded-Proto $scheme;` line. `$scheme` in
nginx reflects the scheme of the connection nginx itself received — and since this
container only ever `listen`s on plain port 80 (TLS is terminated upstream, at Caddy), that
value is unconditionally `http`, regardless of what the real end-user's browser used.
Caddy's `reverse_proxy` already sets a correct `X-Forwarded-Proto` based on the original
client connection, but this `proxy_set_header` line unconditionally replaces it (nginx's
`proxy_set_header` always overwrites, never appends) before forwarding to Django.

### 3. Key Findings
- This container (`vlabs-frontend-*`) is never reachable directly from the public
  internet — only via `hbec-gateway` (Caddy) on `hbec_edge-net` — so hardcoding
  `X-Forwarded-Proto: https` here is accurate for this topology, not a weakening: any
  request that reaches this nginx has already passed through Caddy's TLS termination.
- Not yet checked whether HBEC's own production nginx configs (same line, same pattern)
  have an equivalent live issue — out of scope for this entry, which is about VLabs' own
  config, but worth a follow-up look given the identical line appears in multiple HBEC
  frontend nginx templates.

## Root Cause
`proxy_set_header X-Forwarded-Proto $scheme;` is only correct when nginx itself terminates
TLS. In this topology nginx never does — Caddy does — so the directive silently discarded
the one piece of information (`https`) Django's `SECURE_PROXY_SSL_HEADER` check depends on.

## Solution

### Immediate Fix
Changed `frontend/nginx.conf.template`'s `/api/` block to
`proxy_set_header X-Forwarded-Proto https;` (hardcoded, with a comment explaining why),
rebuilt the image, redeployed `vlabs-frontend-blue`, and re-verified the same request
directly against the container returns `200`/`401` (a real response), not `301`.

### Long-term Fix
None needed beyond the one-line template fix — this is now correct for the only topology
this container ever runs in.

## Prevention
- [x] `nginx.conf.template`'s `/api/` block hardcodes the correct scheme with an inline
      comment explaining why `$scheme` is wrong here
- [ ] Follow-up (not done this session): check whether HBEC's own frontend nginx
      templates, which use the identical `$scheme` line, have a live equivalent of this —
      flagged, not investigated, since it's out of scope for a VLabs-focused session

## Related Issues
- `LEC-2026-11-04-backend-healthcheck-disallowedhost.md` — same `SECURE_SSL_REDIRECT`
  mechanism, narrower blast radius (the healthcheck's own loopback request only).

## References
- `frontend/nginx.conf.template`
- `backend/config/settings.py` (`SECURE_SSL_REDIRECT`, `SECURE_PROXY_SSL_HEADER`)
- `intelligent_memory_management/decisions/ADR-004-vps-bluegreen-deployment.md`

---

**Resolved By:** Claude Sonnet 5 (Claude Code session)
**Time to Resolution:** <15 minutes, caught during pre-cutover direct-container verification,
before any public traffic was ever routed to this color.
