# nginx resolver+variable upstream fix did not actually self-heal after backend recreation

**Date:** 2026-10-13
**Project:** TESC
**Environment:** Staging
**Severity:** Medium
**Status:** Workaround Applied

## Summary
A prior incident ([[TESC-2026-10-12-nginx-stale-upstream-swapped-frontends]])
put a `resolver 127.0.0.11 valid=10s;` + `set $upstream_backend ...;
proxy_pass $upstream_backend;` pattern in place specifically so nginx would
re-resolve a Docker service hostname on every request instead of caching an
IP forever, with the guardrail explicitly framed as "no deploy step can
forget it." During today's deploy (rebuilding + recreating `backend` and
`celery_worker` for the dynamic-report filter fix,
[[TESC-2026-10-13-dynamic-report-filter-fielderror-500s]]), every request
through nginx to the backend 502'd for well over a minute after the new
container came up healthy - the claimed self-heal did not happen on its own
within any reasonable window, and a manual `nginx -s reload` was required.

## Symptoms
- `docker compose -f docker-compose.prod.yml up -d backend celery_worker`
  completed cleanly; `docker ps` showed `tesc-backend-1` as `Up` and
  `tesc-db-1` healthy.
- Every request through nginx to any `/api/*` path (not just the
  newly-changed report endpoints) returned `502 Bad Gateway`, including
  previously-stable routes like `/api/users/profile/`.
- `docker exec tesc-backend-1` confirmed gunicorn had started cleanly with
  no errors; a direct `curl` to the container's own IP (`172.18.0.8:8000`)
  from the VM host succeeded (got a Django response, not a connection
  error).
- nginx error log showed it was still targeting the *old* container IP from
  before recreation:
  ```
  connect() failed (111: Connection refused) while connecting to upstream,
  ... upstream: "http://172.18.0.6:8000/..."
  ```
  more than 60 seconds after the backend was recreated at `172.18.0.8` - far
  past the configured `valid=10s` resolver TTL.
- Polling the endpoint every 4 seconds for 5 attempts (20+ seconds) showed
  no recovery; only an explicit `docker exec tesc-nginx-1 nginx -s reload`
  fixed it immediately (next request succeeded).

## Environment Details
- **Server/Host:** `tesc-staging` VM, `tesc-nginx-1` container
- **Services Affected:** all `/api/*` routing (both `tesc-staging.zchpc.ac.zw`
  and, structurally, `tesc-inst-staging.zchpc.ac.zw`, since both share the
  same nginx process)
- **Related Components:** `nginx/nginx.conf`'s `resolver` + `set
  $upstream_backend` pattern from the prior incident
- **Time First Observed:** 2026-10-13 06:33-06:36 UTC, immediately after
  `docker compose up -d backend celery_worker`

## Investigation Steps

### 1. Initial Diagnosis
Confirmed the backend container itself was healthy (gunicorn logs clean,
direct curl to its container IP succeeded) before suspecting nginx -
ruling out "the deploy broke the app" in favor of "nginx can't reach the
app."

### 2. Root Cause Analysis
Checked `docker inspect tesc-backend-1` for its actual current IP
(`172.18.0.8`) against the IP nginx's error log was still trying
(`172.18.0.6`) - confirmed nginx was using a stale address. Verified the
`resolver`/`set $upstream_backend` pattern from the prior fix was in fact
live in the mounted `nginx/nginx.conf` (it was - this wasn't a regression
of that config). Waited through multiple 10s+ windows with no recovery,
ruling out "just needs a bit longer than one TTL cycle." A manual
`nginx -s reload` fixed it on the very next request.

### 3. Key Findings
- The `resolver ... valid=10s` + variable `proxy_pass` pattern is real and
  present, but in practice did not cause nginx to drop the stale DNS answer
  and re-resolve within any window tested (over 60 seconds, well beyond the
  configured TTL).
- A plain `nginx -s reload` (not a container restart) was sufficient and
  immediate - meaning the running nginx process can reach the new backend
  fine once its resolver cache state is cleared; the problem is specifically
  that the cache isn't clearing itself on the advertised schedule.
- This was not investigated down to nginx-internals root cause (e.g.
  whether `valid=10s` is actually being honored by this nginx:alpine build,
  or whether some other caching layer - connection keepalive, DNS caching
  inside the container's resolv.conf, etc. - is involved). This is flagged
  explicitly as unresolved below rather than guessed at.

## Root Cause
Not fully determined. The previously-applied guardrail (resolver + variable
proxy_pass, intended to force per-request re-resolution) did not produce
the expected self-healing behavior after a `backend` container recreation
in this instance - nginx kept routing to the pre-recreation IP well past its
configured 10-second resolver TTL, and required a manual reload to recover.

## Prevention / Rule
**Guardrail:** until the actual reason the resolver TTL isn't being honored
is root-caused, treat `docker compose up -d <service>` for any service
nginx proxies to as **not self-healing** in practice, and make
`docker exec tesc-nginx-1 nginx -s reload` (not a full container restart -
it's faster and doesn't drop existing connections) an explicit, mandatory
step of the deploy procedure immediately after recreating `backend`,
`frontend_client`, or `frontend_admin` - add it to whatever deploy
script/runbook exists so it isn't a step a human has to remember.

This is an operational stopgap, not a structural fix - the prior incident's
own "Prevention/Rule" explicitly argued against relying on an operational
step for exactly this reason. It's the right interim guardrail only because
the structural fix (resolver+variable) has now been observed to not behave
as expected in practice and needs further investigation before it can be
trusted as self-sufficient again.

## Solution

### Immediate Fix
```bash
docker exec tesc-nginx-1 nginx -s reload
# confirmed immediately after:
curl -s -o /dev/null -w "%{http_code}\n" https://tesc-staging.zchpc.ac.zw/api/v1/reports/schemas/
# -> 401 (reachable, auth required) instead of 502
```

### Long-term Fix
Root-cause why `resolver 127.0.0.11 valid=10s;` isn't producing the
re-resolution it's documented to. Candidates to check next time this
recurs: whether this nginx:alpine version actually re-resolves on
cache-variable proxy_pass per-request vs. per-worker-lifetime; whether
keepalive connections to the upstream are being reused past the point they
should be invalidated; whether Docker's embedded DNS (127.0.0.11) itself is
returning a longer TTL that `valid=10s` isn't fully overriding. Until
determined, keep the mandatory-reload-after-deploy step in place.

## Prevention
- [ ] Configuration changes needed — further nginx resolver investigation.
- [ ] Monitoring/alerts to add — alert on 502 rate from nginx post-deploy.
- [x] Documentation to update — this entry, plus the deploy runbook should
      gain the mandatory `nginx -s reload` step.
- [ ] Code changes required — none yet; root cause still open.

## Related Issues
- [[TESC-2026-10-12-nginx-stale-upstream-swapped-frontends]] — the incident
  that introduced the resolver+variable pattern this entry shows did not
  fully hold up.
- [[TESC-2026-10-13-dynamic-report-filter-fielderror-500s]] — the deploy
  during which this was discovered.

## References
- `nginx/nginx.conf`
- `docker-compose.prod.yml`

---

**Resolved By:** tinomupezeni (with Claude Sonnet 5)
**Time to Resolution:** ~5 minutes (workaround); root cause open
