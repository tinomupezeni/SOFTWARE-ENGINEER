# Flutter Mobile — Phase 5: Dashboard Revenue Trend & Top Products Charts

**Date:** 2026-11-02
**Project:** CRM (Myra)
**Type:** New Feature
**Status:** Completed (tests + real backend + real-device verification)

## Summary
Closed the last gap identified for the Home dashboard in the original
feature-parity audit: the mobile dashboard showed only stat tiles, while
web additionally rendered a revenue trend chart and a top-products chart
from the same `/api/v1/dashboard/` payload. Added both, using data the
endpoint already returns (`revenue_trend`, `top_products`) — no backend
work needed, exactly as scoped when this was originally deferred in the
dashboard's first build.

## Context / Trigger
Follow-up item explicitly deferred in
`reports/CRM-2026-11-02-flutter-home-dashboard.md` ("Revenue trend chart
and Tasks/Deals dashboard tiles — once those mobile modules exist or a
chart is explicitly requested") and listed as Phase 5 in the Phase 4
feature-parity plan. Tasks/Deals tiles remain deferred (those mobile
modules still don't exist); this phase covered only the chart gap.

## Scope
Included: a revenue-over-time line chart and a top-products bar chart on
the Home dashboard, parsing the two array fields the dashboard endpoint
already returns. Excluded: Tasks/Deals tiles (unchanged scope reasoning —
no mobile Tasks/Deals modules exist yet to link them to), date-range
filtering on the charts (the endpoint's `start`/`end` params only affect
the `sales` sub-object per the original dashboard research, not
`revenue_trend`/`top_products`, so a filter control wouldn't do anything
meaningful yet).

## Method
Loaded the project's dataviz guide before writing any chart code (per its
own trigger rule — this is unconditionally a "making a chart" task) and
applied its procedure: picked the form first (a single time-series measure
→ line chart; a small ranked-magnitude set → bar chart), then color, then
marks, then the interaction layer — rather than default-styling an
off-the-shelf chart widget and calling it done.

## Decisions & Findings
- **Single hue throughout, both charts** — the brand Cobalt color, not a
  rainbow. Revenue-over-time has one series (nothing to distinguish by
  color); top-products is a ranked-magnitude bar chart, not a categorical-
  identity chart, so per the guide's "color follows the entity, never its
  rank" rule, assigning a different hue per bar would misleadingly imply
  the bars are different *kinds* of things rather than different products
  ranked by the same measure.
- **One axis, no exceptions** — neither chart pairs revenue with a second
  measure (e.g. profit) on a secondary y-axis; the guide calls dual-axis
  charts the single most common charting mistake. A profit trend, if ever
  wanted, is a separate chart.
- **Sparse, non-literal-daily labeling** — rather than a date label under
  every point (which collides badly at phone width for up to 30 points),
  at most ~5 evenly spaced labels are shown by index. Verified on-device:
  with real sparse sales data (not every day has a sale), this produced
  uneven-looking date gaps (e.g. `10/5, 10/7, 10/18, 10/29, 11/2`) — a
  correct reflection of the actual data's time gaps, not a labeling bug.
- **Long product names truncated with an ellipsis** on the bar chart's
  x-axis (`"Inuka Premium Cologne"` → `"Inuka Pre…"`), confirmed legible
  on-device at phone width; the touch tooltip (see below) shows the full
  name on tap.
- **Tooltip-on-touch shipped by default**, not treated as optional polish —
  the guide specifies this for any line/bar chart. `fl_chart`'s built-in
  touch-tooltip data covers both.
- **Added `fl_chart` as the only new dependency** — the Flutter ecosystem's
  standard charting package for this use case (lightweight, no codegen,
  active maintenance), consistent with this app's existing preference for
  zero-codegen dependencies.
- Both chart cards are **conditionally hidden** when there isn't enough
  data to plot (fewer than 2 revenue points, zero top products) rather than
  rendering an empty or degenerate chart.

## Changes Made
- `pubspec.yaml` — added `fl_chart: ^0.69.0`.
- `lib/features/dashboard/domain/entities/dashboard_entity.dart` — added
  `RevenuePointEntity` (date, revenue), `TopProductEntity` (name, revenue),
  and `revenueTrend`/`topProducts` fields on `DashboardEntity` (defaulted
  to `const []`, so this is additive and doesn't disturb any existing call
  site).
- `lib/features/dashboard/data/models/dashboard_model.dart` — parses
  `revenue_trend`/`top_products` from the existing endpoint response.
- `lib/features/dashboard/presentation/widgets/revenue_trend_chart.dart` —
  new: single-hue line chart with a filled area, recessive gridlines,
  sparse date labels, touch tooltip.
- `lib/features/dashboard/presentation/widgets/top_products_chart.dart` —
  new: single-hue bar chart, truncated labels, touch tooltip.
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` —
  added a shared `_ChartCard` wrapper and placed both charts between the
  Sales performance card and the Stock health card.
- New/updated tests: `dashboard_repository_impl_test.dart` (added a
  revenue_trend/top_products parsing case), `revenue_trend_chart_test.dart`,
  `top_products_chart_test.dart` (both new), `dashboard_screen_test.dart`
  (added chart data to the fixture, asserted both chart card titles render,
  widened the test viewport so the taller dashboard still fits the default
  test window — same fix pattern used for the Products/Sales form screen
  tests earlier in Phase 4).

## Verification
- `flutter analyze` — 0 errors/warnings (same pre-existing style notes).
- `flutter test` — 147/147 passing.
- `flutter build apk --debug` — builds clean.
- **Real device**: confirmed both charts render correctly against live
  backend data — the revenue trend line with its filled area and sparse,
  non-overlapping date labels tracking real (uneven) sales-day gaps, and
  the top-products bar chart showing four real products ranked by revenue
  with truncated labels, all in the single brand hue, sitting correctly
  between the Sales performance and Stock health cards without disturbing
  any of the dashboard's other already-verified content below.

## Follow-ups / Deferred
- Tasks/Deals dashboard tiles — once those mobile modules exist (Phase 6).
- Date-range filtering on the charts — only meaningful once/if the backend
  extends `start`/`end` to also scope `revenue_trend`/`top_products`.

## References
- `reports/CRM-2026-11-02-flutter-home-dashboard.md`
- `reports/CRM-2026-11-02-flutter-phase4-contacts-upgrade.md`
- `backend/apps/dashboard/{views,services}.py`
- `/home/shadowe/Projects/crm/mobile_flutter/lib/features/dashboard/`

---

**Completed By:** Tino (via Claude Code)
**Duration:** One session
