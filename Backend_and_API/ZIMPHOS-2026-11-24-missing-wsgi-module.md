# Django backend had no config/wsgi.py despite WSGI_APPLICATION pointing at it

**Date:** 2026-11-24
**Project:** ZIMPHOS
**Environment:** Development (found while bringing the Docker stack up locally for the first time)
**Severity:** High
**Status:** Resolved

## Summary
`config/settings/base.py` sets `WSGI_APPLICATION = 'config.wsgi.application'`,
but `backend/config/wsgi.py` never existed in the repo. Any WSGI entrypoint
(`manage.py runserver`, gunicorn, daphne) crashes on startup. This was never
caught because CI and prior sessions ran backend tests via pytest, which
never imports the WSGI module.

## Symptoms
- `docker compose up` brought up `zimphos_api` but Django raised
  `ModuleNotFoundError: No module named 'config.wsgi'` wrapped in
  `django.core.exceptions.ImproperlyConfigured: WSGI application
  'config.wsgi.application' could not be loaded`.
- The container stayed "Up" (the dev server's autoreloader thread crashed,
  not the process), so `docker compose ps` showed it healthy while the port
  served nothing.

## Environment Details
- **Server/Host:** local Docker Compose (`docker-compose.yml`, `backend` service)
- **Services Affected:** `zimphos_api` (Django dev server)
- **Related Components:** `backend/config/settings/base.py`, `backend/manage.py`
- **Time First Observed:** 2026-11-24, first local `docker compose up` of this backend

## Investigation Steps

### 1. Initial Diagnosis
`docker compose logs backend` showed the WSGI import traceback immediately
after "System check identified no issues."

### 2. Root Cause Analysis
```bash
find backend -iname "wsgi.py"           # no results
grep -n WSGI_APPLICATION backend/config/settings/base.py
git log --all --oneline -- backend/config/wsgi.py   # no commits ever touched it
```

### 3. Key Findings
- `config/wsgi.py` was never created in either of the two backend-scaffolding
  commits (`1eeea67`, `7cfd83a`).
- `backend/tests/` runs under pytest-django, which reads `DJANGO_SETTINGS_MODULE`
  directly and never imports `WSGI_APPLICATION`, so the test suite passed
  with the module missing.

## Root Cause
The backend was scaffolded with a `WSGI_APPLICATION` setting but the
corresponding module was never generated/committed. Nothing in the test
suite or CI exercises the WSGI entrypoint, so the gap was invisible until
someone actually ran the server (runserver, gunicorn, or Docker).

## Prevention / Rule
**Guardrail:** Add a CI smoke-check step (or a cheap pytest test) that runs
`python -c "import django; django.setup(); from django.core.wsgi import
get_wsgi_application; get_wsgi_application()"` against each configured
settings module (`development`, `production`). This fails fast on any
missing WSGI/ASGI entrypoint without needing a live server.

This closes the gap because pytest alone — which is what CI currently
runs — never touches `WSGI_APPLICATION`.

## Solution

### Immediate Fix
Created the standard Django `config/wsgi.py`:
```python
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
application = get_wsgi_application()
```
Then ran migrations and the baseline seed inside the container:
```bash
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py seed_baseline
```
Confirmed with `curl http://localhost:8001/api/products` returning
`401 {"detail":"Authentication credentials were not provided."}` (correct —
auth is enforced, and the app boots).

### Follow-up
Not yet pushed/committed — this was found running the stack locally for a
demo, not as part of a reviewed PR. Commit `backend/config/wsgi.py` on the
next backend-touching branch.
