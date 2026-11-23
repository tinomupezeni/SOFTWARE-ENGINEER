# Blue/green deploy to the second color failed: singleton containers owned by the wrong Compose project

**Date:** 2026-11-23
**Project:** HBCA Classroom
**Environment:** Production (hbca-vps, live user traffic — this surfaced right after the first real cutover)
**Severity:** Critical
**Status:** Resolved

## Summary
The first deploy (`blue`) succeeded completely — built, migrated, cut over, serving real signups. The very next deploy, to `green`, failed immediately: `Conflict. The container name "/hbca-classroom-minio" is already in use by container ...`.

## Symptoms
- `docker compose up -d` for `green` failed on the `minio` service with a container-name conflict, before creating any `green`-specific containers.
- `blue` itself was unaffected and kept serving traffic throughout — the failure was isolated to standing up the second color.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** hbca-classroom-minio (and, structurally, postgres/redis — same root cause, same risk)
- **Related Components:** `ops/deploy/deploy-color.sh`, `ops/deploy/docker-compose.production.yml`
- **Time First Observed:** 2026-11-23, second deploy (triggered by a docs-only PR merge, not a deliberate test — any second deploy would have hit this)

## Investigation Steps

### 1. Initial Diagnosis
`blue`'s deploy had created `postgres`/`redis`/`minio` under Compose project `hbca-classroom-blue` (the per-color project), because `deploy-color.sh` brought up the whole stack — singletons and colored app tier alike — in one `up -d` call scoped to that project.

### 2. Root Cause Analysis
Docker Compose identifies a service by `(project name, service name)`, and uses `container_name` (when set) as the literal Docker-level name. `postgres`/`redis`/`minio` have fixed `container_name`s (no `${COLOR}` in them — they're meant to be shared, not duplicated per color). When `green`'s deploy ran `up -d postgres redis minio backend frontend` under project `hbca-classroom-green`, Compose tried to create "its own" `postgres`/`redis`/`minio` containers under the new project — but Docker refuses two containers with the identical literal name regardless of which Compose project asked for it.

### 3. Key Findings
- This didn't surface on the first deploy because the singletons didn't exist yet — any project name "wins" when creating from nothing.
- VLabs and HBEC, on this same host, avoid this entirely by keeping each project's genuinely stateful singletons (where they have any) outside the blue/green pair's own compose invocation, or coloring nothing that's meant to be shared.

## Root Cause
Mixing truly shared, singleton resources into the same Compose project scope as the per-color, intentionally-duplicated resources.

## Prevention / Rule
**Guardrail:** In any blue/green Compose setup, never bring up a service with a fixed (non-colored) `container_name` under a per-color (or otherwise per-deploy) project name. Shared/singleton services belong to their own fixed project, brought up once, idempotently, by every deploy regardless of color; only truly duplicated (one instance per color) services belong to the per-color project, and should be started with `--no-deps` so Compose never tries to auto-start their dependencies under the wrong project.

A second deploy to the *other* color is the natural test this gap would always have been caught by — if a single-color deploy pipeline design is ever re-reviewed, explicitly trace through "what happens on the second color's first-ever deploy," not just the first.

## Solution

### Immediate Fix
Split `deploy-color.sh` into two `docker compose` invocations: a fixed `DATA_PROJECT="hbca-classroom-data"` for `postgres`/`redis`/`minio`, and the existing per-color `PROJECT` for `backend`/`frontend` only, both the `up -d` and the migration `run --rm` call now passing `--no-deps`.

### Long-term Fix
None further — this is the correct shape for a shared-singleton blue/green setup.

## Prevention
- [x] Configuration changes needed — script restructured
- [ ] Monitoring/alerts to add
- [x] Documentation to update — `docs/deploy/RUNBOOK.md`
- [x] Code changes required

## Related Issues
- Discovered and fixed as part of the same deploy-pipeline bring-up as every other `HBCA-2026-11-23-*` entry in this folder.

## References
- `ops/deploy/deploy-color.sh`, `ops/deploy/docker-compose.production.yml`

---

**Resolved By:** Claude (session with tinomupezeni)
**Time to Resolution:** ~25 minutes (including live verification with a brief, deliberate, approved downtime window for the singleton migration)
