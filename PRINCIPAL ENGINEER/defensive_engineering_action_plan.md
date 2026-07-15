# Defensive Engineering & Action Plan
**Author:** Principal Engineer (AI)
**Target:** Tino
**Date:** July 2026

## Core Philosophy
Shift from **Reactive** ("How fast can I fix production?") to **Defensive** ("How do I prevent this class of errors from ever reaching production?").

## 1. DevOps Lockdown & Container Hygiene
* **Unify Docker Configuration:** Explicitly map all external networks in your `docker-compose.yml` to prevent Docker from creating isolated bridge networks on restart.
* **Health-Check Gates:** Add `HEALTHCHECK` instructions to all `Dockerfile`s (e.g., `curl -f http://localhost:8000/health || exit 1`). Deploy scripts must wait for this check to pass before routing traffic.
* **Log Rotation Limits:** Prevent OOM (Out of Memory) and disk exhaustion by capping log sizes in every docker-compose service:
  ```yaml
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"
  ```
* **Local Prod-Parity:** Always run `docker compose -f docker-compose.prod.yml up --build` locally before pushing to the VPS. If it crashes locally due to missing dependencies, it will crash in production.

## 2. Codebase Hardening & State Management
* **Frontend Cache Auditing:** Never trust `localStorage` or `sessionStorage` blindly. Always validate cached data against the backend source of truth (e.g., verify that a cached exam board is still `active` in the DB).
* **Data Migration SOP:** Schema migrations must never be deployed without corresponding data migrations. If you add a new table, write the script that populates it *before* the traffic routes to it.
* **Idempotency by Default:** All webhook handlers and background jobs must check if a payload has already been processed before mutating the database (e.g., use `update_or_create` or check for existing transaction IDs).

## 3. Security Backlog
* **Decouple Secrets:** Do not overload secrets (e.g., using `HARNESS_WEBHOOK_SECRET` for payment routing).
* **Webhook Signatures:** Always verify cryptographic signatures on webhooks (e.g., Paynow callbacks) before processing financial transactions.
