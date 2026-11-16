# schools-backend/schools-dashboard shipped without the same deploy verification as the rest of the fleet

**Date:** 2026-11-16
**Project:** HBEC
**Environment:** Development source review; DNS checked live from a sandbox with outbound network access
**Severity:** Medium
**Status:** Resolved

## Summary
`schools-backend`/`schools-dashboard` were added to the blue-green pipeline
after the other 10 services (images, compose blue/green pairs, and Caddy
routes all exist and are correct), but four pieces of deploy verification
that the rest of the fleet gets were never finished for it:

1. No `healthcheck:` on any of `schools-backend`, `schools-backend-blue`,
   `schools-backend-green`, `schools-dashboard`, `schools-dashboard-blue`,
   `schools-dashboard-green` in `docker-compose.production.yml` — so
   `deploy-color`'s `up -d --wait --wait-timeout 420` had nothing to wait
   on for this service; Docker reports "running" the instant the process
   starts, never "healthy."
2. `scripts/deploy/verify-service-links.sh` explicitly deferred a
   `link_check` module for schools-backend ("checked during the blue-green
   rollout... new application code, not a config change") and never added
   one — so the post-deploy signed-link verification every other service
   gets doesn't cover the one outbound signed link schools-backend makes
   (the student-sync call fired by bulk import).
3. `SCHOOLS_ADMIN_SECRET` (admin → schools) was in `preflight-secrets.sh`,
   `cd.yml`'s GitHub-secrets forwarding, and the first-deploy bootstrap
   generator — but `SCHOOLS_TO_STUDENT_SECRET` (schools → student) was in
   none of the three, despite compose requiring it
   (`:?Set SCHOOLS_TO_STUDENT_SECRET in .env`).
4. `school-api.hbca.tech` does not resolve in **production**, not just the
   already-logged staging case
   (`HBEC-2026-11-06-staging-school-api-dns-missing.md`) — confirmed live
   with `getent hosts school-api.hbca.tech` (no answer) vs.
   `getent hosts school.hbca.tech` (resolves to 209.209.42.142, the VPS).
   `scripts/deploy/render-caddyfile.sh` rendered a site block for it, but
   no caller actually needed a dedicated hostname: `school.hbca.tech`'s own
   `/api/*` handle already proxies the identical backend, and does resolve.

## Symptoms
- No user-visible symptom yet — found during a deliberate audit prompted
  by the observation that this deploy pipeline doesn't treat schools the
  same as everything else.
- The real-world risk each gap leaves open: (1) a broken schools-backend
  container could pass `deploy-color` as "deployed" with no health signal;
  (2) a partial deploy that leaves schools-backend signing with a stale
  secret would 403 silently rather than failing the deploy; (3) a fresh
  VPS bootstrap (disaster recovery) would start a compose stack missing a
  required env var and fail to come up, loudly but avoidably; (4) anyone
  given `school-api.hbca.tech` as the schools API hostname gets
  `Could not resolve host`.

## Environment Details
- **Server/Host:** Local checkout; DNS checked from a sandboxed environment
  with outbound network access (`getent hosts`).
- **Services Affected:** DevOps/Infrastructure (blue-green deploy pipeline).
- **Related Components:** `docker-compose.production.yml`,
  `scripts/deploy/verify-service-links.sh`,
  `scripts/deploy/preflight-secrets.sh`, `.github/workflows/cd.yml`,
  `scripts/deploy/render-caddyfile.sh`,
  `scripts/deploy/{manual-cutover,manual-rollback-cutover}.sh`.
- **Time First Observed:** 2026-11-16, prompted by a question about whether
  the school dashboard needed its own repo/pipeline — the answer required
  first checking whether its coverage in the *existing* pipeline was real.

## Investigation Steps

### 1. Initial Diagnosis
Grepped `docker-compose.production.yml`, `cd.yml`, `verify-service-links.sh`
and `preflight-secrets.sh` for `schools` / `SCHOOLS` to see exactly what
coverage exists versus the other 10 production services.

### 2. Root Cause Analysis
Schools was clearly bolted onto an already-mature pipeline: the build/route/
compose layer is complete and correct, but each piece of *verification*
infrastructure (healthchecks, link checks, secret preflight, DNS) was added
incrementally for the original service set and schools never received its
own pass through any of them.

### 3. Key Findings
- `render-caddyfile.sh`'s own comments describe `staging-*.hbca.tech` as
  "real DNS, reused from retired staging" — the production `*-api`
  hostname pattern was evidently never given the same DNS setup pass the
  non-`-api` hostnames got.
- `staging-school.hbca.tech` and `school.hbca.tech` both resolve; only the
  `-api` variants (both staging and production) don't — consistent with
  the dashboard's own-domain route having been set up, and the dedicated
  API hostname route never being.

## Root Cause
Schools (`SCHOOLS/schools_backend`, `SCHOOLS/school_dashboard`) was
integrated into an existing, already-mature blue-green deploy pipeline
after the fact, and the integration stopped at "it builds, routes, and
starts" without a corresponding pass through each verification layer that
exists for the rest of the fleet.

## Prevention / Rule
**Guardrail:** `scripts/deploy/check-dns-resolution.sh` now resolves every
`*.hbca.tech` hostname rendered into the live Caddyfile after every
render (`cutover`, `rollback-cutover`, and their manual stand-ins) and
emits a loud, non-blocking `::warning::` naming any that don't answer —
this is exactly the "proxy-correct, DNS-silent" failure mode this gap was.
For the other three: `RunImportTests`/`HealthCheckTests` in
`institutions/tests.py` and the existing `test_deploy_checks.py` suite now
exercise the new healthcheck endpoint and secret coverage directly.

This turns "schools quietly lacks the same verification as everything
else" into something that shows up in a deploy's own output, rather than
something that has to be rediscovered by audit again.

## Solution

### Immediate Fix
1. Added `/health/live/` (`institutions/health.py`) and wired a
   `healthcheck:` into all six schools-backend/schools-dashboard compose
   service definitions.
2. Added `institutions/management/commands/check_service_links.py`
   (mirroring the admin/student backends' own commands) and wired it into
   `verify-service-links.sh`'s `CHECKS` array.
3. Added `SCHOOLS_TO_STUDENT_SECRET` to `preflight-secrets.sh`'s `SECRETS`
   array, `cd.yml`'s GitHub-secrets forwarding (`env:` + `envs:`), and its
   first-deploy bootstrap generator, matching `SCHOOLS_ADMIN_SECRET`'s
   existing pattern exactly.
4. Added `scripts/deploy/check-dns-resolution.sh`, wired as a non-blocking
   warning into `cd.yml`'s `cutover`/`rollback-cutover` jobs and the manual
   stand-in scripts.

### Long-term Fix
Initially tracked as "create the missing DNS records" (a registrar action,
not a code change). Revisited once it was clear nothing actually needed the
dedicated `-api` hostname: `school.hbca.tech`'s/`staging-school.hbca.tech`'s
own `/api/*` handles already serve the same backend and already resolve.
Removed `school-api.hbca.tech`/`staging-school-api.hbca.tech`'s site blocks
from `render-caddyfile.sh` and their `ALLOWED_HOSTS` entries in
`schools_backend/settings/production.py` instead of chasing DNS for an
alias nothing used; updated `openapi/schools.yml`'s server URLs to the
domains that actually work. `check-dns-resolution.sh` stays as the
guardrail for the next hostname this happens to.

## Prevention
- [x] Healthcheck added to all six schools compose services.
- [x] schools-backend link-check module added and wired in.
- [x] `SCHOOLS_TO_STUDENT_SECRET` added to preflight, secrets forwarding,
      and bootstrap generation.
- [x] DNS-resolution guardrail added to every cutover/rollback path.
- [x] Dead `-api` hostnames removed from Caddy config, `ALLOWED_HOSTS`, and
      the OpenAPI contract, rather than requesting DNS records nothing needed.

## Related Issues
- `HBEC-2026-11-06-staging-school-api-dns-missing.md` — this entry extends
  that finding to production and adds the guardrail its own "Prevention /
  Rule" section proposed but never implemented.

## References
- `docker-compose.production.yml` (schools service definitions)
- `scripts/deploy/check-dns-resolution.sh`
- `scripts/deploy/verify-service-links.sh`
- `scripts/deploy/preflight-secrets.sh`
- `.github/workflows/cd.yml`
- `SCHOOLS/schools_backend/institutions/health.py`
- `SCHOOLS/schools_backend/institutions/management/commands/check_service_links.py`

---

**Resolved By:** Local code fix, 2026-11-16
**Time to Resolution:** Same session as discovery
