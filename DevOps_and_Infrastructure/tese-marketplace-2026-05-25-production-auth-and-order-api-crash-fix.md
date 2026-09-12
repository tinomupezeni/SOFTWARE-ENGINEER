# Incident Log: Production Auth Failure & Order API Crash
**Date:** 2026-05-25
**System:** Tese Marketplace (Production VPS)
**Severity:** Critical (System unusable for customers)

## Symptoms
- Users were immediately logged out after successful login.
- Console logs showed 401 Unauthorized on /api/orders.
- Console logs showed 404 Not Found on /api/addresses.
- Internal logs showed Signature verification failed in tese-store-api.
- tese-order-api was stuck in a restart loop.

## Root Cause Analysis
1. JWT Configuration Drift: The JWT_SECRET_KEY was missing from the environment configuration of several backend services (store-api, catalog-api, order-api, brain-api) in the VPS docker-compose.vps.yml. This caused signature verification failures when the orchestrator forwarded tokens to internal services.
2. Missing Typing Import: A NameError: name 'Optional' is not defined in apps/order-api/app/routes/order.py caused the service to crash on startup. This was due to a missing Optional import from typing.
3. Routing Misconfiguration: The orchestrator's SERVICE_MAP was pointing to /api/orders/cart for the cart service, while the actual endpoint was /api/cart.
4. Environment Loading Failure: Docker Compose failed to interpolate variables from the .env file due to formatting issues and incorrect escaping in the YAML file.

## Resolution Actions
1. Sanitized Environment: Rewrote the VPS .env file with clean line endings and verified content.
2. Fixed Orchestrator Routing: Updated apps/store-api/app/main.py to correctly map the cart service to /api/cart.
3. Hardened Compose Config:
    - Explicitly passed JWT_SECRET_KEY to all backend services.
    - Standardized database healthchecks with hardcoded tese_user to ensure reliable service startup.
    - Cleaned up YAML quoting to prevent parsing errors.
4. Hot-Patched Production Images:
    - Patched tinotenda762/tese-order-api to include the missing Optional import.
    - Patched tinotenda762/tese-store-api to fix the routing table.
    - Restored correct CMD entrypoints after patching.

## Verification
- tese-db-legacy is healthy.
- All microservices are successfully running and connected.
- Orchestrator logs show successful JWT validation and request forwarding.
- Frontend no longer triggers immediate logouts.

## Prevention / Rule
**Guardrail (JWT secret drift):** A fail-fast startup check in every service that validates JWTs — refuse to boot if `JWT_SECRET_KEY` is unset or empty, rather than silently accepting requests it can never actually verify. This is the same JWT-secret-omission bug already logged in `2026-05-22-production-auth-loop-and-address-fix.md`, recurring days later across a *different* set of services in the same compose file — evidence this needs to be a per-service boot-time check, not something remembered per-service when it's added to Compose.

**Guardrail (remote YAML/env corruption):** Always write remote config files via a quoted heredoc (`cat <<'EOF' > .env`), never an unquoted one — an unquoted heredoc lets the local shell expand `$VARS` before the content ever reaches the remote file, corrupting exactly the kind of placeholder values (`${JWT_SECRET_KEY}`) this incident's root cause depended on.

## Prevention & Lessons Learned
- Exhaustive Variable Mapping: Every microservice that validates JWTs MUST have the JWT_SECRET_KEY explicitly passed in the Compose file.
- TDD for Imports: Ensure all routes are covered by basic startup tests to catch missing imports before deployment.
- Literal YAML Pointers: Use quoted heredocs when updating remote YAML files to prevent local variable expansion from corrupting placeholders.
- Registry Hygiene: Ideally, fixes should be pushed to the registry rather than hot-patched. A follow-up CI/CD run is recommended to synchronize the registry images with these patches.
