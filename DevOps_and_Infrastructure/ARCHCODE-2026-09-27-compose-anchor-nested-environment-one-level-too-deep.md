# Compose anchor aliased a whole map into `environment`, nesting it one level too deep

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
While adding `api` and `admin` services to `docker-compose.yml`, the YAML anchor was attached to
the wrong node. `x-app-env: &app-env` held both `env_file` and `environment`, and
`environment: *app-env` therefore resolved `environment` to the *whole* pair — producing
`environment: {env_file: [...], environment: {...}}`. Compose rejected the file. Caught by
`docker compose config` before any container was built, and the fix is one line, but the class of
error is worth recording because the failure message points at neither the anchor nor the alias.

## Symptoms
```
validating docker-compose.yml: services.api.environment.env_file must be a
boolean, null, number or string
```

`docker compose config --quiet` failed; the stack would not come up at all.

## Environment Details
- **Server/Host:** local dev, `runner/`
- **Services Affected:** the containerised stack (both app services)
- **Related Components:** `docker-compose.yml`
- **Time First Observed:** 2026-09-27, on first validation after adding the services

## Investigation Steps

### 1. Initial Diagnosis
The error names `services.api.environment.env_file`, which is not a key anyone wrote under
`environment:`. That is the tell: something resolved into the wrong level of nesting.

### 2. Root Cause Analysis
```yaml
x-app-env: &app-env          # anchors the WHOLE map
  env_file:
    - .env
  environment:
    ARCHCODE_DB_HOST: db

x-app-common: &app-common
  environment: *app-env      # so `environment` == {env_file: ..., environment: ...}
```

YAML anchors capture whatever node they are attached to. `&app-env` sat on the two-key map, not
on the environment mapping, so the alias substituted the pair instead of the inner map.

### 3. Key Findings
- `env_file` is a **compose-level** key, not an environment variable. Grouping it with
  `environment:` under one anchor made the mistake easy to write and impossible to read back.
- The error message mentions neither the anchor (`x-app-env`) nor the alias site, so it reads as
  a schema problem in the service definition rather than in the merge.
- `docker compose config --quiet` is a fast, complete check for this class of error and caught it
  in under a second — before a build that would have taken minutes.

## Root Cause
Anchoring a composite map and aliasing it into a position that expects only part of that map.
Compose merged it faithfully; the structure was simply wrong one level down.

## Prevention / Rule
**Guardrail:** Anchor only the exact node a consumer expects. When a service field needs
`{VAR: value}`, the anchor must be attached to that mapping and nothing else — keep `env_file`
(outside `environment`) as its own line rather than folding it into a shared anchor.

Run `docker compose config --quiet` in the verification set. It validates merges, anchors and
profiles in about a second, and it is the only check that sees this before a build.

## Solution

### Immediate Fix
Anchored just the environment mapping, and moved `env_file` out of the shared block onto the one
service that is not part of the common anchor (`migrate`, which cannot depend on itself):

```yaml
x-app-environment: &app-environment
  ARCHCODE_DB_HOST: db

x-app-common: &app-common
  env_file:
    - .env
  environment: *app-environment
```

### Long-term Fix
`docker compose config --quiet` is part of this project's verification set, alongside ruff,
`manage.py check` and the test suite.

## Prevention
- [x] Anchor scoped to the environment mapping only
- [x] `env_file` stated explicitly where it belongs
- [x] `docker compose config --quiet` passes; all four services resolve
- [ ] Add `docker compose config --quiet` to the documented verification commands in the README
      and to CI when CI exists

## Related Issues
- `reports/ARCHCODE-2026-09-27-runner-stack-and-repository.md`

## References
- YAML anchors alias the node they are declared on, not a sub-key of it
- Compose validates and merges the whole file with `docker compose config`

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~5 minutes
