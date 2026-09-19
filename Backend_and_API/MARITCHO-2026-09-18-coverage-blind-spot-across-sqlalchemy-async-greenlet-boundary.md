# pytest-cov Undercounted Almost the Entire Domain Layer Due to Uninstrumented Greenlet Switches

**Date:** 2026-09-18
**Project:** MARITCHO
**Environment:** Development (CI/local test coverage gate)
**Severity:** Medium
**Status:** Resolved

## Summary
After completing a Clean Architecture restructuring of the FastAPI backend (splitting a flat monolith into `domain`/`infrastructure`/`interface_adapters` layers per app), the test suite passed 130/130 but `pytest --cov` reported only ~53–80% coverage against an 85% gate, with entire use-case method bodies (e.g. `BookJobUseCase.execute`) showing as 0% covered. Manually instrumenting the method confirmed it genuinely executed during the failing test run — the tests were correct; the coverage tool was undercounting.

## Symptoms
- `pytest --cov=app --cov-report=term-missing` reported most lines in every `apps/*/domain/services.py` file as "Missing," specifically every line from the first `await self._db.*` call in a method onward — the pattern was consistent across every use case, in every app.
- Directly wrapping `BookJobUseCase.execute` with a `print()`-emitting monkeypatch confirmed the method was called exactly as expected by the test, proving the gap was in measurement, not execution.
- Isolating a single test with `--cov-fail-under=0` reproduced the same missing-line pattern even for one known-passing test, ruling out cross-test interference or aggregation bugs.

## Environment Details
- **Server/Host:** Docker container (`maricho-builder`, Python 3.11) and local venv (Python 3.14) — reproduced identically on both
- **Services Affected:** `backend-api` test/coverage pipeline only (no runtime impact — this never affected the actual application, only the reported test-coverage percentage)
- **Related Components:** `pyproject.toml` `[tool.coverage.run]`, SQLAlchemy async engine (`AsyncSession` via `asyncpg`)
- **Time First Observed:** 2026-09-18, first full-suite coverage run after finishing the Clean Architecture restructuring (see `docs/architecture/adr/007-clean-architecture-with-domain-apps.md`)

## Investigation Steps

### 1. Initial Diagnosis
Ran `pytest -q --cov=app --cov-report=term-missing` after all 130 tests passed; coverage read 52.59% against an 85% gate that had previously passed (93.77%) on the pre-restructuring flat codebase.

### 2. Root Cause Analysis
Isolated the check to a single file (`app/apps/jobs/domain/services.py`) and a single test, confirming the "missing" lines were exactly the statements following each method's first database-bound `await`. Recognized this shape as SQLAlchemy's async engine bridging each blocking DBAPI call through a `greenlet.greenlet` context switch (`greenlet_spawn`) — `coverage.py`'s default `sys.settrace`-based tracer does not automatically follow execution across a greenlet switch onto its own stack without being told to.

### 3. Key Findings
- `coverage.py` has an explicit `concurrency` config option (`concurrency = ["greenlet"]` in `[tool.coverage.run]`) specifically for this; it was absent from `pyproject.toml`.
- Confirmed the fix by rerunning the full suite after adding the setting: coverage jumped to 89.01% (later 87.87% in the local venv after deleting the dead pre-restructuring files that had been diluting the denominator) — both well above the 85% gate, and the remaining "Missing" lines were legitimate untested branches (e.g. unexercised error paths), not measurement gaps.
- This gap likely predates the restructuring and would have applied to the old flat router code too, but went unnoticed there — plausibly because the old monolithic router functions had proportionally more non-DB-bound lines (validation, branching) before their first `await db.*` call, diluting the effect, whereas the new domain use-case classes are almost entirely DB-bound from their first line.

## Root Cause
`[tool.coverage.run]` in `pyproject.toml` had no `concurrency` setting, so `coverage.py`'s trace function silently stopped attributing hits after the first async-DB-bound `await` in any frame — because SQLAlchemy's async engine executes the actual blocking driver call inside a greenlet switch that the default tracer isn't configured to follow.

## Prevention / Rule
**Guardrail:** Any Python project using SQLAlchemy's async engine (`sqlalchemy[asyncio]` + `asyncpg`/`aiosqlite`/etc.) under `pytest-cov` must set `concurrency = ["greenlet"]` in `[tool.coverage.run]` — add this as a required line whenever `sqlalchemy[asyncio]` appears in a new project's dependencies, checked at the same time the coverage `fail_under` gate is set up.

This closes the gap at its actual mechanism (telling coverage.py about the specific concurrency primitive in use) rather than papering over it with a lower coverage threshold, which would have hidden real coverage gaps going forward instead of just this measurement artifact.

## Solution

### Immediate Fix
Added to `backend/pyproject.toml`:
```toml
[tool.coverage.run]
source = ["app"]
concurrency = ["greenlet"]
```

### Long-term Fix
Covered by the guardrail above — no further action needed for this project. Worth checking any other MARITCHO-adjacent or future project using SQLAlchemy's async engine for the same missing setting before trusting its coverage numbers.

## Prevention
- [x] Configuration changes needed (done — see Immediate Fix)
- [ ] Documentation to update (mentioned in `docs/architecture/adr/007-clean-architecture-with-domain-apps.md` under "Consequences"; consider adding to a shared backend-standards doc if this recurs on another project)
- [ ] Monitoring/alerts to add (n/a)
- [ ] Code changes required (n/a beyond the config change)

## Related Issues
- Found during the same session as `MARITCHO-2026-09-18-repository-create-missing-refresh-lost-numeric-precision.md` (Database_and_State) — both surfaced while verifying the Clean Architecture restructuring.

## References
- `docs/architecture/adr/007-clean-architecture-with-domain-apps.md` — "Consequences" section documents this as a tooling caveat of the restructuring
- [coverage.py: Measuring concurrency](https://coverage.readthedocs.io/en/latest/config.html#run) — `concurrency` config option

---

**Resolved By:** Claude Code (backend restructuring session)
**Time to Resolution:** ~30 minutes (isolating single-test reproduction, confirming via manual method-wrapping, identifying the greenlet mechanism, applying and verifying the fix)
