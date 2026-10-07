# Laravel Container Fatal Error due to PHP Version Mismatch

**Date:** 2026-10-03
**Project:** ATTENDANCE
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The Laravel dashboard container (`attendance-admin-1`) crashed on startup, causing `localhost:8080` to refuse connections. The root cause was a mismatch between the PHP version specified in the `Dockerfile` and the version required by Laravel's latest Composer dependencies.

## Symptoms
- Navigating to `http://localhost:8080` resulted in `ERR_CONNECTION_REFUSED`.
- The container logs (`docker compose logs admin`) showed a fatal exception:
  ```
  Fatal error: Uncaught RuntimeException: Composer detected issues in your platform: Your Composer dependencies require a PHP version ">= 8.4.1". You are running 8.2.34.
  ```

## Environment Details
- **Server/Host:** Local Development Docker Stack
- **Services Affected:** Laravel Admin Dashboard (`admin/Dockerfile`)
- **Time First Observed:** 2026-10-03T23:46

## Investigation Steps
1. The user reported the site could not be reached despite the stack supposedly being online.
2. I executed `docker compose logs admin` to check the container's health.
3. The logs revealed that `php artisan serve` could not boot because the Composer autoloader halted execution due to the platform check failing (PHP 8.2 vs 8.4).

## Root Cause
When bootstrapping the Laravel project, Composer pulled the absolute latest packages which now strictly require PHP 8.4. However, the `admin/Dockerfile` was originally hardcoded to use the `php:8.2-cli` base image.

## Solution

### Immediate Fix
Changed the base image in `admin/Dockerfile` from `php:8.2-cli` to `php:8.4-cli`, and rebuilt the container using `docker compose up --build -d admin`.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

---

**Resolved By:** Antigravity
**Time to Resolution:** 2 minutes
