# Admin dashboard Phase 2: live dashboard, Vite build, workplaces, devices, a11y, config

**Date:** 2026-10-04
**Project:** Attendance
**Type:** Feature implementation (plan: `Attendance/docs/admin-dashboard-plan.md` Phase 2)
**Status:** Completed

## Summary
Finished the dashboard polish phase: live KPIs/charts with honest unavailable states, Vite-built Tailwind replacing the CDN compiler, workplace boundary mini-map plus buffer editing, pairing-code expiry countdown, layout/a11y fixes, and centralized backend-URL config with the server-vs-browser split documented. Verified with `php -l`, `php artisan test`, `npm run build`, and seeded-PostGIS endpoint checks.

## Context / Trigger
Phase 1 left the overview dashboard on hardcoded numbers and several polish items open. User directed Phase 2 start.

## Scope
Included: `DashboardController` + live view, `config/admin.php` + controller migration, Vite build + `@vite` layout/login, workplace list enrichment + `PATCH` + edit view + index mini-map + search offline fallback, pairing countdown + copy, `role=alert`/`aria-label`/focus-visible/contrast fixes.
Excluded: workplace delete (FK-orphan risk against ledger events — deliberate), teleport/multiplexing detection (still needs coordinate/device persistence), consent-timestamp column, full compose staging smoke.

## Method
Backend contract first (workplace `GET` enrichment, `PATCH` with 400/404 guards), admin consumers second. Live verification against throwaway PostGIS (lesson from Phase 1: wait for final post-init startup, not the bootstrap instance). Two self-caught edit mistakes repaired before running anything (dropped PATCH decorator re-added; store() tail restored — both caught by re-reading the edited region per preservation discipline).

## Decisions & Findings
- No workplace delete: `attendance_events.workplace_id` FK has no `ON DELETE` rule; delete would 500 or orphan. Buffer/name/address edit covers the real ops need (drift retuning).
- Boundary stays immutable on PATCH; redraw = create-new. Preserves event meaning.
- Tailwind v4 theme tokens (`--color-shared-*`, `--radius-card`) reproduce the old inline CDN config exactly, including `/10` opacity modifiers.
- `npx/vite` build works with repo's Node 22; `public/build` output present on disk (Attendance has no git, so nothing to commit — flagging `git init` again as the remaining hygiene item).

## Changes Made
Backend: `GET /admin/workplaces` (+buffer/address/GeoJSON/centroid), `PATCH /admin/workplaces/{id}` (+`WorkplaceUpdate` schema).
Admin: `DashboardController`, `config/admin.php`, `WorkplaceController@edit/update`, routes, views (dashboard live, workplaces index/edit, pair countdown, login, layout `@vite` + footer + sign-out, employee consent/revoke from Phase 1 retained), `resources/css/app.css` theme + focus styles, `tests/Feature/ExampleTest` auth expectations.

## Verification
- `php -l` clean on 10 PHP files; `php artisan test`: 3 passed (8 assertions).
- `npm run build`: success (68.8 kB CSS, fonts).
- `phase2_workplace_check.py` vs throwaway PostGIS: list shape, PATCH apply, 400/404 guards, ledger/employees regression — all passed; container removed.

## Follow-ups / Deferred
- `git init` + first commit for Attendance (repeated — working tree keeps growing).
- Kinematic detection schema migration; consent timestamps; compose staging smoke before deploy.

## References
- Bug log resolved: dashboard-fabricated-metrics.
- Still open: pytest-redis-mock-seam (backend test infra, unrelated).
- Plan: `Attendance/docs/admin-dashboard-plan.md`.

---

**Completed By:** Phase 2 session
**Duration:** Same day
