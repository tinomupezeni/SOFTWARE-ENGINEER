# Flutter Mobile — Home Rebuilt as a Real Dashboard

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed (tests, real backend, and real-device check all verified)

## Summary
Replaced the Home tab's placeholder welcome screen with a real dashboard —
sales performance, stock health, and a "needs restocking" list drawing on
live data — built entirely on an existing, already-working backend
endpoint (`/api/v1/dashboard/`) rather than new aggregation logic.

## Context / Trigger
User feedback: "the home, i am not happy with it at all." Clarified via a
quick multi-select question that the core complaint was the screen being
essentially empty (just a welcome message), not a missing-feature request
or a visual-design complaint — so the fix was to give it real content, not
reskin it.

## Scope
Included: a new `dashboard` feature module (domain/data/presentation
layers matching the rest of the app), wired to the existing
`/api/v1/dashboard/` endpoint, replacing the old `home` feature entirely.

Excluded (deliberately): a revenue trend chart/sparkline (the endpoint
returns `revenue_trend`/`top_products` arrays, but charting is a real
scope increase, not something the "stop being empty" complaint asked for)
and Tasks/Deals stat tiles (the backend returns them, but this mobile app
has no Tasks/Deals screens at all yet — showing a number with nothing to
tap would be clutter, not a dashboard; revisit once Phase 4/CRM-parity
builds those modules).

## Method
Delegated two read-only research tasks (backend `/api/v1/dashboard/`
contract, and the `/api/v1/products/low_stock/` shape for comparison) to
sub-agents before writing any Flutter code, to get the exact response
field names right on the first pass rather than guessing and iterating.
Confirmed the dashboard endpoint already embeds its own top-5 low-stock
list (`low_stock_products`, a reduced field set) distinct from the full
products-app low-stock endpoint — used the embedded one since it's exactly
sized for a dashboard card and avoids a second network call.

## Decisions & Findings
- **Reused the existing dashboard endpoint wholesale** rather than
  composing several already-built mobile repositories (Products/Sales)
  client-side — the backend already aggregates and caches this (60s
  server-side cache per org/period), so re-deriving it from multiple REST
  calls would be slower, more code, and could drift from what the web
  dashboard shows for the same org.
- **Deep links where real**: the "Stock health" card navigates to the
  Stock tab (`context.go`), and each "needs restocking" row navigates to
  that exact product's detail screen (`context.push('/products/:id')`,
  reusing the route built in Phase 2) — not just static numbers.
- **No chart, no Tasks/Deals tiles** — see Scope. Kept the dashboard
  honestly scoped to what this app can actually do something about today,
  consistent with the same principle applied to the Stock/Sales
  placeholders in earlier phases.
- **Widget tests exercise the real production widget**, not a hand-copied
  stand-in — an early draft of the screen test duplicated the screen's
  rendering logic to dodge the `GoRouter` dependency its navigation calls
  need; caught and replaced with a minimal real `GoRouter` harness so the
  tests actually exercise `DashboardScreen`/`_DashboardView` and its real
  `context.go`/`context.push` calls (verified navigation to both the Stock
  tab stub and a specific product-detail stub).

## Changes Made
- `lib/features/dashboard/` — new module: `DashboardEntity` (+
  `SalesSummaryEntity`, `ProductsSummaryEntity`, `ContactsSummaryEntity`,
  `LowStockProductEntity`), `DashboardModel`/`DashboardRemoteSource`/
  `DashboardRepositoryImpl`, `DashboardCubit`, `DashboardScreen` (+
  `StatTile`, sales/stock card widgets, low-stock list).
- `lib/features/home/` — removed entirely (superseded).
- `lib/core/routing/app_router.dart`, `lib/main.dart` — Home tab now
  builds `DashboardScreen`; added `DashboardRepository` to the composition
  root's `RepositoryProvider`s.
- `test/core/shell/app_shell_navigation_test.dart` — updated for the real
  dashboard content (was asserting on the old placeholder welcome text).
- New tests: `test/features/dashboard/dashboard_repository_impl_test.dart`
  (contract, via `http_mock_adapter`), `dashboard_cubit_test.dart`,
  `dashboard_screen_test.dart` (real `GoRouter` harness, including
  navigation assertions).

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing `info`-level
  style notes as prior phases).
- `flutter test` — 80/80 passing.
- `flutter build apk --debug` — builds clean against the real backend
  contract (`API_BASE_URL` pointed at the LAN-reachable Django instance).
- **Real-device check completed** (Samsung Galaxy S22+, after a full
  wireless-debugging re-pair — the connection had dropped from a screen
  lock/timeout, per
  `DevOps_and_Infrastructure/DevEnv-2026-11-02-adb-wireless-pairing-port-confusion.md`):
  dashboard renders live backend data correctly (Contacts/Products/Sales
  counts, Revenue/Paid/Outstanding credit/Margin, Stock health counts,
  "Needs restocking" list). Confirmed both deep links fire for real:
  tapping a low-stock row pushes to that exact product's detail screen,
  and tapping the Stock health card switches the bottom nav to the Stock
  tab.

## Follow-ups / Deferred
- Revenue trend chart and Tasks/Deals dashboard tiles — once those mobile
  modules exist or a chart is explicitly requested.

## References
- `CRM-2026-11-02-flutter-mobile-rebuild-phase3-pos-checkout.md`
- `CRM-2026-11-02-flutter-phase3-real-device-verification.md`
- `backend/apps/dashboard/{views,services}.py`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/dashboard/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session
