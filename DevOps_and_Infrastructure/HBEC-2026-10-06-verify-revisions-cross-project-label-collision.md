# `verify-revisions.sh` false-flags a healthy deploy when a dry-run project shares service-name labels

**Date:** 2026-10-06
**Project:** HBEC
**Environment:** Production (`hbca-vps`)
**Severity:** Low (false alarm only — the real deploy was correct; no bad code ever reached traffic)
**Status:** Resolved (workaround identified; script fix not yet applied)

## Summary
New script `scripts/deploy/verify-revisions.sh` (merged today via the
experimental -> master PR, part of the gated blue-green deploy tooling)
proves every container in a deploy's target services is running the
expected commit, by filtering running containers on the
`com.docker.compose.service` label. On this VPS, an isolated dry-run stack
(`/sdb-disk/hbec-bluegreen/`, compose project `hbec-bluegreen`, containers
`bg-admin-backend-blue` / `bg-student-backend-blue`, left running from
earlier blue-green proof-of-concept work) happens to use the *exact same*
service-name labels (`admin-backend-blue`, `student-backend-blue`) as the
real production blue/green pair. The script's filter doesn't scope by
compose *project*, so it matched both the real container and the unrelated
dry-run one, and failed the whole check because the dry-run container
(carrying no `org.opencontainers.image.revision` label at all) reported
`unknown`.

## Symptoms
- After a real, successful blue build+up (commit `c47ab23`, all 9 real
  `hbec-*-blue` containers healthy and on the right commit), running
  `verify-revisions.sh c47ab23 <services>` printed:
  ```
  [verify-revisions] student-backend-blue: c47ab23
  [verify-revisions] student-backend-blue: running 'unknown', expected c47ab23
  [verify-revisions] admin-backend-blue: c47ab23
  [verify-revisions] admin-backend-blue: running 'unknown', expected c47ab23
  [verify-revisions] FAILED - not every container is on c47ab23
  ```
  i.e. two services each reported *two* results, one correct and one not.

## Environment Details
- **Server/Host:** `hbca-vps`
- **Services Affected:** none for real — this is a verification tool false
  positive, not a production issue. Would have blocked (or, in CI, failed)
  a legitimate deploy had this been treated as gospel without investigation.
- **Related Components:** `scripts/deploy/verify-revisions.sh`,
  `/sdb-disk/hbec-bluegreen/docker-compose.bluegreen.yml` (the isolated
  dry-run stack from earlier blue-green rollout planning, still running)
- **Time First Observed:** 2026-10-06, first real-world run of this
  brand-new script (merged same day) against production

## Investigation Steps

### 1. Initial Diagnosis
Re-ran the check scoped directly to the real `hbec-`-prefixed container
names (bypassing the script's label-based lookup) and confirmed all 9 were
genuinely on `c47ab23` — the deploy itself was fine.

### 2. Root Cause Analysis
```bash
docker inspect bg-admin-backend-blue bg-student-backend-blue \
  --format '{{.Name}}: project={{index .Config.Labels "com.docker.compose.project"}} service={{index .Config.Labels "com.docker.compose.service"}} revision={{index .Config.Labels "org.opencontainers.image.revision"}}'
# /bg-admin-backend-blue: project=hbec-bluegreen service=admin-backend-blue revision=unknown
# /bg-student-backend-blue: project=hbec-bluegreen service=student-backend-blue revision=unknown
```
Confirmed: same `com.docker.compose.service` value as the real production
service, different `com.docker.compose.project`. `verify-revisions.sh`'s
`docker ps -q --filter "label=com.docker.compose.service=${service}"` has
no project filter, so it returns both.

### 3. Key Findings
- This is specific to this VPS's history (an isolated dry-run stack with
  deliberately matching service names was left running for exactly this
  kind of future verification work) — it would not reproduce on a fresh
  host, but it will recur every time this script runs here until either the
  script is fixed or the dry-run stack is retired.

## Root Cause
`verify-revisions.sh` identifies "the containers for this service" by one
label (`com.docker.compose.service`) that is not guaranteed unique across
compose projects on the same Docker host, instead of pairing it with
`com.docker.compose.project` (or simply requiring the container name
prefix, as every other script in this deploy pipeline already does).

## Prevention / Rule
**Guardrail:** fix `verify-revisions.sh` to also filter on
`label=com.docker.compose.project=hbec` (or match container names by the
`hbec-` prefix the way `verify-service-links.sh` and every manual check
this session already does) — not yet applied, since this is a borrowed
script from the just-merged PR and the fix belongs with that tooling's
owner, not as a drive-by edit mid-deploy. Tracked as a follow-up.

## Solution

### Immediate Fix
None needed for this deploy — verified directly against the real container
names instead of trusting the script's output, confirmed all 9 real blue
containers correct, proceeded.

### Long-term Fix
Not yet applied. Proposed: add `--filter "label=com.docker.compose.project=hbec"`
to `verify-revisions.sh`'s `docker ps` call, or accept only containers whose
name starts with `hbec-`. Either closes this permanently; the latter also
matches every sibling script's existing convention.

## Prevention
- [ ] Patch `verify-revisions.sh` to scope by project or name prefix
- [ ] Decide whether to retire `/sdb-disk/hbec-bluegreen/`'s leftover
      `bg-admin-backend-blue` / `bg-student-backend-blue` containers now
      that the real blue-green mechanism is live in production — they were
      proof-of-concept only and may no longer be needed
- [ ] Re-run `verify-revisions.sh` after the fix to confirm it reports
      clean on a real deploy without manual workaround

## Related Issues
- None directly, but this is the same class of gap (a check that assumes
  single-tenancy on a host that actually runs multiple parallel
  environments) as the Caddyfile git-tracking near-miss earlier this
  session.

## References
- `scripts/deploy/verify-revisions.sh`
- `/sdb-disk/hbec-bluegreen/docker-compose.bluegreen.yml`

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Diagnosed and worked around within the same deploy,
real fix deferred to a follow-up patch.
