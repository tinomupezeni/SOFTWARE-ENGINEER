# Trigram search import used the wrong Django namespace

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The first trigram-search implementation imported Django's `Greatest` database function from `django.db.models`, but Django exposes it from `django.db.models.functions`. The backend could not import its URL configuration until the namespace was corrected.

## Symptoms
- Backend system checks failed during startup.
- Django raised `ImportError: cannot import name 'Greatest' from 'django.db.models'`.
- The frontend build remained unaffected, but backend validation was blocked.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Backend
- **Related Components:** Listings search view, Django ORM database functions
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Ran the backend image build and Django system check after adding trigram similarity.

### 2. Root Cause Analysis
Read the import traceback and verified Django's function module layout.

```bash
docker compose exec -T backend python manage.py check
```

### 3. Key Findings
- `Greatest` is a database function, not a direct `django.db.models` export.
- The correct import is `from django.db.models.functions import Greatest`.

## Root Cause
The ORM function was imported from the wrong Django module namespace.

## Prevention / Rule
**Guardrail:** Django ORM expressions and database functions must be imported from their documented submodules, and `manage.py check` must run immediately after ORM query changes.

This catches import namespace errors before a backend container is considered healthy.

## Solution

### Immediate Fix
Moved the `Greatest` import to `django.db.models.functions`.

### Long-term Fix
Kept Django system checks and targeted search tests in the trigram-search verification sequence.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- Related to the PostgreSQL trigram search implementation.

## References
- `backend/modules/listings/views.py`
- Django ORM database function imports

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
