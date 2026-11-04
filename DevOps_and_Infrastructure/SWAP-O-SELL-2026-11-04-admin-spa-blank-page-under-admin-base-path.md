# Admin SPA production build serves a blank page under its /admin/ base path

**Date:** 2026-11-04
**Project:** SWAP-O-SELL
**Environment:** Production (mywealth-vm, discovered while preparing a new
public domain's reverse-proxy routing)
**Severity:** High
**Status:** Resolved

## Summary
While preparing nginx reverse-proxy routing for a new public domain
(`swaposell.hpc.ac.zw`, intended to route `/admin` to the admin React app),
found that the admin app's production Docker image never actually serves a
working app — any request for its JS/CSS bundle silently falls back to
`index.html` instead of the real asset, so the browser gets HTML where it
expects JavaScript and the SPA never boots.

## Symptoms
- `curl http://host:5174/admin/assets/index-XXXX.js` returns HTTP 200 but
  `Content-Type: text/html` — the body is `index.html`, not the JS bundle.
- In a real browser this manifests as a blank page with a module-script
  parse error (`Unexpected token '<'` or similar), since the browser tries
  to execute HTML as a JS module.
- Affected any deployment of the `admin` container built from
  `admin/Dockerfile` — confirmed on `mywealth-vm`, likely also true on
  `restk-vps` since the Dockerfile/nginx.conf are identical there.

## Environment Details
- **Server/Host:** mywealth-vm (10.50.23.166 / public 102.217.49.126)
- **Services Affected:** `admin` container (`swap-o-sell-admin`)
- **Related Components:** `admin/vite.config.ts` (`base: '/admin/'`),
  `admin/Dockerfile`, `admin/nginx.conf`
- **Time First Observed:** 2026-11-04, while verifying the admin app would
  work once routed at `swaposell.hpc.ac.zw/admin`

## Investigation Steps

### 1. Initial Diagnosis
```bash
curl -s http://localhost:5174/ | grep -oE 'src="[^"]+"|href="[^"]+\.css"'
# -> src="/admin/assets/index-ytQ_e5rn.js"
#    href="/admin/assets/index-DuslKP8_.css"
curl -s -D - -o /dev/null http://localhost:5174/admin/assets/index-ytQ_e5rn.js | grep -i content-type
# -> Content-Type: text/html
```
The asset request was returning HTML, not JS.

### 2. Root Cause Analysis
- `admin/vite.config.ts` sets `base: '/admin/'`, so the built `index.html`
  references absolute asset URLs prefixed with `/admin/`.
- `admin/Dockerfile` copied the build output straight to the nginx image's
  web root (`/usr/share/nginx/html`), i.e. assets physically live at
  `/assets/*`, not `/admin/assets/*`.
- `admin/nginx.conf` had a single catch-all `location / { try_files $uri
  $uri/ /index.html; }` with no `/admin/` prefix handling, so any request
  under `/admin/...` (including the asset paths the HTML itself asks for)
  never matched a real file and fell through to the SPA fallback
  (`index.html`), which is always a 200 but the wrong content type/body.

### 3. Key Findings
- This has presumably been broken since the admin app was first built with
  a non-root `base` — the Vite dev server (`npm run dev`) and Docker-based
  production serving behave differently here: dev server resolves `base`
  itself, nginx does not, so the bug only shows up in the built/served
  image, not local `npm run dev`, which is likely why it went unnoticed.

## Root Cause
Vite's `base: '/admin/'` config changes the *referenced* asset paths in the
built HTML/JS, but does not change the *physical* output directory layout
(`dist/assets/...`). The Dockerfile/nginx config copied the build to the
web root and never accounted for that mismatch, so none of the referenced
`/admin/...` asset URLs resolved to a real file.

## Prevention / Rule
**Guardrail:** Any Vite app built with a non-root `base` must serve its
build output from a web root subpath matching that `base` exactly (or use
an explicit `alias`-based nginx location that strips the prefix) — verified
by an automated smoke check after build: `curl -f
http://<container>/<base>/assets/$(ls dist/assets | grep '\.js$' | head
-1)` should return `Content-Type: application/javascript`, not
`text/html`. Add this check to whatever builds/deploys the admin image so a
base-path mismatch fails the build instead of shipping a blank page.

## Solution

### Immediate Fix
- `admin/Dockerfile`: copy the build output to
  `/usr/share/nginx/html/admin` instead of the web root, so physical file
  paths match the `/admin/...` URLs the built HTML references.
- `admin/nginx.conf`: added `location /admin/ { try_files $uri $uri/
  /admin/index.html; }` and a `location = /admin` / `location /` redirect
  to `/admin/`, replacing the old root catch-all.
- Verified locally: built the image, ran it, confirmed root issues a 301 to
  `/admin/`, `/admin/` returns 200, and the referenced JS asset now returns
  `Content-Type: application/javascript`.
- Redeployed to `mywealth-vm` (rebuilt + recreated the `admin` container).

### Long-term Fix
Applied as the immediate fix — no further follow-up needed unless
`restk-vps`'s admin deployment is confirmed to have the same issue, in
which case it needs the same rebuild/redeploy.

## Prevention
- [x] Code changes required — `admin/Dockerfile`, `admin/nginx.conf`
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — consider the asset-content-type smoke
      check above in CI for the admin build
- [ ] Documentation to update — n/a

## Related Issues
- Discovered while setting up nginx reverse-proxy routing for the new
  `swaposell.hpc.ac.zw` domain (not a separate logged issue — same session).

## References
- `admin/vite.config.ts` (`base: '/admin/'`)
- `admin/Dockerfile`
- `admin/nginx.conf`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~20 minutes
