# Backend Operational Controls, Position History & Outbox Complete

**Date:** 2026-11-23
**Project:** ZimPhos Stock Watch
**Type:** Implementation / Feature Delivery
**Status:** Completed

## Summary
Completed the final operational backend modules for ZimPhos Stock Watch: segregation-of-duties enforcement on damage write-offs, SKU mapping resolution with backlog record replay, 75-day position history trends, and external connector status & outbox retry controls. Verified with 28 passing contract tests and pushed to `master`.

## Context / Trigger
To complete coverage of the OpenAPI 3.1 specification, the remaining lifecycle operations required implementation: segregation of duties preventing shop users from approving their own inventory shrinkage, external SKU mapping replay, historical stock timeseries, and outbox delivery controls for external ERP integration.

## Scope
1. **Damage Write-offs & Segregation of Duties (`apps.ledger`)**:
   - `POST /api/adjustments`: Field requests for damaged stock.
   - `POST /api/adjustments/{id}/approve`: Checks `created_by != request.user.username` (returns `409 Conflict` on self-approval attempts). Upon approval, automatically posts a negative signed movement to `StockMovement`.
   - `POST /api/adjustments/{id}/reject`: Requires mandatory rejection reason.
2. **SKU Mapping Resolution & Replay (`apps.catalog`)**:
   - `GET /api/mappings`: Pending unmapped distributor codes list.
   - `POST /api/mappings/{id}`: Maps external code to ZimPhos SKU with UOM factor and returns the replayed record count.
3. **Position History & Timeseries (`apps.reconciliation`)**:
   - `GET /api/positions/{site_id}/{product_id}/history?days=75`: Composes historical daily Expected vs Reported stock curve, physical count benchmark points, and recent ledger movements with visibility lag.
4. **Connectors & ERP Outbox Controls (`apps.ingestion`)**:
   - `GET /api/connectors` & `POST /api/connectors/{id}/status`: Connector lifecycle management (`draft`, `shadow`, `active`, `paused`).
   - `GET /api/outbox` & `POST /api/outbox/{id}/retry`: Asynchronous ERP command monitoring and retry mechanism.

## Verification
- Comprehensive test suite covering all contract boundaries: **28 passed in 0.96s**.

---

**Completed By:** Antigravity (AI Assistant)
**Duration:** 15m
