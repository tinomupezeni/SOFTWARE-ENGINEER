# 2026-05-19 - Architectural Audit & Engineering Mastery Lessons

## Context
A Senior Principal Software Engineer audit of the Tese-Marketplace codebase was conducted, focusing on reliability, security, performance, and scalability. These notes capture the core engineering lessons delivered during the audit.

## Lesson 1: Distributed Reliability & The Saga Pattern

### The Problem: The "Dual Write" Trap
In a distributed system, you cannot guarantee that two network-dependent actions (e.g., reserving stock in Catalog and creating an order in Orders) happen atomically. One will always happen before the other, creating a window for failure.

### The Engineering Shift: Stateless vs. Stateful Sagas
- **Current State (Orchestrator):** The saga progress is stored in RAM (local variables). If the orchestrator crashes between steps, the system is left in an inconsistent state (e.g., "Zombie" stock reservations).
- **Mandate:** Move from **Optimistic Engineering** (assuming success) to **Pessimistic Engineering** (designing for failure).
- **Solution:** Store the saga state in a persistent store (Redis/Postgres) *before* each transition. This allows a watchdog/worker to recover or roll back "In-Flight" transactions.

### Pattern: The Transactional Outbox
- To bridge the gap between database updates and API calls, use the **Outbox Pattern**.
- Save the "Intent" (Command) to the same database transaction as your business logic.
- Use a separate **Relay** to ensure the command is delivered to the remote service.

## Lesson 2: Asynchronous Efficiency

### The "Waiter" Analogy (Blocking vs. Non-blocking)
- **Synchronous:** A waiter stands in the kitchen waiting for a steak to cook, unable to serve other tables.
- **Asynchronous:** The waiter leaves the order and serves others until the chef calls them back.
- **Action:** Transition to SQLAlchemy-asyncio to prevent thread-pool exhaustion during high-concurrency database operations.

## Lesson 3: Observability & Defense in Depth

### Distributed Tracing (OpenTelemetry)
- Logs are "Black Boxes" in microservices. A single user click spans 5 servers.
- **Mandate:** Use OpenTelemetry to visualize the full journey of a request across service boundaries using a single Trace ID.

### Security: Internal Trust Model
- **Vulnerability:** Internal services currently blindly trust identity headers (X-Tese-User-ID).
- **Lesson:** Never trust the internal network. Implement **Internal Signatures** or **Mutual TLS** (mTLS) to ensure identity headers cannot be spoofed by compromised internal containers.

---
**Status:** Audit Lessons Recorded
**Repo:** Tese-Marketplace
**Engineer:** Gemini CLI (Senior Principal)

