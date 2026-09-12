# Ruff `B008` Flagged Every FastAPI `Depends(...)` Default as a Bug, Making Real Lint Adoption Impossible

**Date:** 2026-09-11
**Project:** Maricho
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
While implementing the CORE-001 job-request endpoint and running `ruff
check` for the first time (see the separate
`2026-09-11-dev-tooling-never-installed.md` finding), every single existing
FastAPI endpoint using the standard `Depends(...)` default-argument pattern
(`auth.py`, `main.py`, and the new `routers/jobs.py`) tripped `flake8-bugbear`
rule `B008` ("Do not perform function call in argument defaults"). That
pattern is FastAPI's documented, idiomatic way to declare dependencies —
not a bug — but with the project's `pyproject.toml` `ruff` config as
written, it's flagged on every endpoint in the codebase, which would drown
any real signal in noise the moment linting is actually enforced.

## Symptoms
- `ruff check .` reported 6+ `B008` errors on pre-existing code
  (`auth.py:31`, `auth.py:58`, `main.py` x6) and would have reported the
  same on every new endpoint in `routers/jobs.py`.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** lint tooling only (`pyproject.toml`)
- **Time First Observed:** 2026-09-11, building CORE-001

## Investigation Steps

### 1. Initial Diagnosis
Confirmed `Depends(...)` and this project's own `RequireRole(...)` callable
are both meant to be evaluated at declaration time per-request by FastAPI's
DI system — this is the documented pattern, not the mutable-default-argument
bug `B008` exists to catch.

### 2. Root Cause Analysis
`ruff`'s `flake8-bugbear` plugin supports `extend-immutable-calls` to
whitelist specific callables as safe in argument defaults, but
`pyproject.toml` had never configured it — the linting setup was written
without ever actually being run against the codebase (consistent with the
broader "dev tooling never installed" finding).

## Root Cause
Missing `[tool.ruff.lint.flake8-bugbear]` configuration; no one had run
`ruff` against this codebase before to notice.

## Prevention / Rule
**Guardrail:** Require `ruff check .` to actually run in CI starting from
the same commit that adds `ruff` to `pyproject.toml` — a lint tool declared
as a dev dependency but never executed against the codebase provides zero
signal, whatever its configuration claims.

This is the same "Potemkin tooling" gap named in the companion
`2026-09-11-dev-tooling-never-installed.md` finding: the missing
`extend-immutable-calls` entry was invisible for exactly as long as nobody
ran the tool it belongs to.

## Solution

### Long-term Fix
Added to `backend/pyproject.toml`:
```toml
[tool.ruff.lint.flake8-bugbear]
extend-immutable-calls = ["fastapi.Depends", "app.auth.RequireRole"]
```
Verified `ruff check` no longer flags any `Depends(...)`/`RequireRole(...)`
usage in `auth.py`, `main.py`, or the new `routers/jobs.py`.

## Prevention
- [x] Config fixed and verified
- [ ] The remaining ~30 non-`B008` findings from the first real `ruff run`
  (import ordering, `B904`, line length) are still open — tracked in
  `2026-09-11-dev-tooling-never-installed.md`.

## Related Issues
- [[2026-09-11-dev-tooling-never-installed]]

---

**Resolved By:** Claude Code (CORE-001 implementation)
**Time to Resolution:** Same session
