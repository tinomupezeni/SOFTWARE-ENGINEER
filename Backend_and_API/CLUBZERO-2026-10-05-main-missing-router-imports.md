# Club Zero backend crashes on startup — `invites` and `deeplinks` routers used but never imported in `app/main.py`

**Date:** 2026-10-05
**Project:** CLUBZERO
**Environment:** Development (all environments — module-level crash)
**Severity:** Critical
**Status:** Resolved

## Summary

`club-zero-backend/app/main.py` references `invites.router` and `deeplinks.router` at module level (lines 35–36) but the import on line 2 does not include `invites` or `deeplinks`. Importing `app.main` therefore raises `NameError` immediately, so the FastAPI application cannot start in any environment running this commit (`246d3c5`).

## Symptoms

- Any process importing `app.main` (uvicorn worker, pytest collection touching the app, `create_tables.py`-style scripts via the app) dies at import time.
- Expected error (from static name analysis; names are bound nowhere in module scope):
  `NameError: name 'invites' is not defined` (and identically for `deeplinks`).
- `python -m py_compile` passes — this is a runtime `NameError`, not a syntax error, so it is invisible to compilation checks.

## Environment Details

- **Server/Host:** N/A (code-level; affects local compose, VPS `smepulse-vm`, and any CI importing the app)
- **Services Affected:** `club-zero-backend` API (`api` service, port 8001)
- **Related Components:** `app/main.py` lines 2, 35–36; `app/routers/invites.py`, `app/routers/deeplinks.py` (both exist on disk — the modules are there, just not imported)
- **Time First Observed:** 2026-10-05, during a codebase read-through (commit `246d3c5` "feat: complete full-stack invite & offline engine" is the likely introducer — it added the two `include_router` lines without updating the import)

## Investigation Steps

### 1. Initial Diagnosis

Read `app/main.py` (40 lines). Line 2 imports:

```python
from app.routers import health, auth, clubs, checkins, websockets, notifications, habits, stakes, feedback
```

Lines 35–36 mount two more routers:

```python
app.include_router(invites.router)
app.include_router(deeplinks.router)
```

`invites` and `deeplinks` appear nowhere else in the file.

### 2. Root Cause Analysis

Ran an AST-based used-vs-imported name check against `app/main.py`:

```bash
python3 -c "
import ast
src = open('app/main.py').read()
tree = ast.parse(src)
imported = set()
for n in ast.walk(tree):
    if isinstance(n, ast.ImportFrom):
        for a in n.names: imported.add(a.asname or a.name)
    elif isinstance(n, ast.Import):
        for a in n.names: imported.add((a.asname or a.name).split('.')[0])
used = sorted({n.id for n in ast.walk(tree) if isinstance(n, ast.Name)})
print([u for u in used if u not in imported and u not in dir(__builtins__)])
"
```

Result: `used-but-not-imported: ['app', 'conn', 'deeplinks', 'invites', 'lifespan']` — of which `app` (package context), `conn` (lifespan local), and `lifespan` (decorator-defined function) are false positives, while `deeplinks` and `invites` are genuinely unbound at module scope.

### 3. Key Findings

- Both router modules (`app/routers/invites.py`, `app/routers/deeplinks.py`) exist — this is a missing-import bug, not a missing-file bug. Fix is a one-line import change.
- `py_compile` passing while the app cannot start is exactly why this slipped through: nothing in the repo imports `app.main` in CI (no CI at all per DEVLOG §5), so no gate ever executed the module-level statements.
- Production VPS (`smepulse-vm`) status is unknown from here — if it runs an image built before `246d3c5`, it is unaffected; the next rebuild/deploy from this commit will crash-loop the API container.

## Root Cause

The "invite & offline engine" commit added two `app.include_router(...)` calls without extending the `from app.routers import ...` line. Because FastAPI router mounting executes at import time, the omission is a hard startup crash rather than a latent defect.

## Prevention / Rule

**Guardrail:** Add a CI smoke step that imports the app object (`python -c "from app.main import app"` inside the built image or venv) on every backend change — a 2-second import test fails before the fix and passes after it, catching 100% of module-level `NameError`/`ImportError` regressions that `py_compile` and linting cannot see.

This closes the exact gap above: no existing check ever executes `main.py`'s module-level statements, so any future unbound router/model/middleware name will again ship silently until a container crash-loops.

## Solution

### Immediate Fix

Applied 2026-10-05 (was pending at log time): one-line change to `club-zero-backend/app/main.py` line 2, adding the two missing names:

```python
from app.routers import health, auth, clubs, checkins, websockets, notifications, habits, stakes, feedback, invites, deeplinks
```

Verified with:

```bash
python -c "from app.main import app; print('import ok')"
ruff check --select F821,F822,F823 app/main.py  # All checks passed
```

Full-backend verification after this fix exposed three further startup-blocking defects in `app/routers/clubs.py`, logged separately the same day (`CLUBZERO-2026-10-05-clubs-*.md`). After all four fixes: `docker compose up -d --build` starts cleanly, `/health/ready` reports UP (database + redis), and a full register → login cycle returns real JWT access + refresh tokens.

### Long-term Fix

- Add the import-smoke CI check described above (covers this bug class permanently).
- Per DEVLOG §8 item 8, CI running `pytest` + `flutter analyze` is still missing entirely — the import smoke test should ride along with that CI setup rather than as a one-off.
- Consider `ruff check --select F821` (undefined-name) on the backend; it flags exactly this pattern statically.

## Prevention

- [ ] One-line import fix in `app/main.py` (pending owner go-ahead)
- [ ] Import-smoke step in backend CI
- [ ] `ruff` F821 undefined-name check on backend
- [ ] Confirm which image SHA is actually running on `smepulse-vm` before next deploy

## Related Issues

- `ClubZero-2026-10-03-fastapi-models-import-crash.md` — same bug class (import-time crash in backend), different file
- `CLUBZERO-2026-09-28-test-suite-could-not-even-collect.md` — prior collection-time failure; a standing import smoke test would have covered both

## References

- `SharedHQ/club-zero-backend/app/main.py` (lines 2, 35–36)
- `SharedHQ/DEVLOG.md` §3 (production on `smepulse-vm`), §5 (no CI), §8 item 8 (CI still missing)

---

**Resolved By:** Muse Spark (opencode)
**Time to Resolution:** Same day (found in morning review, fixed during login-failure investigation when the backend had to be started)
