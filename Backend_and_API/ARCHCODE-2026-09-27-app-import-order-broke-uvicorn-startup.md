# Application could not boot under uvicorn; pytest hid it by bootstrapping Django first

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** Critical
**Status:** Resolved

## Summary
`api/app.py` imported `api.routes` — which import Django models — *before* importing `core.db`,
which is the module that calls `django.setup()`. Django refuses to define a model before the app
registry is populated, so `uvicorn api.app:app` died instantly with `ImproperlyConfigured`. The
entire 18-test suite passed throughout, because pytest-django calls `django.setup()` during
collection, so by the time `api.app` was imported the ordering was irrelevant. The service had
never actually been started.

## Symptoms
- `uvicorn api.app:app` → immediate `ImproperlyConfigured: Requested setting INSTALLED_APPS, but
  settings are not configured`
- Traceback passed through `content/models.py:40` → `ModelBase.__new__` →
  `apps.get_containing_app_config` → `check_apps_ready`
- 18/18 tests green, `manage.py check` clean, migrations clean — no signal anywhere that the
  process could not start

## Environment Details
- **Server/Host:** local dev, `runner/`
- **Services Affected:** the entire FastAPI service — nothing was deployable
- **Related Components:** `api/app.py`, `core/db.py`, `tests/test_api.py`, `scripts/smoke.py`
- **Time First Observed:** 2026-09-27, on the first attempt to start a real server

## Investigation Steps

### 1. Initial Diagnosis
Ran the app under uvicorn for the first time, rather than only under `TestClient`:

```bash
./.venv/bin/uvicorn api.app:app --host 127.0.0.1 --port 8077
```

### 2. Root Cause Analysis
The traceback ends in `django/apps/registry.py check_apps_ready`, which reads
`settings.INSTALLED_APPS` — and settings were not configured. Reading `api/app.py`'s imports in
execution order:

```python
from api.routes import runs, ws      # line 19 - imports attempts.models -> content.models
from api.schemas import HealthOut

# Importing core.db runs django.setup(), which must happen before any model is touched.
from core import db                  # line 23 - too late
```

The file already contained a comment stating the requirement. The code did the opposite, and the
comment's presence made the file read as correct on review.

### 3. Key Findings
- Python executes imports top to bottom, so placement is the whole mechanism. The requirement was
  documented one line *below* its own violation.
- `manage.py check` starts with `DJANGO_SETTINGS_MODULE` set, so it never exercises this path.
- `TestClient` inherits the test session's already-configured Django, so it cannot observe
  start-up order at all. **No in-process test of this code path could ever have caught it.**
- A second false claim sat in the same file: the lifespan comment said "Django closes its
  connections on exit via django.setup()'s lifecycle". `django.setup()` has no such lifecycle. The
  thread-sensitive executor's connection was therefore never closed on shutdown.
- The lint/format tooling actively wanted to *reintroduce* the bug: `isort` sorts imports
  alphabetically and would move `from core import db` below `from api.routes import ...`.

## Root Cause
A test harness that pre-bootstraps the framework it is meant to be testing. pytest-django calls
`django.setup()` as a plugin, so application import order became unobservable, and a
load-bearing ordering requirement was documented while being violated. The bug lived in the gap
between "the tests pass" and "the process starts", and nothing in the suite spanned that gap.

## Prevention / Rule
**Guardrail:** Any test that must observe application *start-up* has to run in a fresh
subprocess with the framework's bootstrap environment stripped. For this project specifically:
import `api.app` in a subprocess with `DJANGO_SETTINGS_MODULE` removed from the environment, so
the only thing that can configure Django is the application's own import order.

The second half: where import order is semantically load-bearing, exclude that file from the
import sorter (`per-file-ignores = ["I001"]`) with a comment. Otherwise the formatter is a
standing invitation to reintroduce the defect.

## Solution

### Immediate Fix
Moved the bootstrap import above the route imports, and made the comment say why it is there
rather than what it does:

```python
# MUST come before anything that imports a model. `core.db` is what calls django.setup(), and
# Django refuses to define a model before the app registry is populated. The routes below import
# models, so importing them first raises ImproperlyConfigured under a plain `uvicorn api.app:app`
# -- it only appeared to work under pytest, because pytest-django runs django.setup() during
# collection and hid the ordering bug entirely.
from core import db

from api.routes import runs, ws
from api.schemas import HealthOut
```

Also corrected the lifespan and made it actually close the connection, on the right thread:

```python
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    try:
        yield
    finally:
        await db.db_call(connections.close_all)
```

### Long-term Fix
- `test_app_imports_in_a_clean_process_with_no_django_bootstrap` — subprocess import with
  `DJANGO_SETTINGS_MODULE` stripped. Verified load-bearing: restoring the bad order makes it fail.
- `pyproject.toml` → `per-file-ignores` for `api/app.py` = `["I001"]`, with the reason recorded.
- `scripts/smoke.py` — an end-to-end script against a *running* uvicorn process, covering real
  sockets, a real event loop, and real WebSocket frames. Self-cleaning, so it is re-runnable.

## Prevention
- [x] Import order corrected
- [x] Subprocess import test added and proven to fail on the old order
- [x] `isort` prevented from reordering the file, with reason recorded
- [x] Lifespan actually closes the bridge's connection, on the bridge's own thread
- [x] `scripts/smoke.py` added for real-process coverage
- [ ] Add a `make`/script target that starts the server and runs the smoke test in CI, so
      "it boots" is a checked property rather than a manual step
- [ ] Audit other `noqa: F401` "import for side effects" comments — they are where this class of
      ordering dependency tends to hide

## Related Issues
- `Backend_and_API/ARCHCODE-2026-09-27-django-tests-need-transactional-db-with-async-bridge.md` —
  the same `thread_sensitive` executor whose connection this lifespan failed to close
- `Database_and_State/ARCHCODE-2026-09-27-stale-dev-database-after-in-place-migration-edit.md` —
  found by the same live-server run
- `reports/ARCHCODE-2026-09-27-runner-api-first-green.md`

## References
- `scripts/smoke.py` docstring records the failure verbatim
- Django `apps/registry.py check_apps_ready` — the exact frame that raised

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~25 minutes
