# `Skill.grade` and `Standing.grade` Are Both Unconstrained Free-Text Strings — Inconsistent With Every Other Categorical Column

**Date:** 2026-09-11
**Project:** MARITCHO
**Environment:** Development
**Severity:** Medium
**Status:** Resolved (type-safety fix; population workflow tracked separately)

## Summary
Every other categorical column in the schema (`persons.role`,
`jobs.trade`/`status`, `ledger_entries.entry_type`,
`disputes.status`, `crew_orders.status`) is a real Postgres `ENUM` type,
enforced at the database level. `Skill.grade` and `Standing.grade` are the
one exception: both are plain `String(50)` with no `CHECK` constraint and
no shared enum, even though `docs/architecture/database_schema_design.md`
documents one specific taxonomy for both
(`REGISTERED, IDENTIFIED, APPRENTICE, JOURNEYMAN, EXPERT`). Nothing stops a
typo, a different casing, or an arbitrary string from being stored in
either column.

## Symptoms
- `app/models.py`: `Skill.grade: Mapped[str | None] = mapped_column(String(50))`
  and `Standing.grade: Mapped[str | None] = mapped_column(String(50),
  default="REGISTERED")` — both unconstrained.
- `app/matching.py`'s `_GRADE_RANK` dict (`{"REGISTERED": 0, "IDENTIFIED":
  1, ...}`) silently treats any unrecognized string as rank 0 via
  `.get(grade, 0)` — so a typo'd grade doesn't error, it just silently
  scores as the lowest possible standing with no warning.
- No migration ever adds a `CHECK (grade IN (...))` or a dedicated
  `gradeenum` Postgres type, unlike `tradeenum`/`roleenum`/etc.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO/backend`
- **Services Affected:** `app/models.py` (`Skill`, `Standing`)
- **Related Components:** `app/matching.py::_standing_score` (silently
  degrades on bad input rather than failing loudly)
- **Time First Observed:** 2026-09-11, DB normalization review requested
  directly by the user

## Investigation Steps

### 1. Initial Diagnosis
Compared every categorical column's DB-level type against the documented
enum values in `database_schema_design.md`.

### 2. Root Cause Analysis
`grade` is set by `worker_id` registration (`Skill.grade` — currently
never actually set by any endpoint either; `POST /workers/me/skills`
doesn't accept a `grade` field at all, so it's always `NULL` in practice
today) and by `Standing`'s Python-side default. Because nothing ever
writes a `Skill.grade` value yet, the missing constraint hasn't caused a
visible bug — but the column exists, is documented with a specific
taxonomy, and has no enforcement, which is exactly the kind of gap that
becomes a real data-integrity problem the moment a "worker self-reports
grade" or "OPS assigns grade" feature is built.

### 3. Key Findings
- `Skill.grade` is currently dead/always-NULL in practice (no writer
  exists), which is itself worth noting separately from the type-safety
  gap, since it means the "how it was proven" grade the SDD describes for
  skills isn't actually captured anywhere yet.

## Root Cause
`grade` was modeled early (initial migration) as a plain string, and later
categorical columns (`trade`, `status`, etc.) were correctly upgraded to
real Postgres enums as the schema matured — `grade` was never revisited to
match.

## Prevention / Rule
**Guardrail:** A schema-review checklist rule enforced at PR review: any new categorical column that a design doc documents as a fixed taxonomy must use a shared Postgres `ENUM` type or a `CHECK` constraint before merge — a plain `String` column is never acceptable for a documented closed set of values.

This is exactly the gap here: `grade`'s taxonomy was documented in `database_schema_design.md` from the start, but nothing forced the column itself to enforce it, so a typo would have silently scored as the lowest possible standing with no error.

## Solution

### Immediate Fix
Implemented in a follow-up session (same day) — the type-safety half of
this finding, which needed no product decision:
- `app/models.py`: new `GradeEnum(str, enum.Enum)` with the documented
  taxonomy (`REGISTERED, IDENTIFIED, APPRENTICE, JOURNEYMAN, EXPERT`).
  `Skill.grade` and `Standing.grade` both changed from
  `Mapped[str | None] = mapped_column(String(50))` to
  `Mapped[GradeEnum | None] = mapped_column(Enum(GradeEnum))` (Standing's
  keeps its Python-side `default=GradeEnum.REGISTERED`).
- Migration `6d1158370df3`: `CREATE TYPE gradeenum AS ENUM (...)`, then
  `ALTER COLUMN ... TYPE gradeenum USING grade::gradeenum` for both
  tables. Written as raw SQL (`op.execute`) rather than SQLAlchemy `Enum`
  objects, per this project's established pattern for enum migrations.
- Hit and fixed a real bug while round-trip testing (not a hypothetical):
  the first downgrade/upgrade cycle failed with `default for column
  "grade" cannot be cast automatically to type gradeenum`. Root cause:
  my first downgrade draft re-added a `SET DEFAULT 'REGISTERED'` (as
  plain varchar) that never existed in the original schema in the first
  place (`Standing.grade`'s `default=` is a Python/ORM-side default only,
  never a `server_default` — confirmed by reading the original initial
  migration, which never set one). That stray varchar default then broke
  the *next* upgrade's `ALTER TYPE`, since Postgres can't auto-cast an
  existing varchar default to an enum type. Fixed by removing the
  erroneous `SET DEFAULT` from both directions of the migration, and by
  manually cleaning the already-corrupted dev DB in place before
  retrying. Re-verified: `alembic downgrade -1` → `alembic upgrade head`
  → `alembic check` all clean this time, and confirmed via `\d skills` /
  `\d standings` that both columns are physically `gradeenum` in Postgres.
- Propagated the type change everywhere `grade` flows: `app/matching.py`
  (`_GRADE_RANK` keys, `_DEFAULT_GRADE`, `_standing_score`'s parameter
  type), `app/schemas.py` (`MatchCandidateOut.grade`, `SkillOut.grade`,
  `StandingOut.grade`), `app/routers/workers.py`'s two `"REGISTERED"`
  string literals → `GradeEnum.REGISTERED`, and the equivalent test
  call sites (`tests/conftest.py`'s `worker_factory`,
  `tests/test_matching.py`).
- Verified: `ruff check .` / `mypy .` clean (42 files); full suite green
  (92 passed, 92.86% coverage) — including the test DB's own from-scratch
  migration run picking up the corrected migration cleanly.

### Long-term Fix
Done for the type-safety half. The second half — deciding and building
whatever workflow would actually populate `Skill.grade` (it remains
always-`NULL` today; no endpoint sets it) — is a product/workflow
decision, not a data-integrity bug, and is out of scope for this finding.
Tracked as its own follow-up rather than bundled in here, consistent with
how `Standing.grade` progression was already left as a separate open
question in the Standing-recomputation finding.

## Prevention
- [x] Added `gradeenum` and migrated both `Skill.grade` and
  `Standing.grade` to it
- [ ] Decide and build whatever sets `Skill.grade` in practice (separate,
  product-scoped follow-up — not a data-integrity gap)

## Related Issues
- Related to the broader Standing-never-recomputed finding — `grade` is
  one of the fields nothing ever updates

---

**Resolved By:** Claude Code (architecture-review-to-fixes session)
**Time to Resolution:** Same day, follow-up session
