# nginx served the main and institution portals swapped after a routine deploy

**Date:** 2026-10-12
**Project:** TESC
**Environment:** Staging
**Severity:** High
**Status:** Resolved

## Summary
After deploying a feature (OTP remember-device) to `tesc-staging`, the two
public domains served the wrong app entirely: `tesc-staging.zchpc.ac.zw`
(expected: main "ScalarEye SRS" portal) showed the Institution Portal, and
`tesc-inst-staging.zchpc.ac.zw` (expected: Institution Portal) showed the
main portal's simple login screen. User-reported as "the domains got mixed
up." The deployed code on both sides was correct the whole time - this was
a reverse-proxy routing bug, not a build or branch issue.

## Symptoms
- `https://tesc-inst-staging.zchpc.ac.zw/` showed the main portal's login
  (email/password only, "Scalareye - Zimbabwe Human Capital Planning...").
- `https://tesc-staging.zchpc.ac.zw/` showed the Institution Portal's login
  (institution dropdown + email/password).
- Reported alongside "none of the frontends have the remember me button" -
  a red herring caused by the same bug: the tester was looking at swapped
  apps, not missing functionality (both deployed bundles already contained
  the feature, confirmed via `grep` inside each container).

## Environment Details
- **Server/Host:** `tesc-staging` VM, `tesc-nginx-1` container
- **Services Affected:** Public routing for `frontend_client` (main
  portal, built from `./frontend`) and `frontend_admin` (Institution
  Portal, built from `./inst`)
- **Related Components:** `nginx/nginx.conf`, `docker-compose.prod.yml`
- **Time First Observed:** 2026-10-12, immediately after a deploy that
  recreated `frontend_client`/`frontend_admin` via
  `docker compose -f docker-compose.prod.yml up -d --remove-orphans`

## Investigation Steps

### 1. Initial Diagnosis
Read `nginx/nginx.conf` on both the local repo and the VM - identical,
and internally consistent: `tesc-staging.zchpc.ac.zw` routes to
`frontend_client`, `tesc-inst-staging.zchpc.ac.zw` routes to
`frontend_admin`. Config-on-disk looked correct, which ruled out a simple
"wrong domain in the config" mistake.

### 2. Root Cause Analysis
Tested nginx directly with explicit `Host` headers from the VM itself
(bypassing any possible external DNS/gateway issue):

```bash
curl -s -H 'Host: tesc-staging.zchpc.ac.zw' http://localhost/ | grep -oE '<title>[^<]*</title>'
curl -s -H 'Host: tesc-inst-staging.zchpc.ac.zw' http://localhost/ | grep -oE '<title>[^<]*</title>'
# -> swapped titles, confirming nginx itself was misrouting, not DNS/CDN
```

Then checked what was actually *inside* each container, independent of
nginx:

```bash
docker exec tesc-frontend_client-1 grep -i title /usr/share/nginx/html/index.html
docker exec tesc-frontend_admin-1 grep -i title /usr/share/nginx/html/index.html
# -> each container had the CORRECT content for its build context
```

This isolated the bug to nginx's proxy routing specifically - the images
were right, the config file was right, but the live behavior was wrong.
Checked container uptimes: `tesc-nginx-1` had been running 2 days
continuously, while `frontend_client`/`frontend_admin` had just been
recreated (new IPs on the `main_net` bridge network) by the deploy minutes
earlier.

### 3. Key Findings
- `proxy_pass http://frontend_client:80;` (a bare hostname, no variable)
  causes nginx to resolve that hostname to an IP once, at config load (or
  first request), and never again for the life of the worker process.
- `docker compose up -d` recreating a service gives it a new IP on the
  bridge network. If nginx is not itself restarted/reloaded, it keeps
  sending traffic to the *old* IP - which Docker may have since handed to
  a *different* container (exactly what happened: frontend_client's old
  IP became frontend_admin's new IP, or vice versa), producing not a
  connection error but a confident, successful proxy to the wrong app.
- This is a documented failure mode: SOFTWARE-ENGINEER guide
  `10. Deployment And Maintenance.md`, "Triage Checklist: Service
  Unreachable Through the Gateway", point 7, from a prior incident on a
  different project (2026-09-11).

## Root Cause
nginx's `proxy_pass` to a bare Docker service hostname resolves once and
caches the IP indefinitely. A deploy recreated the two frontend
containers without also reloading nginx, so nginx kept serving traffic to
stale IPs that the Docker bridge network had since reassigned to the
*other* frontend service - swapping which domain served which app.

## Prevention / Rule
**Guardrail:** Any nginx (or similar) reverse-proxy config in front of
Docker Compose services must reference upstreams through an explicit
`resolver` (Docker's embedded DNS, `127.0.0.11`) plus a `proxy_pass`
*variable*, never a bare hostname - a config review / lint step should
reject `proxy_pass http://<bare-hostname>` in any nginx config touching
Docker-networked services.

This closes the gap structurally rather than operationally: an
operational rule ("reload nginx after every upstream recreate") is one
missed step away from recreating this exact incident, since nothing
enforces it. The `resolver` + variable pattern makes nginx re-resolve on
every request on its own, so no deploy step can forget it.

## Solution

### Immediate Fix
Restarted `tesc-nginx-1` to force re-resolution and confirmed correct
routing immediately after:
```bash
docker restart tesc-nginx-1
curl -s -H 'Host: tesc-staging.zchpc.ac.zw' http://localhost/ | grep -oE '<title>[^<]*</title>'
curl -s -H 'Host: tesc-inst-staging.zchpc.ac.zw' http://localhost/ | grep -oE '<title>[^<]*</title>'
```

### Long-term Fix
Edited `nginx/nginx.conf`: added `resolver 127.0.0.11 valid=10s;` at the
`http` block level, and changed every `proxy_pass http://service:port;`
to `set $upstream_x http://service:port; proxy_pass $upstream_x;` across
both server blocks (frontend_client, frontend_admin, and all three
backend locations). Validated syntax in a throwaway container
(`docker run --rm -v ... nginx:alpine nginx -t`), then deployed and
proved the fix by force-recreating both frontend containers again
(`docker compose -f docker-compose.prod.yml up -d --force-recreate
frontend_client frontend_admin`) with nginx left completely untouched -
routing stayed correct, confirming self-healing.

## Prevention
- [x] Code changes required (done this session - `nginx/nginx.conf`)
- [ ] Add a CI/lint check that flags `proxy_pass http://<bare-hostname>`
      (no `resolver` + variable) in any nginx config in this repo
- [ ] Apply the same `resolver` + variable pattern to `nginx/nginx.conf`'s
      prod counterpart if a separate file exists for `tesc.zchpc.ac.zw`
      proper (not just the staging-reachable server block already covered
      here, since both domains share the same file)

## Related Issues
- None filed for the near-miss during this same deploy: an earlier
  `--remove-orphans` flag on this same VM stopped and removed the
  separate k6/Grafana load-testing stack because it shares the same
  Compose project namespace (not a bug in the app, but a deploy-command
  footgun worth a guardrail of its own if it recurs).

## References
- `nginx/nginx.conf`
- `docker-compose.prod.yml`
- `/home/shadowe/Projects/SOFTWARE-ENGINEER/Principal_Engineer/engineering-guides/10. Deployment And Maintenance.md`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~25 minutes from report to verified structural fix
