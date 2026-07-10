# Backend Development Standard

A living standard synthesized from production incidents across 10+ projects. Every rule here exists because its absence caused an outage, a security gap, or technical debt.

**Last Updated:** 2026-07-03
**Applies To:** All backend services (FastAPI / Django / Express)

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Code Quality & Static Analysis](#2-code-quality--static-analysis)
3. [API Design](#3-api-design)
4. [Database & Data Layer](#4-database--data-layer)
5. [Security](#5-security)
6. [Error Handling & Resilience](#6-error-handling--resilience)
7. [Testing](#7-testing)
8. [Observability](#8-observability)
9. [Deployment](#9-deployment)
10. [Microservices & Communication](#10-microservices--communication)
11. [Dependency Management](#11-dependency-management)

---

## 1. Project Structure

### Monorepo Layout (Preferred)
```
project-root/
├── apps/
│   ├── api-gateway/
│   ├── service-a/
│   └── service-b/
├── packages/
│   └── shared/
├── scripts/
│   ├── deploy.ps1
│   ├── smoke-test.sh
│   └── verify-deployment.ps1
├── docker-compose.yml
├── deployment-config.json
├── requirements.txt          # Root only if monorepo
└── README.md
```

### Service Naming
- Use kebab-case for directories: `auth-api`, `order-api`, `catalog-api`
- Use the same name as the Docker service name and container name
- Every service MUST have a unique port, health check endpoint, and Dockerfile

### Configuration Management
- **NEVER** hardcode secrets in source files (`base.py`, `config.py`, `.env` committed)
- Use typed settings classes (Pydantic Settings / Django-environ)
- Use granular env vars, NOT raw connection strings:

```python
# GOOD - granular, parse-safe
DB_USER: str
DB_PASSWORD: str
DB_HOST: str
DB_PORT: int
DB_NAME: str

@property
def database_url(self) -> str:
    from sqlalchemy.engine import URL
    return str(URL.create(
        drivername="postgresql+psycopg2",
        username=self.DB_USER,
        password=self.DB_PASSWORD,
        host=self.DB_HOST,
        port=self.DB_PORT,
        database=self.DB_NAME,
    ))

# BAD - breaks with special characters in password
DATABASE_URL: str = "postgresql://user:p@ssword@host/db"
```

- Validate critical secrets at startup (fail-fast, crash container):

```python
def _validate_production_secrets():
    required = ["SECRET_KEY", "DB_PASSWORD", "JWT_SIGNING_KEY"]
    dev_defaults = ["hbec@123", "tese@1234", "changeme"]
    for key in required:
        val = os.getenv(key)
        if not val:
            raise RuntimeError(f"FATAL: Missing required secret: {key}")
        if val in dev_defaults:
            raise RuntimeError(f"FATAL: Secret {key} still using dev default")
```

---

## 2. Code Quality & Static Analysis

### Mandatory Linting
- **Python:** `ruff` must be run on every service before commit
- **TypeScript/JS:** `eslint` + `prettier`
- Add lint script to root `package.json` or equivalent:

```bash
ruff check apps/ --fix
ruff format apps/ --check
```

### Import Hygiene
Missing imports caused multiple critical production crashes (`NameError: Depends is not defined`, `NameError: asyncio`).
- Run `ruff` which catches missing imports automatically
- NEVER rely on "it worked in my editor"
- Every file must have complete, explicit imports

### Type Hints
- **FastAPI:** Type hints are THE truth — they define validation, serialization, and docs
- **Django:** Use type stubs (`django-stubs`) for static analysis
- Avoid `Record<string, unknown>` and generic types — use Zod/Pydantic for runtime validation at service boundaries

### Dependency Injection
- FastAPI: Use `Depends()` for all shared resources (DB sessions, auth, config)
- Never import global singletons directly

---

## 3. API Design

### Versioning
- Prefix all API routes: `/api/v1/`, `/api/v2/`
- Never expose unversioned endpoints

### Health Check Endpoints (REQUIRED)
Every service MUST implement two health check endpoints:

```python
# SHALLOW - for load balancers (checks if process is alive)
@router.get("/health/shallow")
async def shallow_health():
    return {"status": "healthy"}

# DEEP - for deployment verification (checks dependencies)
@router.get("/api/v1/health/deep")
async def deep_health(db: Session = Depends(get_db)):
    status = {"status": "healthy", "components": {}}

    try:
        db.execute("SELECT 1")
        status["components"]["database"] = "up"
    except Exception as e:
        status["status"] = "unhealthy"
        status["components"]["database"] = f"down: {str(e)}"

    if status["status"] == "unhealthy":
        raise HTTPException(status_code=503, detail=status)
    return status
```

### WebSocket Routes
- MUST have explicit reverse proxy rules (`/ws/*` routed to ASGI server)
- NEVER let WebSocket traffic hit a catch-all to a static file server

### Response Standards
- Consistent error shape: `{"detail": "message", "code": "ERROR_CODE"}`
- Use HTTP status codes correctly (201 for creation, 204 for deletion, 401/403 for auth)
- Idempotency keys on payment/mutation endpoints

---

## 4. Database & Data Layer

### Connection Management
- **Always use PgBouncer (transaction mode) in production** — Django `CONN_MAX_AGE` alone causes connection leaks with Celery workers
- Set `CONN_MAX_AGE = 0` in production when behind PgBouncer to prevent idle connection accumulation
- Use context managers for raw DB access in background tasks:

```python
with connection.cursor() as cursor:
    cursor.execute(...)
```

### Migrations
- **Always use Alembic (FastAPI) or native Django migrations** — never manual SQL
- Migrations must run automatically in container entrypoint
- Use `--no-cache` on Docker build when migrations change to avoid stale migration files
- Test migrations against a copy of production data before deployment

### Credential Safety
- Passwords with special characters (`@`, `#`, `$`, `%`) MUST be URL-encoded or passed as granular vars
- Prefer alphanumeric-only passwords where possible to eliminate parsing ambiguity

### Idempotency
Payment webhooks and mutation endpoints MUST be idempotent:

```python
async def handle_webhook(event_id: str, ...):
    existing = await PaymentEvent.get_by_idempotency_key(event_id)
    if existing:
        return existing  # Already processed, return existing result
    # ... process new event
```

### Connection Pool Sizing
- Start with `POOL_SIZE=20`, `MAX_OVERFLOW=20` (SQLAlchemy)
- PgBouncer: `POOL_MODE=transaction`, `MAX_CLIENT_CONN=500`, `DEFAULT_POOL_SIZE=50`
- Monitor `pg_stat_activity` during load tests — idle connections should NOT accumulate

---

## 5. Security

### Secrets Management
- **ZERO hardcoded secrets** in source files — use `.env` + environment variables
- Implement `_validate_production_secrets()` that crashes the container on boot if any secret is missing or still a dev default
- Use `.env.example` (committed) with placeholder values, `.env` (gitignored) with real values
- Rotate secrets quarterly

### Authentication & Authorization
- Use RS256 asymmetric JWT for cross-service auth (not HS256 shared secrets)
- Validate tokens at the service boundary, not deep in business logic
- Implement "fail-closed" tenant isolation — default deny, explicit allow:

```python
# GOOD - fail closed
class TenantAwareViewSet(ModelViewSet):
    def get_queryset(self):
        return self.model.objects.filter(tenant_id=self.request.tenant_id)

# BAD - fail open (missing mixin leaks cross-tenant data)
```

- NEVER trust internal network headers (`X-User-ID`, `X-Tenant-ID`) without signature verification
- Implement mTLS or HMAC-signed internal tokens between services

### CORS
- `CORS_ALLOW_ALL_ORIGINS = True` is only acceptable in local dev
- Production MUST specify explicit origins
- CSP headers MUST allow required external services (Google Auth, CDN, etc.)

---

## 6. Error Handling & Resilience

### Graceful Degradation
All external dependencies (Sentry, Redis, AI providers) must use try-except guards:

```python
try:
    import sentry_sdk
    SENTRY_AVAILABLE = True
except ImportError:
    SENTRY_AVAILABLE = False
    log.warning("sentry-sdk not available")

if SENTRY_AVAILABLE and SENTRY_DSN:
    sentry_sdk.init(...)
```

### Retry Logic
- Network calls (webhooks, API calls, image pulls) MUST have retry with backoff
- Docker pulls in deployment: retry up to 3 times on failure
- Webhook delivery: use a queue (Redis/Celery) with retry, not synchronous delivery

### Circuit Breakers (AI Services)
LLM providers MUST have a tiered fallback chain:

```yaml
# litellm_config.yaml
model_list:
  - model_name: gpt-4
    fallbacks:
      - claude-3
      - local-vllm
```

### Async Processing
- Webhooks and long-running tasks MUST be offloaded to a queue (Celery, Redis Streams)
- Return `202 Accepted` immediately, process asynchronously
- NEVER process payment webhooks synchronously in the request handler

### Entrypoint Scripts
- DO NOT use `set -e` in Docker entrypoints — it causes crash loops on non-fatal errors
- Use explicit error handling with clear log messages:

```bash
echo "Running migrations..."
python manage.py migrate --noinput || {
    echo "WARNING: Migration failed, continuing..."
}

echo "Starting application..."
exec "$@"
```

---

## 7. Testing

### Testing Pyramid
```
    /\          E2E / Smoke Tests (few)
   /  \         Integration Tests (some)
  /    \        Unit Tests (many)
 /______\
```

### Smoke Tests (Required)
Every deployment pipeline MUST have a smoke test that runs against the live deployment:

```python
# scripts/smoke_test.py
def test_full_cycle():
    # 1. Health check
    assert requests.get(f"{BASE}/api/v1/health/deep").status_code == 200

    # 2. Auth
    token = login(admin_user, admin_pass)
    assert token is not None

    # 3. Core business flow
    resource = create_resource(token, test_data)
    assert resource.status_code == 201

    # 4. Verify via GET
    fetched = get_resource(token, resource.json()["id"])
    assert fetched.status_code == 200

    # Cleanup
    delete_resource(token, resource.json()["id"])
```

### Health Check Validation
Deployment scripts MUST wait for the **deep** health check (not just shallow) before considering a rollout complete:

```bash
for i in $(seq 1 20); do
    if curl -sf http://localhost:8000/api/v1/health/deep; then
        echo "Service healthy"
        break
    fi
    echo "Waiting... (attempt $i)"
    sleep 5
done
```

### Test Requirements
- Smoke tests must not be hardcoded to specific data (use unique test namespaces like `PRD-SMOKE-`)
- Always clean up test data (use `try...finally` or fixture teardown)
- Keep smoke tests in sync with API changes — include smoke test updates as a mandatory step in API refactoring

### Linting in CI
- `ruff check` (Python) / `eslint` (JS) MUST pass before build
- Add to Dockerfile as a build step or CI gate

---

## 8. Observability

### Logging
- Structured JSON logs in production
- Always log: request ID, service name, timestamp, severity
- NEVER log secrets, tokens, or passwords
- Clear startup logging showing configuration status:

```python
log.info("Sentry initialized successfully")
log.warning("sentry-sdk not installed. Error tracking disabled.")
log.info("Database connected, pool size: %d", pool_size)
```

### Health Checks (see Section 3)
Every service MUST expose `/api/v1/health/deep` for automated deployment verification.

### Monitoring
- Container restart loops MUST trigger alerts
- Monitor `pg_stat_activity` for connection leaks
- Use UptimeRobot or equivalent for external uptime checks

---

## 9. Deployment

### Pre-Deployment Checklist
- [ ] Registry prefix matches between docker-compose and deploy script
- [ ] Dockerfiles have ARG/ENV declarations for all `VITE_*` variables
- [ ] Build arguments contain production URLs (no localhost)
- [ ] `ruff check` / `eslint` passes
- [ ] Smoke tests pass against staging
- [ ] Pre-deployment verification script passes

### Docker Build
```bash
docker build -t ${REGISTRY}/service:latest \
  --build-arg VITE_API_URL=https://api.prod.com \
  .

# Verify no localhost in build output
grep -r "localhost:8000" dist/ && exit 1 || echo "Build OK"
```

### Post-Deployment Verification
- [ ] All containers running and healthy
- [ ] Nginx config tested and reloaded
- [ ] Deep health check passes
- [ ] Frontend bundles contain production URLs (grep for localhost — must return empty)
- [ ] Domain routing verified with `curl -H 'Host: domain.com' ...`
- [ ] Smoke test passes against production

### Nginx / Reverse Proxy
- Use `handle` not `handle_path` (Caddy) for API routes to preserve prefixes
- Always add explicit WebSocket routing (`/ws/* -> backend:8000`)
- Always run `nginx -s reload` after config changes
- Test config before reload: `nginx -t`
- NEVER rely on `default_server` for important routes — use explicit `server_name`

### Docker Network
- Ensure services are connected to the correct networks (proxy-tier, internal, etc.)
- Verify network connectivity in post-deployment checks
- Document the network topology in the project README

### Image Management
- Single source of truth for registry prefix (JSON config file)
- Verify registry prefix consistency across build, compose, and deploy scripts
- Use `--no-cache` on builds when critical changes (migrations, env vars) occur

---

## 10. Microservices & Communication

### Internal Service Communication
- Use HMAC-SHA256 signatures or mTLS for inter-service webhooks
- NEVER trust unauthenticated HTTP requests on the internal network
- Use a message broker (Redis Streams, RabbitMQ) for async communication

### Saga Pattern (Distributed Transactions)
- Store saga state in persistent storage (Redis/Postgres) before each transition — NOT in memory
- If a saga crashes mid-step, a watchdog worker must recover/rollback in-flight transactions
- Use Transactional Outbox pattern: save the command intent in the same DB transaction as business logic, then relay to the target service

### API Gateway
- Route all external traffic through a single entry point (Nginx / Caddy / API Gateway)
- Implement rate limiting at the gateway level
- Gateway handles SSL termination, routing, and logging

---

## 11. Dependency Management

### Python
- Track ALL dependencies in `requirements.txt` or `pyproject.toml`
- Use `pip freeze > requirements.txt` before deployment to capture exact versions
- Pin major versions: `sentry-sdk>=1.39.0,<2.0.0`
- Never rely on transitive dependencies being available

### Base Images
- Use stable, named versions: `python:3.12-slim-bookworm` (NOT `python:3.12-slim` which may alias to testing)
- Ensure `curl` is included in Docker images (required for health checks)
- Avoid Debian "Testing" or "Sid" mirrors — they are unstable

### Dockerfile Structure
```dockerfile
FROM python:3.12-slim-bookworm AS builder
RUN pip install --no-cache-dir -r requirements.txt
# ... build steps

FROM python:3.12-slim-bookworm AS runner
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY . .
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s \
  CMD curl -sf http://localhost:8000/api/v1/health/deep
CMD ["gunicorn", "app.main:app", "--workers", "4", "--worker-class", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000"]
```

---

## Quick Reference: Most Common Failure Modes

| Failure | Symptom | Root Cause | Standard |
|---------|---------|------------|----------|
| Container crash loop | `Restarting (1)` | Missing import, missing dependency, secret still dev default | Sections 2, 6, 5 |
| 502 Bad Gateway | Nginx/Caddy returns 502 | Backend crash loop OR missing deps in container | Sections 6, 11 |
| 404 on API | Endpoint not found | Caddy `handle_path` stripping prefixes OR missing URL routes | Section 9 |
| WebSocket failure | `WebSocket connection failed` | Missing `/ws/*` rule in reverse proxy | Section 3 |
| 500 errors / too many clients | `FATAL: sorry, too many clients` | Bypassing PgBouncer, CONN_MAX_AGE too high | Section 4 |
| Auth failures | 401/403 | Password desync, JWT secret mismatch between services | Sections 5, 10 |
| Products/images not showing | Empty database | Schema migration not run | Section 4 |
| Frontend broken in prod | Calls to `localhost:8000` | VITE_* not passed as build args | Section 9 |
| Cross-tenant data leak | User sees other org's data | ViewSet missing tenant filter (fail-open) | Section 5 |

---

## Enforcement

1. **Automated:** `ruff` linting, static analysis, CI gates
2. **Review:** Architectural reviews must reference this standard
3. **Post-mortem:** Every incident should identify which standard was violated (or what's missing from the standard)
4. **Living document:** Update this standard when new failure patterns are discovered

---

**Maintained by:** Engineering Team
**Review cadence:** Quarterly
**Contributions:** Open a PR with your incident pattern reference
