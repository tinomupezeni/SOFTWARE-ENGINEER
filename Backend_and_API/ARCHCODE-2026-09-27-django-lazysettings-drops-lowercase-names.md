# Django's LazySettings silently drops lowercase setting names

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
`archcode/settings.py` defines a Pydantic `Settings` object with lowercase fields, and exports
the values Django needs as module-level uppercase constants (`SECRET_KEY`, `DEBUG`,
`ALLOWED_HOSTS`). `ATTEMPT_BUDGET_MS` was never added to that export list, so the rest of the
codebase — which reads `django.conf.settings.ATTEMPT_BUDGET_MS` — got an `AttributeError` at
request time. Every endpoint that reported the latency budget, including `/healthz`, returned
500. Pydantic's own model was correct the whole time; the value simply never crossed the
boundary into Django's namespace.

## Symptoms
- `GET /healthz` → 500
- `AttributeError: 'Settings' object has no attribute 'attempt_budget_ms'`
- Any code touching the budget (`POST /runs`, `GET /runs/{id}`, the WebSocket snapshot, the
  Django admin) failed the same way
- Confusing type in the message: the `Settings` named is Pydantic's, but the caller asked
  `django.conf.settings`, so the error read as if Pydantic had lost the attribute

## Environment Details
- **Server/Host:** local dev, `runner/`
- **Services Affected:** FastAPI `/healthz`, run submission, run detail, WebSocket `hello` frame
- **Related Components:** `archcode/settings.py`, `api/app.py`, `api/routes/runs.py`,
  `api/routes/ws.py`, `content/admin.py`
- **Time First Observed:** 2026-09-27, first API test run

## Investigation Steps

### 1. Initial Diagnosis
The traceback bottomed out in `django/conf/__init__.py:124` — inside `LazySettings.__getattr__`
raising `AttributeError` — which pointed at the *lookup*, not at the Pydantic model.

### 2. Root Cause Analysis
```bash
./.venv/bin/python -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE','archcode.settings')
django.setup()
from django.conf import settings
print(settings.ATTEMPT_BUDGET_MS)"
# AttributeError: 'Settings' object has no attribute 'attempt_budget_ms'
```

The settings module exported three of its four values. `attempt_budget_ms` was read from
Pydantic correctly everywhere in the module body, so it *looked* wired up — it simply wasn't in
the uppercase namespace that `django.conf.settings` copies from.

### 3. Key Findings
- `django.conf.settings` is a `LazySettings` that copies only **UPPERCASE** module attributes.
  Lowercase names are invisible to it, permanently and silently.
- Pydantic's `BaseSettings` convention is lowercase field names, and Django's is uppercase
  module constants. Anything read through `django.conf.settings` needs an explicit uppercase
  bridge; there is no automatic one.
- This is invisible to `manage.py check` and to startup. It fails on first access, at whatever
  request happens to read the value first.

## Root Cause
Two naming conventions met at one boundary with no bridge. The Pydantic `Settings` instance was
correct, but `django.conf.settings` never received `ATTEMPT_BUDGET_MS`, because the module
exported `SECRET_KEY`/`DEBUG`/`ALLOWED_HOSTS` and the author assumed the pattern generalised.
Django silently ignores lowercase module attributes rather than rejecting them, so the omission
produced no warning at any point before the first request.

## Prevention / Rule
**Guardrail:** In a project that pairs Pydantic settings with Django, define one module-level
`assert`-style completeness check in `archcode/settings.py` that raises at import if any
`Settings` field lacks a corresponding uppercase module constant — and treat any
`dj_settings.<lowercase_name>` as a lint error.

`RUF`/custom rule: ban lowercase attribute access on `django.conf.settings`. Django's own
convention is uppercase precisely because `LazySettings` copies only uppercase names; a
lowercase read is always either an `AttributeError` or a silent miss, never a value.

## Solution

### Immediate Fix
Exported the missing constant with a comment recording why it exists:

```python
# Django's LazySettings copies only UPPERCASE names off the settings module, so anything read
# as `django.conf.settings.<name>` must be uppercase here.
ATTEMPT_BUDGET_MS = settings.attempt_budget_ms
```

Updated all five call sites from `dj_settings.attempt_budget_ms` to
`dj_settings.ATTEMPT_BUDGET_MS`.

### Long-term Fix
Recorded the constraint at the export site so the next field added to `Settings` has an obvious
companion. The gap is now documented in the one place a future author will be editing.

## Prevention
- [x] `ATTEMPT_BUDGET_MS` exported and all call sites updated
- [x] Comment added at the export site explaining the uppercase requirement
- [ ] Add an import-time check that every `Settings` field has an uppercase export
- [ ] Add a `DJ101`-style custom lint check for lowercase `django.conf.settings` access
- [ ] `/healthz` is now covered by `test_healthz_reports_execution_disabled`, which fails loudly
      if a budget field is ever dropped again

## Related Issues
- `Database_and_State/ARCHCODE-2026-09-27-verdict-check-constraint-inverted-polarity.md` — the
  `IntegrityError` seen in the same run was blamed on this one first
- `reports/ARCHCODE-2026-09-27-runner-api-first-green.md`

## References
- `django.utils.connection.LazySettings` copies uppercase attributes from the settings module
- Pydantic `BaseSettings` field names are lowercase by convention

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~5 minutes
