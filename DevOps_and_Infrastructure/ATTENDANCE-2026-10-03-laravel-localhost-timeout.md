# Laravel API Base URL Fallback Networking Bug

**Date:** 2026-10-03
**Project:** ATTENDANCE
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The Laravel dashboard triggered a `cURL error 28: Operation timed out` when attempting to load the ledger. The root cause was the HTTP client attempting to fetch data from `http://localhost:8000` instead of the internal Docker backend container.

## Symptoms
- Navigating to the ledger dashboard threw an `Illuminate\Http\Client\ConnectionException`.
- The stack trace showed Guzzle attempting to connect to `http://localhost:8000/admin/ledger` and timing out after 30 seconds.

## Environment Details
- **Server/Host:** Local Development Docker Stack
- **Services Affected:** Laravel Admin Dashboard (`LedgerController`, `WorkplaceController`)
- **Time First Observed:** 2026-10-03T23:53

## Investigation Steps
1. Reviewed the crash stack trace provided by the user.
2. Identified that Guzzle was dialing `localhost:8000`.
3. Inside a Docker network, `localhost` resolves to the loopback interface of the *current* container (the PHP container), not the host machine or the FastAPI container. 
4. The FastAPI container is accessible via the Docker DNS hostname `backend:8000`.
5. Checked the `LedgerController` and discovered the `env()` fallback was incorrectly set to `http://localhost:8000`. Because the Docker environment variable was seemingly dropped or not loaded by `php artisan serve`, Laravel defaulted to the fallback.

## Root Cause
The `env('API_BASE_URL', 'http://localhost:8000')` fallback incorrectly pointed to `localhost`. When executed inside the PHP container, this caused the Laravel app to make HTTP requests to itself, resulting in a recursive timeout since it wasn't running an API on that port.

## Solution

### Immediate Fix
Changed the fallback value in both `LedgerController.php` and `WorkplaceController.php` to use the correct internal Docker DNS resolution:
`$this->apiBaseUrl = env('API_BASE_URL', 'http://backend:8000');`

## Prevention
- [x] Code changes required
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Configuration changes needed

---

**Resolved By:** Antigravity
**Time to Resolution:** 2 minutes
