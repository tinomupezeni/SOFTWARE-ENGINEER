# Engineering Growth & Accountability Tracker

**Engineer:** Tino
**Role Context:** System Architect & LLM Driver
**Tracker Started:** July 2026

*This document is a living "report card." Its purpose is to track engineering maturity, ensure past mistakes are not repeated, and set clear goals for the next review cycle.*

---

## 🟢 Demonstrated Growth (What is working well)
*To be expanded each review cycle when a new tier of maturity is reached.*

* **Full-Stack Ownership:** Demonstrated ability to debug across Django, FastAPI, React Native, and Docker infrastructure.
* **Incident Response:** Systematic debugging (e.g., tracing a React sticky-cache bug all the way back to an Admin Outbox sync).
* **Fearless Refactoring:** Willingness to rip out faulty dependencies (e.g., migrating Flutter's local database from `isar` to `sqflite` to fix Android 15 compatibility).
* **Culture of Documentation:** Keeping rigorous post-mortems of production outages.

---

## 🔴 Anti-Patterns & Mistakes (The "Never Again" List)
*If any of these issues appear in future logs, it represents a regression in engineering maturity.*

### 1. The "Empty Migration" Trap
* **The Mistake:** Deploying new database schemas without a data migration strategy (e.g., Tese Marketplace `products` vs `products_listing`).
* **The Standard:** Schema changes *must* include an Alembic/Django data migration to port existing production data before routing traffic.

### 2. Manual "ClickOps" in Production
* **The Mistake:** SSHing into the VPS to run `sed` inside a container, manually running `docker network connect`, or starting a container left in `Created` state.
* **The Standard:** All changes must go through code. If it's not in the `docker-compose.yml` or a deployment script, it doesn't exist.

### 3. The "Environment Mirage"
* **The Mistake:** Pushing code that works locally but crashes in production due to missing dependencies (e.g., `sentry-sdk` crash) or missing connection factories (e.g., Redis Sentinel).
* **The Standard:** Staging Parity. Run `docker compose -f docker-compose.prod.yml build` locally or deploy to a staging VM *before* touching production.

### 4. Blind Trust in Caches (The Ghost Cache)
* **The Mistake:** The frontend locking up because it trusted `localStorage` for an exam board that the backend had deactivated.
* **The Standard:** The UI must always validate cached state against the backend truth and handle cache invalidation gracefully.

### 5. Silent Background Failures
* **The Mistake:** Background jobs (Celery/Kafka) failing due to network blips and leaving data unsynced without anyone knowing.
* **The Standard:** Try-Catch-Alert. Background jobs must have explicit error handling, retries, and Sentry alerts for fatal failures.

---

## 🎯 Goals for the Next Review Cycle (Target: August 2026)

To demonstrate progression from this cycle to the next, the following must be achieved:

- [ ] **Zero Manual Production Fixes:** No logs indicating that a problem was solved by typing raw docker commands on the live VPS.
- [ ] **Defensive Deployments:** Evidence that `deploy_staging.sh` and `deploy_prod.sh` are being used to catch errors *before* they go live.
- [ ] **Idempotent Webhooks:** The payment system webhooks (and any new webhooks) are rewritten to include strict Idempotency Keys to prevent duplicate processing.
- [ ] **Strict Network Mapping:** Docker networks are explicitly named and pinned in `docker-compose.yml` files, eliminating random DNS resolution failures.

---
*Reviewer Note: At the next review session, we will open this file first. If the logs show you manually tweaking a live container, or deploying an empty database table, we will highlight the regression. If the logs show you using staging to catch a hallucination from the LLM, we will mark a massive win for your growth!*
