---
title: Free trial length and enabling decoupled from Settings
date: 2026-09-18
tags: [payment, settings, trial, django, fast-api]
---

### Issue
The platform’s 14-day free trial length was hardcoded as `TRIAL_DAYS = 7` inside the `PAYMENTS` FastAPI microservice (`PAYMENTS/app/services/subscriptions.py`) and inside the `STUDENT` Django application (`STUDENT/hbec_backend/apps/accounts/serializers.py`). This led to an architectural issue where the setting in the `ADMIN` UI (which allowed changing the trial length, and now disabling it) was entirely ignored at user signup. Moreover, if a trial was generated, Django generated it with a hardcoded 7 days and sent an async best-effort request to the `PAYMENTS` service, which also hardcoded 7 days.

### Resolution
- Introduced a `trialEnabled` boolean on the backend `SystemSettings` default for `payment`.
- Added the `trialEnabled` state to the Admin UI's `<Switch>`.
- Updated `PAYMENTS/app/services/config.py` to correctly parse `trialEnabled`.
- Replaced the hardcoded `TRIAL_DAYS` in both `PAYMENTS` and `STUDENT` codebases with an HTTP request to the `ADMIN` backend internal `_internal/settings/payment/` endpoint (with local caching in Django). 
- Modifed the trial creation logic to insert an `EXPIRED` status subscription if `trialEnabled` is false.

**Resolved By**: Antigravity
