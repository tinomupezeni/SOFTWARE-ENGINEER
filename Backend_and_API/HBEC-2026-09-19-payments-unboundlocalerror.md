# Payments UnboundLocalError on /initiate Endpoint

**Date:** 2026-09-19
**Project:** HBEC
**Area:** Backend and API

## Issue Description
A 500 Internal Server Error occurred on `POST /api/payments/initiate/` in the `payments` microservice.

## Root Cause
- An inline import `from ..services.webhooks import get_broadcaster` was placed deep inside the `initiate_payment` function.
- Because Python treats variables imported inline as local variables for the entire function scope, earlier references to `get_broadcaster()` in the same function resulted in an `UnboundLocalError: cannot access local variable 'get_broadcaster' where it is not associated with a value`.

## Resolution
- Removed the inline import from `initiate_payment` (the module already had a module-level import of `get_broadcaster` at the top of the file).
- The function now properly resolves `get_broadcaster` from the global module scope.

**Resolved By:** Antigravity
