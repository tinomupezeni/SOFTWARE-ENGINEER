# VITE_API_URL silently ignored in every production build — frontend always hardcoded to call the user's own localhost

**Date:** 2026-11-04
**Project:** SWAP-O-SELL
**Environment:** Production (discovered on mywealth-vm; same source affects restk-vps)
**Severity:** Critical
**Status:** Resolved

## Summary
While rebuilding the frontend and admin containers with a new
`VITE_API_URL` (for a new public domain, `swaposell.hpc.ac.zw`), found that
the resulting bundle still called `http://127.0.0.1:8000/api/` no matter
what `VITE_API_URL` was set to. Traced it to a build-time bug that has
silently affected **every** production build of the storefront app: the
`VITE_API_URL` build argument has never actually been baked into the
bundle. The deployed app has always shipped hardcoded to call the end
user's own `localhost:8000`, which does not exist on a real user's
machine — i.e. the storefront's API calls have likely never worked for
any real visitor on any production deployment of this app to date.

## Symptoms
- Rebuilt `swap-o-sell-frontend` with `--build-arg
  VITE_API_URL=https://swaposell.hpc.ac.zw/api/`; the resulting JS bundle
  still contained the literal string `http://127.0.0.1:8000/api/` and no
  trace of the new URL.
- Reproduced with three different ways of setting the var (Docker build
  arg, shell env var passed straight to `vite build`, `.env.production.local`
  file) — same result every time, byte-identical output hash
  (`index-BNsaet6M.js`) regardless of the value supplied.
- `admin` had a related but separate symptom: same hardcoded-fallback
  behavior, but for a different root cause (see below).

## Environment Details
- **Server/Host:** mywealth-vm (discovered here); same source deployed to
  restk-vps is presumed affected too, not yet verified there
- **Services Affected:** `swappify-social-hub` (storefront), `admin`
- **Related Components:** `swappify-social-hub/src/server/constants.tsx`,
  `admin/Dockerfile`, `admin/src/api.ts` (already correct)
- **Time First Observed:** 2026-11-04, verifying a `VITE_API_URL` change
  took effect before wiring up new domain routing

## Investigation Steps

### 1. Initial Diagnosis
```bash
VITE_API_URL=https://probe.example/api/ npx vite build --outDir /tmp/t
grep -o 'probe.example\|127.0.0.1:8000' /tmp/t/assets/*.js
# -> 127.0.0.1:8000   (not probe.example)
```
Confirmed this wasn't a Docker caching artifact — plain `vite build` with
the env var set directly in the shell still ignored it.

### 2. Root Cause Analysis
```bash
node -e "const {loadEnv}=require('vite'); console.log(loadEnv('production', process.cwd(), '').VITE_API_URL)"
# -> correctly printed the value — Vite CAN see it
```
So the variable was visible to Vite's env loader; the break was somewhere
between that and the actual bundle. Built with `--minify false` to read
the unminified output around the assignment:
```js
const api_url = ((_j = (_i = import.meta) == null ? void 0 : _i.env) == null ? void 0 : _j.VITE_API_URL) || "http://127.0.0.1:8000/api/";
```
The source was:
```ts
export const api_url =
  (import.meta as any)?.env?.VITE_API_URL || "http://127.0.0.1:8000/api/";
```
Vite's static env-replacement plugin only recognizes the literal
`import.meta.env.X` (or `import.meta.env["X"]`) AST pattern. The `as any`
cast plus optional-chaining on `import.meta` itself gets lowered by
TypeScript/esbuild into a temp-variable indirection (`_i = import.meta;
_i.env...`), which no longer matches that pattern — so the replacement
never fires, and the runtime `import.meta.env` stub Vite injects for
unmatched references does not contain the custom key, so the lookup is
`undefined` and the hardcoded fallback is always used.

Confirmed by rewriting the line as a plain `import.meta.env.VITE_API_URL`
reference and rebuilding — the custom value was correctly inlined.

`admin` had a second, independent cause for the same symptom:
`admin/src/api.ts` already used the correct plain-reference pattern, but
`admin/Dockerfile` never declared `ARG VITE_API_URL` before its `RUN npm
run build` step, so the `--build-arg VITE_API_URL=...` docker-compose
passes was never consumed/exposed as an environment variable inside the
build stage at all (Docker silently drops unconsumed build args).

### 3. Key Findings
- This is a correctness bug in application source code, not a deployment
  or caching issue — it reproduces with a plain, non-Dockerized `vite
  build` and is 100% deterministic (same output regardless of input).
- The storefront's own Docker setup (`swappify-social-hub/Dockerfile`,
  `nginx.conf`) was otherwise correct — it does wire `ARG`/`ENV`
  correctly; the break was purely in the TS source pattern.
- Because the resulting bundle calls an *absolute* `http://127.0.0.1:8000/api/`
  URL rather than a relative `/api/` path, the frontend container's own
  `nginx.conf` same-origin `/api/` proxy (which does work correctly)
  never gets a chance to help — the browser never routes the request
  through it at all.

## Root Cause
Two independent build-arg plumbing bugs that happened to produce the same
symptom:
1. `swappify-social-hub/src/server/constants.tsx` used an `import.meta`
   access pattern (`(import.meta as any)?.env?.VITE_API_URL`) that Vite's
   static env-substitution cannot recognize, so the real `VITE_API_URL`
   value is never inlined into the production bundle.
2. `admin/Dockerfile` never declared `ARG VITE_API_URL`, so Docker dropped
   the `--build-arg` silently before it could reach the Vite build.

## Prevention / Rule
**Guardrail:** Add a build-time smoke assertion to CI (or the deploy
script) for both frontend apps: after `vite build` with a distinctive
`VITE_API_URL` test value, `grep` the output bundle for that value and
fail the build if it's absent. This directly catches both the "pattern
Vite can't statically replace" class of bug and the "build arg never
reached the build" class of bug, since both manifest identically (custom
value absent from the bundle).

## Solution

### Immediate Fix
- `swappify-social-hub/src/server/constants.tsx`: replaced the
  cast/optional-chaining access with a direct `import.meta.env.VITE_API_URL`
  reference.
- `admin/Dockerfile`: added `ARG VITE_API_URL=http://localhost:8000/api/`
  and `ENV VITE_API_URL=$VITE_API_URL` before the build step, matching the
  pattern already used in `swappify-social-hub/Dockerfile`.
- Verified locally: built both images with
  `VITE_API_URL=https://swaposell.hpc.ac.zw/api/` and confirmed that exact
  value is now present in both output bundles with no `127.0.0.1:8000` /
  `localhost:8000` fallback remaining.
- Rebuilt and redeployed both containers on mywealth-vm.

### Long-term Fix
- Verify `restk-vps` (the actual customer-facing production deployment)
  has the same issue and redeploy there once confirmed — **not yet done,
  flagged for the user to decide on since it requires pushing to
  `origin/main`, which triggers that environment's auto-deploy.**
- Add the build-time smoke assertion described above to CI.

## Prevention
- [x] Code changes required — `constants.tsx`, `admin/Dockerfile`
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — the CI smoke assertion above
- [ ] Documentation to update — n/a

## Related Issues
- Discovered while setting up new domain (`swaposell.hpc.ac.zw`) reverse
  proxy routing; cross-reference
  `DevOps_and_Infrastructure/SWAP-O-SELL-2026-11-04-admin-spa-blank-page-under-admin-base-path.md`
  (a separate admin routing bug found the same session).

## References
- `swappify-social-hub/src/server/constants.tsx`
- `admin/Dockerfile`, `admin/src/api.ts`
- `swappify-social-hub/Dockerfile` (the correctly-wired reference pattern)

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~45 minutes
