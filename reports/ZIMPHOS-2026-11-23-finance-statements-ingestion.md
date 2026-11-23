# Backend Finance Ledgers, Statements & Ingestion File Upload

**Date:** 2026-11-23
**Project:** ZimPhos Stock Watch
**Type:** Implementation / Feature Delivery
**Status:** Completed

## Summary
Completed the implementation of financial ledgers, receivables ageing, monthly consignment statements, dynamic integration mode configuration, and batch CSV file ingestion with automatic de-duplication and SKU mapping. Verified via TDD and pushed directly to `master`.

## Context / Trigger
To complete the consignment lifecycle, the system required the financial debt ledger (Money Check BR-09), month-end distributor statements (BR-12), and the batch upload mechanism allowing distributors to submit POS sales exports directly into the append-only stock movement ledger.

## Scope
1. **Financial Receivables & Ageing (`apps.finance`)**:
   - `POST /api/payments`: Records manual cash or bank payments with currency conversion into reporting currency.
   - `GET /api/receivables`: Evaluates distributor sold vs paid figures, calculating outstanding balances and debt ageing (`current`, `1-30`, `31-60`, `60+`).
   - `GET /api/statements/{distributor_id}`: Generates month-end consignment statements detailing SKU-by-SKU opening balance, deliveries, sales, returns, closing balance, closing stock value, and net closing owed.
2. **Ingestion & Integration Modes (`apps.ingestion`)**:
   - `IntegrationSetting` model: Governs dispatch and payment modes (`native`, `erp`, `native_with_erp_sync`).
   - `GET` & `POST /api/settings/integration`: Dynamic mode toggles for operations.
   - `POST /api/ingest/{distributor_code}/upload`: Handles batch CSV sales uploads, resolves canonical products through `SkuMapping`, applies UOM conversion factors, and enforces idempotency on `source_ref` so duplicate files never double-count sales.
   - `GET /api/feeds`: Ingestion feed health monitoring endpoint.

## Method
- Test-driven development with `pytest-django` covering CSV file decoding, mapping resolutions, debt ageing math, and statement generation in `test_finance_ingestion_contract.py`.

## Changes Made
- Updated `backend/apps/finance/views.py` and `urls.py`.
- Updated `backend/apps/ingestion/models.py`, `views.py`, and `urls.py`.
- Created `backend/tests/test_finance_ingestion_contract.py`.
- Pushed commit `9ed9f4e` directly to `master`.

## Verification
- Full test suite execution: **24 passed in 1.05s**.

---

**Completed By:** Antigravity (AI Assistant)
**Duration:** 20m
