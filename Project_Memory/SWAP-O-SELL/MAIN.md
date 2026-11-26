# SWAP-O-SELL — Memory Index

**Last updated:** 2026-11-26
**Project repo:** /home/shadowe/Projects/swap-o-sell
**One-line what-it-is:** A swap-plus-cash marketplace (Lovable-bootstrapped storefront + separate admin SPA + Django/DRF backend) where buyers can trade a listing, cash, or both for a seller's item.

Read this file first, every session, before touching the codebase. It
should be enough to understand what the project is and why it's built the
way it is without reading source. If something here is stale or wrong,
fix it in the same session you notice — don't leave it for later.

## What this project is
Swap-O-Sell is a consumer marketplace with three deployable units: a public
storefront (`swappify-social-hub/`, React + Vite + shadcn/Tailwind, originally
bootstrapped from Lovable.dev), a separate internal admin SPA (`admin/`, React
+ Vite, static Nginx image in production), and a Django 5 / DRF backend
(`backend/`). Its defining feature beyond a normal marketplace is **swap
offers**: a buyer can propose one of their own active listings plus an
optional cash top-up in exchange for a seller's swap-enabled listing, handled
through a dedicated `SwapOffer` model rather than forcing two-sided trades into
the existing single-product `Order` model. All public-facing user/product
identifiers are UUIDs (`public_id`) layered over stable internal integer PKs.

## Current state
- **Live/deployed:** Production runs on `restk-vps` (Coolify-managed Caddy
  proxy, Compose project `swaposell`, isolated PostgreSQL 16 on a private
  network, no host ports published) and was also stood up on `mywealth-vm`
  for testing (temporary host ports, Apache left untouched). Domain:
  `swaposell.restksolutions.co.zw` (restk-vps); a second domain
  `swaposell.hpc.ac.zw` has also been used, which is what surfaced the
  VITE_API_URL/admin-base-path bugs below.
- **Recently completed:** PostgreSQL migration (replacing a silent SQLite
  fallback), public UUID identifiers for users/products, swap-offer MVP
  (create/accept/decline/withdraw, no settlement yet), messaging UUID
  contract fixes, admin/client user separation in the admin Users page,
  proximity-distance product listings, Google sign-in wired into the
  storefront (commits `64302bd`, `aeb51ad` — `VITE_GOOGLE_CLIENT_ID` now
  flows through as a build arg alongside `VITE_API_URL`).
  Also recently fixed: `VITE_API_URL` silently never being baked into any
  production storefront build (every prior production deploy's storefront
  was hardcoded to call the end user's own `localhost:8000` — see
  [[vite-api-url-never-baked-in]]), and the admin SPA serving a blank page
  under its `/admin/` base path because its Nginx config SPA-fallbacks JS/CSS
  asset requests to `index.html` (see [[admin-spa-blank-page]]).
- **In progress / deferred:** Swap-offer **settlement** (inspection, payment
  verification, pickup OTP, product locking, disputes) is explicitly not
  built — accepted offers don't mark inventory sold yet. Scheduled
  `pg_dump` backups + restore drill for production Postgres are not set up.
  DNS/TLS for `mywealth-vm` deployment was never finished (test-only).
- **Known broken, not yet fixed:** 4 pre-existing backend test failures in
  `modules.listings` (`TrustHardeningTests`, `test_home_sections_validate_partial_location`)
  that predate the `public_id` UUID migration and were never updated to match
  it — confirmed unrelated to unrelated later changes via `git stash`. See
  [[stale-tests-after-uuid-migration]].

## Map
- `architecture/` — what the system looks like now (components, data flow,
  boundaries). Derivable from code in principle, kept here so an agent
  doesn't have to re-derive it every session.
- `decisions/` — **why** it's built this way, where "why" isn't visible
  from reading the code (alternatives considered, constraints, trade-offs
  accepted). Don't duplicate code-derivable facts here.
- `implementation/` — notes on specific non-obvious mechanisms (a tricky
  hook, an integration quirk) worth remembering without re-reading the
  code each time.
- `prompts/significant-tasks.md` — prompts that produced non-obvious
  architectural output worth reusing or referencing, not a log of every
  prompt.
- `change-history/` — dated entries, one per session/change that altered
  architecture or decisions. Not a diary of every commit — only entries
  that would otherwise force a re-read of git history to understand "how
  did we get here."

## Known gaps / don't trust this for
- This memory set was initialized retroactively on 2026-11-26 from existing
  dev-log/report history, not written incrementally — verify anything
  load-bearing against the actual code before acting on it.
- The dev-log/report filename prefix for this project has been inconsistent
  historically (`SWAP-O-SELL`, `SWAPOSELL`, and one stray `Market-Link`
  entry that is actually this project's admin-routes bug). Search all three
  when looking for this project's history; use `SWAP-O-SELL` going forward.
- Payment and WhatsApp integration credentials/flows mentioned as deferred
  in deployment reports — status not re-verified in this pass.

## Related
- Bug/issue log entries for this project: see `SOFTWARE-ENGINEER`
  technical-area folders, filename prefix `SWAP-O-SELL-` (also check
  `SWAPOSELL-` and the one `Market-Link-2026-11-03-admin-routes-not-dual-mounted-404-through-proxy.md`).
- Reports: see `SOFTWARE-ENGINEER/reports/`, filename prefix `SWAP-O-SELL-`
  / `SWAPOSELL-`.
