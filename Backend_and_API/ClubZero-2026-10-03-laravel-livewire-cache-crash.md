# Laravel 11 QueryException on Livewire due to missing cache table

**Date:** 2026-10-03
**Project:** Club Zero
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The Laravel 11 admin dashboard crashed with a 500 Internal Server Error when rendering Livewire components. The application attempted to validate Livewire checksums using the application cache, but the default Laravel 11 `.env` configuration sets `CACHE_STORE=database`, and the `cache` table did not exist in the shared Postgres database.

## Symptoms
- Attempting to load any Livewire page in the Admin Dashboard resulted in a 500 error screen.
- Laravel logs showed `Illuminate\Database\QueryException`: `SQLSTATE[42P01]: Undefined table: 7 ERROR: relation "cache" does not exist`.

## Environment Details
- **Server/Host:** local Laravel Sail
- **Services Affected:** `club-zero-admin` (Livewire)
- **Related Components:** `.env` configuration, shared PostgreSQL DB
- **Time First Observed:** 2026-10-03

## Investigation Steps

### 1. Initial Diagnosis
The stack trace explicitly pointed to the `Illuminate\Cache\DatabaseStore` failing to execute a `select * from "cache" where "key" in (...)` query during the Livewire component checksum validation phase.

### 2. Root Cause Analysis
The Laravel application was configured to share a PostgreSQL database with a FastAPI backend. Because the database schema is owned by FastAPI (Alembic migrations), we intentionally skipped running Laravel's default migrations (`php artisan migrate`) to avoid overwriting or conflicting with the FastAPI `users` table. However, Laravel 11 defaults `CACHE_STORE`, `SESSION_DRIVER`, and `QUEUE_CONNECTION` to `database`, meaning it expects the `cache`, `sessions`, and `jobs` tables to exist.

### 3. Key Findings
- Laravel's `.env` contained `CACHE_STORE=database` and `SESSION_DRIVER=database`.
- The `cache` and `sessions` tables were never created because Laravel migrations were intentionally bypassed.

## Root Cause
An architectural friction point when sharing a database between two frameworks: Laravel 11's default reliance on database-backed infrastructure services (cache, sessions) collided with the decision to skip Laravel migrations in a database owned by another framework.

## Prevention / Rule
**Guardrail:** When integrating Laravel into an existing external database where it is not the primary schema owner, explicitly reconfigure `CACHE_STORE`, `SESSION_DRIVER`, and `QUEUE_CONNECTION` away from `database` (e.g., to `file` or `redis`) as a mandatory onboarding checklist step before booting the application.

This ensures Laravel does not blindly attempt to query internal framework tables that were never generated, preventing crash-on-boot scenarios for integrated tools like Livewire.

## Solution

### Immediate Fix
Updated the `club-zero-admin/.env` file to fall back to the filesystem for infrastructure services:
```env
CACHE_STORE=file
SESSION_DRIVER=file
QUEUE_CONNECTION=sync
```
Cleared the configuration cache to apply the changes.

### Long-term Fix
The environment variables have been committed or documented so that future developers do not attempt to use the database driver without creating the tables.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

## Related Issues
- N/A

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 10m
