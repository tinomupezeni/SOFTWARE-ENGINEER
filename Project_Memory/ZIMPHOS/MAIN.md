# ZIMPHOS — Memory Index

**Last updated:** 2026-11-24
**Project repo:** /home/shadowe/Projects/Zimphos (GitHub: winstonjthinker/Zimphos)
**One-line what-it-is:** Consignment stock visibility and reconciliation system for ZimPhos — lets ZimPhos independently verify what its distributors report (stock, counts, payments) rather than trusting the distributor's own figures.

Read this file first, every session, before touching the codebase. If
something here is stale or wrong, fix it in the same session you notice.

## What this project is
ZimPhos consigns stock to distributors and needs to reconcile what the
distributor's own systems report against independently-sourced counts and
movements. The design's core principle (see project `CLAUDE.md`) is that the
distributor's own figures are never authoritative — the backend ingests
independent sources (counting phone app, adapters) and compares them.
Backend is Django/DRF; frontend is React/Vite/TypeScript with a generated
API client from `docs/contracts/openapi.yaml`. The frontend has two
"shells": a desk app (ZimPhos staff: audit, finance, admin) and a field app
(drivers/shop staff doing counts, deliveries, adjustments), the latter
built installable/offline-first (PWA, IndexedDB outbox).

## Current state
- **`main` is current as of 2026-11-24**: PR #7 (contract: evidence photos,
  collections, count checks) and PR #5 (phone app rework: driver app, desk
  shop page, collections) are both merged. PR #5 depended on #7; merging #5
  required resolving contract/type-generation conflicts with #7 (see
  `change-history/2026-11-24-pr7-pr5-merge.md`).
- **Backend:** has migrations, Celery, baseline seed, Docker setup (per
  commit history: "complete production readiness with migrations, celery,
  baseline seed and docker setup"). A `/messages` endpoint was recently
  added to the contract/backend/frontend-types chain.
  - **Found 2026-11-24, fixed locally, not yet committed:** `config/wsgi.py`
    never existed despite `WSGI_APPLICATION` pointing at it — the Django
    dev server (and any real WSGI server) crashes on boot. See
    `Backend_and_API/ZIMPHOS-2026-11-24-missing-wsgi-module.md`. The fix
    (a standard `config/wsgi.py`) is sitting locally in the working tree;
    commit it on the next backend-touching branch.
  - Confirmed 2026-11-24: `docker compose up` (postgres, redis, backend,
    celery_worker, celery_beat) runs cleanly once `wsgi.py` exists, after
    `manage.py migrate` and `manage.py seed_baseline`. `GET /api/products`
    correctly returns 401 unauthenticated — login/logout endpoints are
    still missing (see gap list below), so there's currently no way to
    authenticate against the real backend from the frontend.
- **Frontend:** as of PR #3 (`experimental` → `main`, merged 2026-11-23),
  every planned screen exists: desk (today/overview, stock
  check/reconciliation, alerts, distributor detail, money/receivables,
  BRD targets, desk actions — counts/write-offs/alerts/payments/
  deliveries, admin — connections/settings/audit trail), plus a full
  offline field app (surprise counts, delivery sign-off w/ signature,
  damage reports, sales upload, statement, offline outbox via IndexedDB)
  and an installable PWA shell. Runs against mock data by default
  (`npm run dev:mock`).
- **Contract:** `docs/contracts/openapi.yaml` is the source of truth; PR #3
  made several corrective changes to it (weekly data as `WeeklyPoint[]`
  not an object, new `OverviewDistributorRow`/`RecentPayment` schemas,
  nullable `ReconciliationLine.counted`/`counted_raw` meaning "never
  counted" vs. 0). A contract-conformance test
  (`frontend/src/test/contract.test.ts`) validates all recorded mock
  responses against the OpenAPI schema on every CI run.
- **Known backend/frontend contract gaps** (found by running the real
  `main` backend against the frontend's expectations, documented in PR #3's
  `docs/notes/2026-11-24-backend-check-for-tino.md`, not yet fixed as of
  this writing):
  1. Re-submitting a count with the same `client_id` records it twice
     (breaks the offline outbox's retry-safety assumption).
  2. `GET /messages` returns every shop's messages to any user (no
     scoping) — this is the kind of issue the project's own
     "distributor data scoping enforced in backend querysets"
     non-negotiable exists to prevent.
  3. Any user can change the reporting currency (no authorization check).
  4. Seed users have roles outside the contract (`GLOBAL_ADMIN`…), so the
     frontend shows "no access."
  5. `weekly: {}` and empty `receivables`/`summary` objects returned
     instead of the contract's expected shapes (frontend now tolerates
     this, but it's still a backend contract violation).
  6. `POST /payments` has no idempotency key.
  7. `signature` is optional on POD (proof of delivery) in the backend,
     though the field app always captures one.
  - Still missing entirely: login/logout + CSRF endpoints.
- **PR #3 review (2026-11-24):** reviewed via ECC `code-review` skill at
  high effort against the SOFTWARE-ENGINEER Code Review guide (guide 24).
  5 "important"-severity findings logged individually in
  `Frontend_and_UI/ZIMPHOS-2026-11-24-*.md` (an off-site-link-guard
  whitespace bypass in the Inbox screen, an unhandled nested throw in the
  offline outbox's failure path, a SignaturePad regression that can strand
  the signing gesture on devices without pointer capture, a mock-API
  fallback returning a status value outside its own contract enum, and two
  unreconciled "today" date helpers disagreeing across the Harare midnight
  window) plus 5 lower-severity maintainability nits (not individually
  logged — see the PR review conversation/findings for detail if needed).
  Fixes for the 5 important findings are in progress as of this entry.
- **PR #7 and #5 review (2026-11-24):** reviewed via ECC `code-review` skill
  against the same guide (guide 24). PR #7 (contract-only): 4 findings, all
  fixed and merged — `collection_handover` nullability mismatch between
  `openapi.yaml` and `api-types.ts`, an undocumented ordering dependency
  between `SubmitCountRequest.started_at` and `photo_evidence.taken_at`
  for the "too-fast count" check, and a wording contradiction in
  `docs/contracts/README.md` between "never reject on a finding" and
  `AdjustmentItem.decision_note`. PR #5 (app code): 2 findings, both
  fixed and merged — `LocationCheck.tsx` rendered `Math.round(null)` as
  "±0 m" instead of "unknown" GPS accuracy, and `AlertFacts.tsx` silently
  dropped any `null`-valued detail field instead of rendering "—".

## Map
- `architecture/` — frontend shell/screen structure, offline outbox design.
- `decisions/` — not yet populated; add as real "why" decisions surface
  (e.g. why mock-mode exists, why the contract test only covers GET/
  recorded responses).
- `implementation/` — not yet populated; candidate: the offline outbox
  retry/dedup mechanism once its fix lands.
- `prompts/significant-tasks.md` — not yet populated.
- `change-history/` — `2026-11-24-pr7-pr5-merge.md` (PR #7/#5 review,
  fixes, and merge, plus the merge-conflict resolution between them).

## Known gaps / don't trust this for
This memory file was created from a single session's PR review plus the
top-level `CLAUDE.md` and PR #3's own notes — it has not been cross-checked
against the actual backend code, the full frontend source, or
`docs/system-design/`. Verify anything load-bearing against the real code
before acting on it. In particular: the backend contract-gap list above is
reported secondhand from PR #3's notes, not independently re-verified in
this session.

## Related
- Project `CLAUDE.md` (non-negotiables, workflow) and
  `docs/system-design/` (system design docs) are the project's own
  authoritative references — read those directly, this file only indexes
  what's been learned across sessions.
- Bug log entries: `Frontend_and_UI/ZIMPHOS-2026-11-24-*.md`,
  `Backend_and_API/ZIMPHOS-2026-11-24-missing-wsgi-module.md`.
