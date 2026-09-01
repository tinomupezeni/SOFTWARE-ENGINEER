# PROJECT GUIDE ADAPTER — SMEPulse (Opportunity Radar)

> Bridge between `dev-logs/PRINCIPAL ENGINEER/engineering-guides/` and the SMEPulse
> monorepo. Records which guides were ported, where they landed, and the stack
> adaptations required. SMEPulse is Node/TypeScript throughout, unlike most guide
> examples (Python/FastAPI/Django) — every "Ported sections" entry below notes the
> translation.

## Project

- **Name:** SMEPulse (Opportunity Radar)
- **Path:** `/home/tino/Projects/SMEPULSE_II`
- **Stack:** npm workspaces + Turborepo. `apps/webhook` — Express 4 + TypeScript,
  **Twilio** WhatsApp webhook (migrated off the direct Meta Cloud API on
  2026-08-03), conversational state machine (onboarding → main menu → digest →
  eligibility → roadmap). `apps/admin` — Next.js 16 / React 19 admin portal
  (Server Actions, single-shared-credential auth). `packages/database` —
  shared Prisma 5 schema/client over PostgreSQL (`Category`, `Province`,
  `OpportunityInteraction` added for the category/province taxonomy and the
  notified→shown→viewed→applied funnel).
- **Deploys to:** Self-hosted VM (specific host/orchestration not yet decided —
  open gap, see below).

## WhatsApp provider: Twilio (migrated 2026-08-03, off the direct Meta Cloud API)

Twilio's WhatsApp Content Templates are **static** — a `quick-reply`/`list-picker`
template's button/item IDs and count are fixed at creation+approval time.
Confirmed via Twilio's own docs (`twilio/quick-reply`, `twilio/list-picker`
schemas) and a live `twilio-node` GitHub issue about per-send item-array
substitution not working reliably. Only body/title *text* reliably supports
`{{n}}` variable substitution — this breaks the old Meta-based pattern of
encoding a dynamic opportunity ID directly into a button's payload
(`ready_${opp.id}`).

**Resolution:** static, positional button/item IDs (`ready`, `need_help`,
`digest_1`/`digest_2`/`digest_3`), resolved against the *actual* opportunity
via two fields on `User` — `pendingOpportunityId` (what `ready`/`need_help`
currently refers to) and `lastDigestOpportunityIds` (ordered IDs from the most
recent digest, so `digest_1..3` resolve correctly). Category and province
picker item IDs are the `Category.name`/`Province.name` strings themselves —
provinces are truly static (Zimbabwe's 10 never change); categories are
"near-static" by deliberate choice (see Open Gaps below).

**Status as of 2026-08-04: all six Content Templates exist, created live via
the Content API** (not the Console UI) using real account credentials —
scripted rather than hand-created, so re-creating them (e.g. for a second
environment) is just re-running the same `client.content.v1.contents.create()`
calls with the shapes below. The account is currently on Twilio's **shared
public Sandbox** (`whatsapp:+14155238886`), not a real approved WhatsApp
Business sender — fine for dev, but every test phone number must first send
`join <sandbox-code>` to that number before the bot can message it.

**Wire-format gotcha worth remembering:** the `twilio` Node SDK's
`content.v1.contents.create()` does **not** camelCase-convert its params for
this resource — despite the `.d.ts` types suggesting `friendlyName`/
`twilioQuickReply` etc., the actual HTTP body must use the raw wire format
(`friendly_name`, and type keys as literal strings like `"twilio/quick-reply"`
/ `"twilio/list-picker"`) or the API rejects it with "Invalid types." Confirmed
by reading `node_modules/twilio/lib/rest/content/v1/content.js` directly — the
`create()` method forwards `params` as JSON verbatim, no transformation.

| Purpose | Type | Body / structure | Env var | SID (created 2026-08-04) |
|---|---|---|---|---|
| Main menu | `quick-reply` | Body: "What would you like to do?" — actions: `{id:"menu_deals", title:"View Today's Deals"}`, `{id:"menu_request", title:"Request Deal"}`, `{id:"menu_change", title:"Change Preferences"}` | `TWILIO_CONTENT_SID_MAIN_MENU` | `HX7537d2cb4ad0933d4f242294a0b82b72` |
| Category picker | `list-picker` | Body includes welcome text — one item per active `Category`, `id` = the category's `name` exactly (e.g. `"Agriculture"`), max 10 | `TWILIO_CONTENT_SID_CATEGORY_PICKER` | `HX10feccab888bec81631eeab298f60158` |
| Province picker | `list-picker` | Body: "Which province is your business in?" — one item per `Province`, `id` = province `name` exactly (e.g. `"Harare"`), all 10 seeded provinces | `TWILIO_CONTENT_SID_PROVINCE_PICKER` | `HX876e68184b155c6bea759182879ef4b5` |
| Opportunity digest | `quick-reply` | Body with `{{1}}`-`{{6}}` variables (title/value pairs for up to 3 opportunities) — actions: `{id:"digest_1", title:"View Deal 1"}`, `digest_2`, `digest_3` (static, positional) | `TWILIO_CONTENT_SID_DIGEST` | `HXa858ded1ce8f46220cc905b856da72a6` |
| Eligibility confirm | `quick-reply` | Body with `{{1}}`-`{{3}}` variables (title, value, checklist text) — actions: `{id:"ready", title:"Yes, I'm ready!"}`, `{id:"need_help", title:"No / Need help"}` | `TWILIO_CONTENT_SID_ELIGIBILITY_CONFIRM` | `HX5c6aadb3f24e0898a21636db87f65ed9` |
| New opportunity broadcast | `twilio/text`, submitted for WhatsApp approval (category `UTILITY`) | Body with `{{1}}`-`{{4}}` for category/title/value/deadline: `"📢 New {{1}} opportunity: {{2}} ({{3}}). Deadline {{4}}. Reply DEALS on WhatsApp to view and check your eligibility."` | `TWILIO_CONTENT_SID_NOTIFY_BROADCAST` (`apps/admin`) | `HXb678e445029b20e743aa12d290ef4fd8` — approval **submitted, status "received"**, not yet approved; broadcasts will fail until Meta approves it |

**Recreating these**: the 5 session-reply templates need no approval (list-picker
can *never* be approved for business-initiated use; quick-reply ≤3 buttons used
only in-session doesn't require it either) — only the broadcast template goes
through Meta review. If categories change enough to warrant it, re-run the
category-picker creation call with the updated list and update the env var —
old SID can be left orphaned or deleted via `client.content.v1.contents(sid).remove()`.

Also required: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_WHATSAPP_NUMBER`
(format `whatsapp:+1415...`), `TWILIO_WEBHOOK_URL` (the exact public URL Twilio
POSTs to — required for signature validation; changes if tunneling via ngrok
without a static domain). Env var slots exist in `apps/webhook/.env` and
`apps/admin/.env` as empty placeholders — nothing in code creates the
templates themselves, that's a manual Twilio Console step.

**Residual uncertainty, not yet empirically verified:** Twilio's docs confirm
`quick-reply` taps return `ButtonPayload`/`ButtonText` on the inbound webhook,
but did not confirm whether `list-picker` selections (used for category/province
pickers) use the same field name or a different one. `apps/webhook/src/app.ts`
reads `req.body.ButtonPayload` for both — **verify this against a real list-picker
tap once live templates exist**, and adjust the extraction in `app.ts` if it's
actually a different field.

## Guides applied

### 8. E2E Testing → fit: high
- **Ported sections:** test-tier structure (unit vs integration), composable
  fixtures over Page Object Models, dynamic/unique test data (no hardcoded phone
  numbers or accounts), strict test isolation via per-test DB truncation.
- **Landed in:** `apps/webhook/tests/{unit,integration,fixtures}`,
  `apps/webhook/vitest.config.ts`.
- **Adaptation:** Guide assumes Playwright (web) + pytest (API) as defaults.
  SMEPulse has no browser-driven UI test target yet (`apps/admin` deferred —
  priority was the webhook state machine); the API tier uses **Vitest + Supertest**
  instead of pytest, since the whole stack is TypeScript. Playwright should be
  adopted when `apps/admin` gets test coverage.
- **Compliance:** [x] unit tests (state machine, all branches) [x] integration
  tests against real ephemeral Postgres [x] dynamic test data via faker
  [x] CI-gated (`.github/workflows/test.yml`, now two jobs: `webhook-tests` with
  the Postgres service, `admin-tests` fully mocked/no DB) [ ] UI E2E for
  `apps/admin` (not yet started — `apps/admin/tests/unit/actions.spec.ts` covers
  `publishAndNotifyOpportunity` at the unit level only, no Playwright yet)

### 6. Database Engineering → fit: high
- **Ported sections:** "never mock Postgres with SQLite/in-memory" rule (ephemeral
  real Postgres in CI + local tests), idempotent-write discipline, UUIDv7 PKs,
  `TIMESTAMPTZ` over bare `TIMESTAMP`, single cached connection pool per process,
  explicit `onDelete` referential actions, JSONB storing real structured JSON
  (not double-encoded strings).
- **Landed in:** `docker-compose.test.yml` (ephemeral `postgres:16-alpine`, no
  named volume, bound to `127.0.0.1`), `.github/workflows/test.yml` service
  container, `apps/webhook/tests/global-setup.ts`, `packages/database/prisma/schema.prisma`
  (`@default(uuid(7))`, `@db.Timestamptz(3)` on every `DateTime`, explicit
  `onDelete` on every relation), `packages/database/index.ts` (exports a
  `globalThis`-cached `prisma` singleton — every consumer across both apps
  imports this instead of calling `new PrismaClient()` itself).
- **Adaptation:** Guide assumes SQLAlchemy/Alembic with a formal
  upgrade/downgrade migration cycle. SMEPulse uses **Prisma with `db push`**
  (no migration history yet) — this is a real gap, not a stylistic choice; see
  open gaps below. UUIDv7 syntax (`uuid(7)`) confirmed working on the installed
  Prisma 5.22.0 via `prisma validate` before adopting it.
- **Fixed this pass (2026-08-03):** `eligibilityChecklist` was being
  `JSON.stringify()`'d before being passed into a `Json`-typed field, so it was
  stored as a JSON *string* inside JSONB rather than a real array — defeated
  JSONB entirely and required a defensive `JSON.parse()` on every read (now
  removed). Three separate `new PrismaClient()` instances existed across
  `apps/admin` alone (one per actions file) plus two more in `apps/webhook` —
  a real connection-pool-leak risk under Next.js dev-mode hot reload, now a
  single shared singleton. `OpportunityInteraction`'s FK to `Opportunity` had
  no explicit `onDelete`, which meant "Archive" would have thrown a foreign-key
  violation on any opportunity with recorded engagement — verified this was a
  real reproducible bug before fixing it with `onDelete: Cascade`.
- **Compliance:** [x] ephemeral Postgres in CI, never SQLite [x] test data
  isolated per test (truncate in `beforeEach`) [x] UUIDv7 PKs [x] `TIMESTAMPTZ`
  everywhere [x] single connection pool per process [x] explicit `onDelete` on
  every relation [x] JSONB holds real JSON, not stringified JSON [ ] formal
  migration history (`prisma migrate`) [ ] statement/lock timeouts (n/a yet —
  no production migrations have run against a live table)

### 9. Performance Engineering → fit: medium (partial)
- **Ported sections:** webhook response-latency awareness (Meta will disable
  webhooks that are slow/unreliable — motivated adding the idempotency guard
  and payload-shape guard so the webhook never hangs or crashes on unexpected
  input), N+1-avoidance awareness for the `Opportunity` digest query.
- **Landed in:** `apps/webhook/src/app.ts` (idempotency short-circuit,
  malformed-payload guard, `twilio.validateRequest` signature verification
  before any DB work).
- **Adaptation:** Guide's concrete examples (FastAPI connection pools, OTel
  tracing, Core Web Vitals) don't apply to this Express/Prisma service.
  Deferred: load-testing (guide's Little's Law capacity planning) since the
  immediate priority was functional correctness, not throughput.
- **Compliance:** [x] webhook never crashes on malformed payloads [x] webhook
  never double-processes a retried message [ ] latency SLO defined [ ] load
  test run [ ] connection pool sizing reviewed (Prisma default pool, single
  Postgres instance, low traffic expected at MVP stage)

### 7. Software Security Engineering → fit: medium (partial)
- **Ported sections:** basic access control — the admin portal now requires a
  session before any page renders or any Server Function mutates data.
- **Landed in:** `apps/admin/src/proxy.ts` (Next 16's renamed `middleware.ts` —
  see the migration note in the guide-adaptation notes below), `apps/admin/src/lib/session.ts`
  (HMAC-signed cookie, no auth library), `apps/admin/src/lib/require-session.ts`
  (per-Server-Function guard — Next 16's own proxy docs explicitly warn a
  matcher change can silently stop covering a route's Server Functions, so
  `requireSession()` is called inside `createOpportunity`/`deleteOpportunity`/
  `publishAndNotifyOpportunity`/category actions too, not just at the proxy layer).
- **Adaptation:** Deliberately **not** NextAuth or any auth library — this app's
  own `AGENTS.md` flags Next 16 as having breaking changes from training-data
  assumptions, so a hand-rolled, dependency-free session was lower-risk than an
  external auth library of unverified Next-16 compatibility.
- **Compliance:** [x] all routes gated except `/login` [x] mutating Server
  Functions independently verify the session [x] password never stored in
  plaintext (bcrypt hash) [ ] per-person accounts (single shared credential by
  deliberate choice, not per-person — see PRD's "small team" framing) [ ] phone
  number PII handling/retention review still not done.

## Open gaps (guides not yet satisfied)

- [ ] 6. Database — adopt `prisma migrate` instead of `db push` before this
  goes anywhere near a shared/production database with real data to lose.
- [ ] 4. SRE + 10. Deployment — no SLOs, no docker-compose.prod.yml, no
  resource caps. Blocked on finalizing the VM target (host, orchestration —
  plain Docker Compose vs Coolify — not yet decided).
- [x] ~~7. Security — admin portal has no authentication~~ resolved: single
  shared-credential session (see above). Still open: phone-number PII review,
  per-person accounts if the team grows.
- [ ] 8. E2E — `apps/admin` (Next.js) has zero browser-driven test coverage;
  Playwright not yet introduced (only a unit-level test for the broadcast action).
- [ ] 5a. Observability — no structured logging, no correlation IDs, no error
  tracking (Sentry or equivalent) wired up.
- [x] ~~six Twilio Content Templates must exist~~ resolved 2026-08-04: all six
  created live via the Content API, real SIDs in both `.env` files — see
  "WhatsApp provider: Twilio" above. Still open: the broadcast template's
  WhatsApp approval is submitted but not yet granted (status "received").
- [ ] **Still on Twilio's shared Sandbox** (`+14155238886`), not a real
  approved WhatsApp Business sender. Fine for dev/testing (every test number
  must `join <sandbox-code>` first) — moving to a real sender number is a
  pre-launch requirement, not yet scheduled.
- [ ] **Not yet wired end-to-end**: `TWILIO_WEBHOOK_URL` is still an empty
  placeholder — needs a publicly reachable tunnel (ngrok or similar) pointed
  at local dev, or a real deployed URL, configured as the Sandbox's "when a
  message comes in" webhook in the Twilio Console, before any live message
  reaches the bot.
- [ ] **Unverified:** whether `list-picker` inbound replies use `ButtonPayload`
  (assumed) or a different field — must confirm against a real tap once
  `TWILIO_WEBHOOK_URL` is wired up and a real device has joined the sandbox
  (see "WhatsApp provider: Twilio" above).
- [ ] Category picker is a "near-static" Content Template by deliberate choice
  — adding a new `Category` requires an operational runbook step (re-run the
  category-picker creation call with the updated list, update the env var, no
  code change needed) rather than being fully dynamic.
- [ ] The broadcast loop in `publishAndNotifyOpportunity` is sequential, no
  queue/batching — fine at MVP user counts (per guide #9's capacity-planning
  notes), revisit before user counts grow past a few hundred per category.

## Review cadence

Re-open this adapter each review cycle (see `../growth_tracker.md`). If a guide
is updated in the library, re-port changed sections and bump version.

- **Adapter version:** 0.5
- **Last synced:** 2026-08-04
