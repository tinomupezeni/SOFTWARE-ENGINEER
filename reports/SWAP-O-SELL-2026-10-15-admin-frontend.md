# Swap-O-Sell Admin Frontend

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Type:** Feature implementation / Architecture decision  
**Status:** Completed

## Summary
Added a lightweight React/Vite admin frontend inspired by Chem-Glee's simpler admin pattern. It provides a focused staff shell, JWT login, operational dashboard, and read-only views for listings, users, orders, and swap offers against new staff-only Django API endpoints.

## Context / Trigger
Swap-O-Sell had a Django backend and built-in Django admin, but no simple operational frontend for marketplace staff. Chem-Glee's separate admin app provided a useful reference: a compact sidebar, shared API client, dashboard cards, and small operational pages instead of reusing the customer storefront.

## Scope
Included the standalone `admin/` Vite app, JWT authentication, responsive navigation, dashboard metrics, listing/user/order/swap-offer views, backend staff authorization, Docker Compose integration, and validation. Editing and moderation workflows remain deferred until the read-only operational surface is proven useful.

## Method
Inspected Chem-Glee's admin shell and API-client patterns, mapped them to Swap-O-Sell's existing models and serializers, added a small `modules.admin_api` Django app, and verified both unauthenticated rejection and container serving.

## Decisions & Findings
- The admin is a separate frontend at port `5174`, keeping staff workflows isolated from the customer app.
- The backend owns authorization; the frontend only stores JWT access/refresh tokens and renders the staff surface.
- The first version is intentionally read-only to avoid introducing destructive marketplace controls before the operational data model is settled.
- Existing `/signin/` returns JWT tokens under `data`, so the admin client explicitly unwraps that response.

## Changes Made
- Added `backend/modules/admin_api/` with staff-only summary, products, users, orders, and swap-offer endpoints.
- Added `admin/` React/Vite application with responsive sidebar, login, dashboard cards, searchable listings, and operational tables.
- Added `admin/Dockerfile` and a Compose `admin` service on port `5174`.
- Added port `5174` to development CORS origins.

## Verification
- `admin`: `npm run typecheck` passed.
- `admin`: `npm run build` passed.
- Django `manage.py check` passed in the backend container.
- Unauthenticated `GET /api/admin/summary/` returns `401`.
- Admin container serves successfully on `http://localhost:5174/`.
- `git diff --check` passed.

## Follow-ups / Deferred
- Add focused Django API tests for authenticated staff and denied non-staff users.
- Add listing moderation, user verification, order state transitions, and swap-offer review actions.
- Add refresh-token handling to the admin client before long-lived production use.

## References
- Chem-Glee admin pattern: `/home/shadowe/Projects/chemglee-concept-site/admin`
- `backend/modules/admin_api/`
- `admin/src/main.tsx`
- `admin/src/api.ts`
- Related issue: `Backend_and_API/SWAP-O-SELL-2026-10-15-admin-endpoint-permission-wrapper.md`

---

**Completed By:** Copilot  
**Duration:** One implementation session
