# Swap offer conversation app-label mismatch

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The new `SwapOffer` model initially referenced `messaging.Conversation`, but the installed Django app label is `modules_messaging`. This prevented the backend container from passing Django system checks and caused its entrypoint to restart continuously.

## Symptoms
- Backend container repeatedly restarted.
- Django reported `fields.E300` and `fields.E307` for `swapapp.SwapOffer.conversation`.
- Swap-offer migration could not be validated while the model pointed at the wrong app label.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Backend
- **Related Components:** `swapapp.SwapOffer`, `modules.messaging.Conversation`, migration `0008_swapoffer`
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Ran `docker compose logs --tail=80 backend` and reproduced the Django system-check failure.

### 2. Root Cause Analysis
Compared the model relation with `modules/messaging/apps.py` and the existing messaging migrations.

```bash
docker compose logs --tail=80 backend
docker compose exec -T backend python manage.py check
```

### 3. Key Findings
- The messaging app config declares `label = 'modules_messaging'`.
- Existing migrations consistently reference `modules_messaging.conversation`.
- The model used the Python package name instead of the Django app label.

## Root Cause
Django model relations use the registered app label, not the Python import path. The `SwapOffer.conversation` field used `messaging.Conversation`, an app label that is not installed.

## Prevention / Rule
**Guardrail:** Every cross-app model relation must use the app label verified in the target app's `AppConfig`, and `manage.py check` must run before container startup.

This catches import-path/app-label confusion before the service enters a restart loop and ensures migrations and runtime model state use the same relation target.

## Solution

### Immediate Fix
Changed the relation to `modules_messaging.Conversation`, rebuilt the backend image, and restarted the service.

```bash
docker compose build backend --quiet
docker compose up -d backend
docker compose exec -T backend python manage.py check
```

### Long-term Fix
Added the swap-offer index migration and verified the migration graph through `swapapp.0009_swapoffer_indexes`.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- Related to the Swap-O-Sell swap-offer MVP implementation.

## References
- `backend/modules/messaging/apps.py`
- `backend/modules/messaging/migrations/0001_initial.py`
- `backend/swapapp/models.py`

---

**Resolved By:** Copilot
**Time to Resolution:** Same development session
