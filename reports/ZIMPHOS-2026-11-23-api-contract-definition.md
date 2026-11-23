# Contract Definition: OpenAPI 3.1 & TypeScript Types for ZimPhos Stock Watch

**Date:** 2026-11-23
**Project:** ZimPhos Stock Watch
**Type:** Architecture Decision / Contract Definition
**Status:** Completed

## Summary
Defined the comprehensive OpenAPI 3.1 specification, TypeScript type declarations, and an engineering contract guide for ZimPhos Stock Watch. This establishes an unambiguous contract-first baseline enabling backend (Django REST Framework) and frontend (React + Vite PWA) teams to build independently while preserving core system invariants.

## Context / Trigger
To transition from design and system discovery into development, both backend and frontend teams required an explicit, binding contract document detailing all REST paths, HTTP methods, request bodies, query parameters, response structures, and exact data types.

## Scope
- Reverse engineered and mapped the full schema from the 484-request snapshot in `docs/ZimPhos-Consignment-Hub-explorer.html` and `docs/system-design/05-api-contract.md`.
- Produced:
  - `docs/contracts/openapi.yaml`: OpenAPI 3.1.0 specification encompassing 38 endpoint operations and 63 components.
  - `docs/contracts/api-types.ts`: Strongly typed TypeScript interfaces mirroring all schemas.
  - `docs/contracts/README.md`: System invariant documentation and method reference guide.

## Method
- Extracted verified real response payloads from `window.__CVH_SNAPSHOT__` covering all roles (`audit`, `finance`, `management`, `sales`, `logistics`, `admin`, `distributor`).
- Validated YAML parsing, schema references, and path completeness with an automated validation script.
- Codified non-negotiable architectural rules:
  1. Append-only ledger contracts (`stock_movement`, `audit_entry`).
  2. Complete omission of `expected_at_trigger` in distributor-facing stocktake endpoints.
  3. Client-generated UUID `client_id` for offline mobile mutations (`pod`, `submit`, `adjustments`).
  4. Standardized DRF error format (`{"detail": "string"}`).

## Decisions & Findings
- Kept the flat DRF response format without artificial `success/data` envelopes, maximizing compatibility with the existing frontend demo screens.
- Defined explicit money and currency mappings supporting multi-currency (`amount_reporting` in USD with original currency & amounts preserved).

## Changes Made
- Created `docs/contracts/openapi.yaml`.
- Created `docs/contracts/api-types.ts`.
- Created `docs/contracts/README.md`.
- Committed to branch `feature/api-contracts` (`4ce007b`).

## Verification
- Automated syntax validation: 38 paths, 63 component schemas, 0 broken `$ref` pointers.
- TypeScript generation script successfully verified type mappings for all models.

## References
- System Design: `docs/system-design/05-api-contract.md`
- Data Model: `docs/system-design/03-data-model.md`
- Core Logic: `docs/system-design/04-core-logic.md`

---

**Completed By:** Antigravity (AI Assistant)
**Duration:** 25m
