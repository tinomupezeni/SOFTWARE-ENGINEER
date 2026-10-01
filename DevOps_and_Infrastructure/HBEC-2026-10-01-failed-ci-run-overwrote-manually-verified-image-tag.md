# A Failed Staging CI Run Silently Overwrote a Manually-Verified Production-Bound Image Tag

**Date:** 2026-10-01
**Project:** HBEC
**Environment:** Production (promotion process)
**Severity:** High
**Status:** Resolved (caught before reaching production)

## Summary
During a full-catchup production promotion (14 commits), images were
manually built, tested, and tagged `sha-f43f471` on the VPS earlier in the
session. Before using that tag to promote production, a digest comparison
against the actually-running `-staging` containers found the tag no longer
pointed at the verified build: a failed GitHub Actions "Deploy to Staging"
run had progressed far enough to rebuild and retag images under that same
`sha-<commit>` convention before ultimately failing later in its own
pipeline, silently overwriting the earlier manual tag.

## Symptoms
- No alert, no error — the tag `sha-f43f471` existed and looked correct by
  name for all 10 canonical images.
- Comparing `docker inspect --format='{{.Image}}'` on 5 spot-checked
  `-staging` containers against `docker inspect --format='{{.Id}}'` on the
  `sha-f43f471` tag showed all 5 were different digests.

## Environment Details
- **Server/Host:** Production VPS (`/opt/hbec`, shared Docker daemon with
  staging)
- **Services Affected:** All 10 canonical service images (any image tagged
  under the `sha-<commit>` convention)
- **Related Components:** GitHub Actions `cd.yml` staging deploy job, manual
  promotion process, shared Docker daemon between staging and production
- **Time First Observed:** During this promotion, caught before any
  production container was recreated from the stale tag

## Investigation Steps

### 1. Initial Diagnosis
Per standing process, verified the production-bound tag against the running
staging containers before using it — a deliberate check, not triggered by
any visible failure.

### 2. Root Cause Analysis
Checked out the failed "Deploy to Staging" Actions run
(`gh run view 36829670383`) and confirmed it had reached the image build/tag
step for several services before failing later at
"Build and Deploy Staging on VPS" — meaning it rebuilt and retagged images
under the exact same `sha-f43f471` tag the manual promotion process had
already built and verified earlier in the session.

### 3. Key Findings
- `sha-<commit>` is not a unique, write-once identifier in this setup — any
  process (manual or CI) that builds for the same commit can retag it,
  overwriting whichever build was there first.
- This is the same risk class already documented in a prior incident:
  `HBEC-2026-09-21-staging-prod-shared-docker-tag-near-miss.md` — staging
  and production share one Docker daemon and the same image repo paths, so
  a tag is never scoped to "the build I verified," only to "the build that
  wrote this name most recently."

```bash
# Digest comparison that caught the collision
docker inspect --format='{{.Image}}' hbec-student-backend-staging
docker inspect --format='{{.Id}}' ghcr.io/rest-creator/hbec-student-backend:sha-f43f471
# → different digests, despite matching tag name
```

## Root Cause
A `sha-<commit>` tag is mutable and shared between any build process
targeting that commit. A failed CI run that got far enough to retag images
(but not far enough to finish deploying them) left a different, less-tested
build sitting under the tag name the manual promotion process intended to
trust.

## Prevention / Rule
**Guardrail:** Before using any `sha-<commit>`-tagged image to promote
production, verify its digest against the actually-running, already-behaviorally-verified
`-staging` container — never trust the tag name alone. This promotion
captured the real running digests directly from the live `-staging`
containers and retagged them explicitly as `prod-promote-<commit>` before
using them, which cannot be silently overwritten by an unrelated process
using the standard `sha-<commit>` naming.

This closes the specific gap because the failure mode is a name collision,
not a bad build — pinning promotion to a digest captured from a running,
verified container sidesteps the collision entirely regardless of what any
other process does to the shared tag afterward.

## Solution

### Immediate Fix
Captured actual running image digests from the verified `-staging`
containers and retagged each explicitly as
`ghcr.io/rest-creator/hbec-<service>:prod-promote-f43f4711`, re-verified
these new tags matched the running digests exactly, and used only those for
the production promotion.

```bash
for svc in student-backend student-frontend admin-backend admin-frontend harness harness-ml notifications; do
  digest=$(docker inspect --format='{{.Image}}' "hbec-${svc}-staging")
  docker tag "$digest" "ghcr.io/rest-creator/hbec-${svc}:prod-promote-f43f4711"
done
```

### Long-term Fix
No code change made to `cd.yml` in this session — flagged as a process gap.
A durable fix would have the staging deploy job tag images with something
that can't collide with a manual rebuild of the same commit (e.g. a run-id
suffix, or refusing to overwrite an existing `sha-<commit>` tag), but that
is CI pipeline work, not something this promotion touched.

## Prevention
- [ ] Configuration changes needed: consider making `cd.yml`'s image tagging
      step refuse to overwrite an existing `sha-<commit>` tag, or suffix with
      a run id, so a failed/retried CI run cannot silently replace a
      different build under the same name.
- [ ] Monitoring/alerts to add: none added this session.
- [x] Documentation to update: this entry, cross-referencing the prior
      09-21 near-miss, so the pattern is recognized faster next time.
- [ ] Code changes required: none to application code; the fix was process
      (digest-pinning), not code.

## Related Issues
- `HBEC-2026-09-21-staging-prod-shared-docker-tag-near-miss.md` — same risk
  class, documented previously as a near-miss rather than a caught-in-the-act
  collision.

## References
- `reports/HBEC-2026-10-01-full-catchup-production-promotion.md`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Caught and worked around within the same promotion session, before any production container used the stale tag.
