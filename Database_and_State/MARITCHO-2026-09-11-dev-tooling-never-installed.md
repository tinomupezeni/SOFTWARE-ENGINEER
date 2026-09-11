# Dev Tooling (Ruff/MyPy/Pytest) Declared But Never Installed — Standards Were Never Actually Enforced

**Date:** 2026-09-11
**Project:** Maricho
**Environment:** Development
**Severity:** Medium
**Status:** Fully Resolved

## Summary
`backend/pyproject.toml` declares `ruff`, `mypy`, `pytest`,
`pytest-asyncio`, and `httpx` under `[project.optional-dependencies].dev`,
and `engineering_standards.md` mandates `ruff check .` / `mypy .` pass
before every commit. None of these packages were actually installed in
`backend/venv` — meaning every commit so far, including the ones marked
`DONE` in `docs/backlog.md`, went in without the linting/type-checking gate
the standards doc requires ever having run.

## Symptoms
- `ruff` / `mypy` not found in `backend/venv/bin`.
- Running `ruff check .` for the first time surfaced 42 pre-existing
  errors across `main.py`, `auth.py`, `database.py`, `redis.py`,
  `telemetry.py`, and the initial migration — none introduced this session.
- `mypy app` fails immediately with "Source file found twice under
  different module names: 'database' and 'app.database'" — a `mypy`
  configuration issue (missing `--explicit-package-bases` or a namespace
  package setup) that would need fixing before `mypy` could run at all,
  even after installing it.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** dev tooling only, no runtime impact
- **Related Components:** `pyproject.toml`, `backend/venv`
- **Time First Observed:** 2026-09-11, attempting to lint schema changes
  made in this session before considering them done

## Investigation Steps

### 1. Initial Diagnosis
Tried `ruff check .` / `mypy app` per `engineering_standards.md` before
finishing this session's schema work; both commands were missing.

### 2. Root Cause Analysis
`pip install -e ".[dev]"` also fails outright (setuptools can't
auto-discover packages — multiple top-level dirs with no `packages`/`src`
layout configured), so even the "correct" install path is broken. Installed
the five dev packages directly (`pip install ruff mypy pytest
pytest-asyncio httpx`) as a workaround to be able to lint this session's
changes; this does not fix the underlying `pyproject.toml` packaging issue.

## Root Cause
`BACK-001` ("Initialize FastAPI project structure with strict linting") was
marked `TODO` in the backlog at the time other Sprint-1 items were marked
`DONE` — the linting setup was never actually completed, so nothing ever
installed or ran these tools.

## Solution

### Immediate Fix
Installed `ruff`, `mypy`, `pytest`, `pytest-asyncio`, `httpx` directly into
`backend/venv` (not editable-install, to sidestep the packaging error) and
used `ruff check --fix` to clean the files touched in this session's schema
work (`app/models.py`, the two new migrations).

### Long-term Fix
Done in a later session (2026-09-11, "tackle mypy and lint debt"):
- Fixed the `mypy` dual-module-name error by adding `backend/app/__init__.py`
  — see `2026-09-11-mypy-strict-blocked-by-legacy-orm-style.md` for the full
  fix (also required migrating `models.py` off legacy `Column()` to
  `Mapped[]`/`mapped_column()`).
- Triaged and fixed every pre-existing `ruff` finding across `main.py`,
  `auth.py`, `database.py`, `redis.py`, `telemetry.py`, `migrations/env.py`,
  and the initial migration. `ruff check .` and `mypy .` are both now clean
  (0 errors) across the entire `backend/` tree, including `tests/` and
  `migrations/`.

Finished in a further session (same day, "tackle them both" — packaging +
CI):
- Fixed `pyproject.toml` packaging: added a `[build-system]` table
  (`setuptools>=68`) and `[tool.setuptools.packages.find] include =
  ["app*"]` to stop setuptools from trying to auto-discover packages across
  `migrations/`, `tests/`, and (critically) `venv/`. `pip install -e
  ".[dev]"` now works cleanly — verified end to end.
- Added `.github/workflows/backend-ci.yml`: Postgres 15 + Redis 7 service
  containers, then `ruff check .` → `mypy .` → `alembic upgrade head` +
  `alembic check` (drift gate) → `pytest --cov` (85% gate via new
  `[tool.coverage]` config, enforced through `pytest-cov`).
- Validated the whole pipeline by hand against **genuinely fresh** Postgres/
  Redis containers on non-default ports (not the long-lived local dev
  containers) — this is what caught
  `2026-09-11-test-admin-dsn-hardcoded-and-password-masked.md`, a real bug
  that would have made the very first CI run fail despite every test
  passing locally.
- Added `*.egg-info/` and `.coverage` to `.gitignore` (new artifacts from
  the editable install and coverage runs).

## Prevention
- [x] All 42 original `ruff` findings fixed; `mypy .` clean strict
- [x] `pip install -e ".[dev]"` fixed and verified
- [x] CI workflow added and validated against fresh containers (not just
  the already-migrated local dev DB)
- [ ] `BACK-001` can now genuinely be marked `DONE` — linting, typing, and
  tests are enforced in CI, not just passing when run by hand locally

## Related Issues
- [[2026-09-11-mypy-strict-blocked-by-legacy-orm-style]]
- [[2026-09-11-test-admin-dsn-hardcoded-and-password-masked]]

---

**Resolved By:** Claude Code (backend schema audit → mypy/lint cleanup → packaging/CI)
**Time to Resolution:** Same day, across three sessions
