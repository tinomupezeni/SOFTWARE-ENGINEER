# Principal Engineer HBEC System Audit

**Date:** 2026-07-01
**Project:** HBEC
**Auditor:** Antigravity (Principal Systems Architect)
**Status:** Brutally Honest Review

---

### 🚨 CRITICAL STRUCTURAL RISKS (Fix Immediately)

* **[Synchronous Gunicorn Workers Blocking on Async AI I/O]**
    * **Location:** `STUDENT/hbec_backend/config/wsgi.py` / `docker-compose.production.yml` (Gunicorn config)
    * **The Systemic Vulnerability:** The Student backend is currently running sync Gunicorn (2 workers × 4 threads). If the backend is proxying or awaiting *any* long-running LLM or heavy I/O tasks, a mere 8-9 concurrent requests will completely exhaust the thread pool. The 9th request will hang indefinitely. This is a catastrophic architectural mismatch for an AI-heavy application. Under a minor traffic spike, the entire student backend will trigger a cascading timeout failure (`504 Gateway Timeout`) across the infrastructure.
    * **Architectural Remedy:** Migrate the Django backend from WSGI to ASGI (`uvicorn` or `daphne`). All views that interact with the AI Harness or external APIs must be refactored to use `async def` and `httpx.AsyncClient`. You cannot safely run sync workers for high-latency downstream AI calls.

* **[Local Database Backups Create a Single Point of Failure]**
    * **Location:** `scripts/backup-hbec.sh` and `/home/administrator/hbec/backups/`
    * **The Systemic Vulnerability:** While the new cron job successfully automates daily `pg_dump` and Redis `BGSAVE` exports, it saves them directly to the local host filesystem. If the ZCHPC VM suffers a catastrophic disk failure or hypervisor corruption, both your primary data and your backups are instantly annihilated. True Disaster Recovery (DR) does not exist here.
    * **Architectural Remedy:** Refactor the backup script to securely stream the compressed `.tar.gz` artifact to an immutable, off-site cloud storage bucket (e.g., AWS S3, Cloudflare R2, or a separate physical server) immediately after creation using the AWS CLI or `rclone`.

### ⚠️ MAJOR ARCHITECTURAL DEBT (Prioritize for Next Sprint)

* **[PgBouncer Transaction Mode & Django Connection Leaks]**
    * **Location:** `STUDENT/hbec_backend/config/settings/production.py` and Celery Task Workers
    * **The Anti-Pattern:** Django, by default, tries to hold persistent connections. In a PgBouncer `transaction` pooling environment, holding connections across Celery task boundaries or utilizing long-lived `CONN_MAX_AGE` exhausts the limited pool (max 25 connections to PG) instantly under load. While we recently patched `CONN_MAX_AGE=0` in the main web threads, Celery background workers are notorious for leaking connections if `DATABASES['default']['CONN_MAX_AGE']` isn't strictly managed per-task.
    * **Refactoring Strategy:** Implement the `celery.signals.task_postrun` hook to explicitly call `django.db.connection.close()` after every single background task. Do not trust Django's ORM to release the socket back to PgBouncer automatically in background threads.

* **[LiteLLM Rate Limit Wall & Absent Fallback Buffers]**
    * **Location:** `AGENTIC_HARNESS/app/shared/llm_client.py` and LiteLLM Proxy
    * **The Anti-Pattern:** The system relies on a brittle Groq free-tier limit (90 RPM). When the AI hits this wall, it outright fails requests instead of implementing a resilient backpressure or queuing buffer. A system is only as scalable as its tightest chokepoint.
    * **Refactoring Strategy:** Implement a Redis-backed queue for non-critical AI tasks (like background marking or summary generation). For synchronous chat, configure LiteLLM with strict fallback arrays (e.g., Groq -> Gemini -> local LLM) and implement an exponential backoff circuit breaker so the frontend gracefully degrades to a "Generating..." queue state rather than throwing a 500.

### 📊 DATA TOPOLOGY & SECURITY MATRIX AUDIT

* **Boundary Isolation Weaknesses:** 
  The Student backend recently exhibited bugs where querysets were not properly filtering by hierarchical relationships (e.g., missing database constraints allowing subjects without proper level/grade matching to leak to the frontend). Relying on application-layer `Q` objects for multi-tenant or multi-level data isolation is brittle. 
* **Validation at the Edge:**
  We must ensure that the Agentic Harness (FastAPI) utilizes strict `Pydantic` validation at the edge before any LLM payload hits the internal network or the vector database (Qdrant). The recent migration to explicit `http://localhost:6000` overrides in the React frontend exposed that environment variable injection was poorly structured, allowing potential local routing hijacks in untrusted environments.

### 🛠️ INFRASTRUCTURE RECOMMENDATIONS

1. **Host-Level Reverse Proxy SSL Termination:** Ensure NGINX or Caddy is handling all SSL/TLS handshakes strictly at the edge, utilizing HTTP/2 or HTTP/3 for multiplexing SSE (Server-Sent Events) streams to the FastAPI Harness. SSE over HTTP/1.1 via Gunicorn will exhaust connection limits instantly.
2. **Redis Split:** You are currently sharing a 512MB Redis instance for Celery brokering, rate limiting, and caching. Split this into two discrete containers: one `redis-cache` (with `allkeys-lru` eviction) and one `redis-broker` (with `noeviction`). If the cache fills up, you do not want it randomly evicting your mission-critical Celery tasks or rate-limit tokens.
