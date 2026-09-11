# Lesson Plan: Tese Marketplace Microservices Architecture

**Status:** Active
**Objective:** Master advanced microservices architecture patterns, distributed reliability, async databases, and zero-trust security through the lens of the Tese Marketplace codebase.

---

## Course Modules

### Module 1: Distributed Reliability & Saga Patterns (Current)
* **Goal**: Build fault-tolerant workflows that span multiple database boundaries without raw dual-write bugs.
* **Topics**:
  - RAM-based orchestrators vs. persistent state machines.
  - Compensating actions for partial failures.
  - The Transactional Outbox pattern for decoupled event generation.
* **Logs**:
  - [x] [Lesson 1.1: The Saga Pattern & RAM State Risks](file:///C:/Users/Dell/Documents/projects/dev-logs/tese-marketplace/lesson-01-sagas.md)
  - [x] [Lesson 1.2: Distributed Reliability & The Outbox Pattern](file:///C:/Users/Dell/Documents/projects/dev-logs/tese-marketplace/lesson-02-reliability-principles.md)

### Module 2: Concurrency & Async Database Scaling
* **Goal**: Maximize server throughout by transitioning database interactions from blocking threads to async loops.
* **Topics**:
  - Thread-pool exhaustion vs. Async Event Loops.
  - Implementing `SQLAlchemy-asyncio` models.
  - Eliminating database connection leakage in FastAPI background workers.

### Module 3: Observability & Zero-Trust Defense
* **Goal**: Secure and trace client interactions inside a multi-container Docker cluster.
* **Topics**:
  - Request mapping via distributed Trace IDs (OpenTelemetry).
  - Internal trust models: Spofing headers vs. Container Signatures (mTLS).
  - Centralized logs aggregation.

### Module 4: Deployment Safety & System Verification
* **Goal**: Enforce absolute environment integrity using automated verification pipelines.
* **Topics**:
  - Vite build-time environment variable compilation.
  - Automated pre-deployment static checks.
  - Automated post-deployment routing and liveness validation.
