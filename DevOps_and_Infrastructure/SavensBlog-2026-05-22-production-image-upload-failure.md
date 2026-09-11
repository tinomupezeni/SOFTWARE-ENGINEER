# Production Image Upload Failure - Savens Blog

**Date:** 2026-05-22
**Project:** Savens Blog
**Environment:** Production
**Severity:** Critical
**Status:** Resolved

## Summary
A production outage occurred where users were unable to upload images for blog posts. The issue was traced to environment configuration drift, out-of-sync database migrations, and restrictive proxy settings.

## Root Causes
1. **CORS Mismatch:** The primary production domain was missing from CORS_ALLOWED_ORIGINS.
2. **Migration Lag:** New features (Categories) were implemented in code but the production database schema was not updated.
3. **Internal DNS Block:** savens-backend was missing from ALLOWED_HOSTS, blocking internal service communication.
4. **Proxy Limits:** The admin dashboard proxy defaulted to a 1MB upload limit.

## Resolution
1. **Infrastructure Fix:** Updated .env and Caddyfile to support the correct production domains and internal hosts.
2. **Database Sync:** Manually applied missing migrations and implemented a **Migration Gatekeeper** in the startup sequence.
3. **Proxy Optimization:** Standardized all Nginx proxies to support 50MB uploads and direct media volume serving.

## Prevention (Architectural)
Implemented a self-healing startup command:
\python manage.py makemigrations --check || (python manage.py makemigrations posts && python manage.py migrate --noinput)\
This ensures the database is always in sync with the current code deployment.

---
**Resolved By:** Gemini CLI
