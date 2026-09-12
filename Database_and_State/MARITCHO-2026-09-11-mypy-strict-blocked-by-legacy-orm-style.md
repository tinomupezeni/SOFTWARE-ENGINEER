# mypy `strict = true` Was Unusable: Legacy SQLAlchemy `Column()` Style Plus a Missing `__init__.py`

**Date:** 2026-09-11
**Project:** Maricho
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
`backend/pyproject.toml` has declared `[tool.mypy] strict = true` since the
project's first commit, but `mypy` had never actually been run successfully
(see `2026-09-11-dev-tooling-never-installed.md`). Once actually invoked,
two separate, compounding problems made it fail completely, then made it
report 126 errors even after the first was fixed: a missing `app/__init__.py`
causing a module-identity crash, and `models.py` using SQLAlchemy's legacy
`Column()` declarative style, which mypy sees as `Column[X]` rather than the
actual runtime attribute type `X`.

## Symptoms
- `mypy app` failed immediately: `Source file found twice under different
  module names: "auth" and "app.auth"`.
- After adding `app/__init__.py`, `mypy app` ran but reported 126 errors,
  the bulk being `Incompatible types in assignment (expression has type
  "JobStatusEnum", variable has type "Column[Any]")` — every ordinary
  `job.status = JobStatusEnum.BOOKED`-style assignment across all four
  routers looked like a type error.
- Every model class also errored with `Class cannot subclass "Base" (has
  type "Any")`, since `declarative_base()` returns an untyped base under
  strict mypy.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `mypy` only, no runtime impact
- **Related Components:** `app/models.py`, `app/database.py`,
  `app/__init__.py` (missing), `migrations/env.py`
- **Time First Observed:** 2026-09-11, tackling mypy/lint debt explicitly

## Investigation Steps

### 1. Initial Diagnosis
Ran `mypy app` per the standards doc; hit the dual-module-name crash before
mypy could check a single file.

### 2. Root Cause Analysis
- The dual-module error is mypy's classic symptom of a package with no
  `__init__.py` being resolved two different ways depending on how it's
  imported. Standard fix (from mypy's own error message): add the
  `__init__.py`.
- With that fixed, the flood of `Column[Any]` assignment errors traced to
  `models.py` using `Column(...)` class attributes with no type annotation
  — mypy has no way to know a `Job.status` attribute is really a
  `JobStatusEnum` at the instance level; it just sees the class-level
  descriptor type. SQLAlchemy 2.0's fix for this is the `Mapped[]` +
  `mapped_column()` declarative style, not a Column-only fix.
- Migrating `models.py` also surfaced a subtler issue: `Mapped[datetime]`
  (non-Optional) makes SQLAlchemy 2.0 *infer* `nullable=False` at the DDL
  level. Several `created_at`/`updated_at` columns had only ever had a
  Python-side `default=`, never `nullable=False` — so a naive migration to
  `Mapped[datetime]` would have silently tightened the actual database
  schema. Caught via `alembic check` reporting new `modify_nullable`
  operations; fixed by annotating those specific columns
  `Mapped[datetime | None]` to match the real, pre-existing nullability.
- Separately, `declarative_base()` (legacy factory function) returns `Any`
  under strict mypy; every model subclassing it errors. Fix: switch to the
  `class Base(DeclarativeBase): pass` style in `app/database.py`.
- Also found (via a related mypy re-export check):
  `migrations/env.py` imported `Base` from `app.models`, but `Base` is
  actually defined in `app.database` — it only worked via Python's implicit
  re-export. Fixed to import from its real source, keeping the
  `import app.models` line (needed for its side effect of registering all
  tables on `Base.metadata` before `target_metadata = Base.metadata` runs).

## Root Cause
The project adopted `strict = true` aspirationally without ever running
`mypy`, so nobody noticed the codebase's ORM style (`Column()`, no
`__init__.py`, `declarative_base()`) is fundamentally incompatible with
strict mode until this session actually ran it.

## Prevention / Rule
**Guardrail:** Whenever a stricter static-analysis setting (`mypy strict = true`, a new `ruff` rule set, etc.) is added to a config file for an existing codebase, run it once immediately in the same PR that adds the config — a codebase that can't pass the new setting is blocking evidence the setting doesn't fit yet, not background debt to discover in some later session.

This is distinct from (and a level up from) simply running the tool at all: `strict = true` had been declared since the first commit with nobody ever checking whether the codebase's actual ORM style was even compatible with it.

## Solution

### Long-term Fix
- Added `backend/app/__init__.py`.
- Migrated all 15 model classes in `app/models.py` to `Mapped[]` +
  `mapped_column()`, preserving exact column arguments (types, nullability,
  FKs, defaults) so the migration produced **zero** DDL drift — verified via
  `alembic check` immediately after, plus a full `alembic downgrade base` /
  `upgrade head` round-trip.
- Switched `app/database.py`'s `Base` from `declarative_base()` to
  `class Base(DeclarativeBase): pass`.
- Fixed `migrations/env.py`'s `Base` import to come from `app.database`.
- Added explicit return-type annotations to every route handler and
  dependency across `main.py`, `auth.py`, `redis.py`, `telemetry.py`, and
  all of `app/routers/*.py` (strict's `disallow_untyped_defs`).
- Added a `[[tool.mypy.overrides]]` for `tests.*` relaxing
  `disallow_untyped_defs` / `disallow_untyped_calls` / `disallow_incomplete_defs`
  — full strict annotation coverage on test helpers/fixtures buys little
  and isn't standard practice; everything else in strict still applies to
  test code.
- `mypy .` now reports **0 errors across 37 source files** (`app/`,
  `migrations/`, `tests/`).

## Prevention
- [x] `mypy .` verified clean, `ruff check .` verified clean, full test
  suite (86 tests) verified passing, migrations verified to round-trip
  twice from a clean `base` state
- [ ] Wire both into CI/pre-commit so this can't silently regress (tracked
  in `2026-09-11-dev-tooling-never-installed.md`)

## Related Issues
- [[2026-09-11-dev-tooling-never-installed]]
- [[2026-09-11-initial-migration-downgrade-never-dropped-enum-types]]

---

**Resolved By:** Claude Code (mypy/lint debt cleanup)
**Time to Resolution:** Same session
