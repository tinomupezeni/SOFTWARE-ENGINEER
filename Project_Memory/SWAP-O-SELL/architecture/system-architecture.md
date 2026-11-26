# SWAP-O-SELL — System Architecture

**Last updated:** 2026-11-26

## Components
- **`backend/`** — Django 5.2 / DRF 3.15 API. Modular apps under
  `backend/modules/` (`auth`, `listings`, `comments`, `messaging`,
  `admin_api`, ...) plus core models in `backend/swapapp/`. JWT auth via
  `djangorestframework-simplejwt`. Google sign-in via `google-auth`. Served
  by `gunicorn` in production, mounted at `/api/*`.
- **`swappify-social-hub/`** — public storefront. React + Vite +
  TypeScript + shadcn/Tailwind, originally bootstrapped from Lovable.dev
  (hence leftover scaffold artifacts like the default favicon). Built to a
  static bundle, served by Nginx in production, mounted at `/` (all
  non-`/api/`, non-`/admin/` paths).
- **`admin/`** — separate internal admin SPA (`swap-o-sell-admin`). React +
  Vite + TypeScript, no Tailwind/shadcn — plain React + `lucide-react`.
  Converted from a Vite dev server to a static Nginx image for production.
  Mounted at `/admin/*` behind the same reverse proxy/domain as the
  storefront.
- **PostgreSQL 16** (`postgres:16-alpine`) — production database, isolated
  Compose service, no host port published, named volume for persistence.
  Local/dev defaults to SQLite when `DATABASE_URL` is unset.

## Data flow
Browser → reverse proxy (Caddy, Coolify-managed on restk-vps) → one of:
- `/api/*` → `backend` container (Django/DRF, gunicorn)
- `/admin/*` → `admin` container (Nginx serving the admin SPA bundle)
- everything else → `swappify-social-hub` container (Nginx serving the
  storefront bundle, which itself proxies `/api/` to `backend` over the
  Compose network in local/non-Caddy setups, e.g. `swappify-social-hub/nginx.conf`)

All three app containers talk to `backend`, which is the only service with
access to PostgreSQL. Public API identifiers for users and products are
UUIDs (`public_id`); internal foreign keys and primary keys stay integers.
See [[public-uuid-identifiers]] in `decisions/`.

## Deployment topology
Three known deployment targets observed in the dev-log/report history:
- **`restk-vps`** — production. Compose project name `swaposell`. No
  application host ports published; reached only through the existing
  Coolify-managed Caddy proxy over the external `proxy-tier` Docker
  network. PostgreSQL on a private `swaposell-internal` network, backend
  is the only service that joins it. Domain:
  `swaposell.restksolutions.co.zw` (also `swaposell.hpc.ac.zw` has been
  used/tested). GitHub Actions deploys to this host over SSH by streaming
  the checked-out commit (private repo, no token/clone credential stored
  on host) — see `deploy/deploy.sh`, `deploy/README.md`,
  `docker-compose.production.yml`.
- **`mywealth-vm`** — a secondary test deployment target, dedicated host,
  Apache already listening on port 80 (left untouched), temporary host
  ports used instead of a reverse proxy (backend `:8000`, storefront
  `:8080`, admin `:5174`). Used the Compose-managed Postgres 16 rather than
  the VM's pre-existing host Postgres 14. No DNS/TLS was ever finished
  here — test-only, not a production target.
  Cross-reference: `DevOps_and_Infrastructure/SWAP-O-SELL-2026-10-24-vm-topology-mismatch.md`.
- **Local dev** — `docker compose up --build` from the repo root
  (`docker-compose.yml`), or running `backend`/`swappify-social-hub`/`admin`
  directly without Docker. Local non-Docker backend defaults to SQLite and
  has a dependency pitfall — see [[sqlite-dev-postgres-driver]] in
  `implementation/`.
