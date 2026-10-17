# TESC Admin Login Redesign and Staging Bootstrap

**Date:** 2026-10-17  
**Project:** TESC  
**Type:** UI / Operations  
**Status:** Completed

## Summary

Redesigned the TESC Django administration entry point and operations
dashboard into a branded white/blue interface, then deployed it to staging.
A staging-only bootstrap administrator was provisioned with staff and
superuser access, a hashed temporary password, and a forced first-login
password change.

## Context / Trigger

The original admin experience exposed a mostly default Django form labeled
only with `TESC administration` and did not present a clear operations
workspace. The requested improvement was a more usable TESC administration
login and dashboard for the user-testing period.

## Scope

Included the Django admin login template, admin branding/navigation, dashboard
layout, responsive styling, static assets, focused regression coverage, and
staging-only administrator provisioning. Production account creation and
production UI changes were explicitly excluded.

## Method

The existing Django authentication and staff authorization boundary was
preserved. The presentation layer was changed surgically, with no model or
migration changes. Local checks were run first, then the exact templates and
static files were transferred to staging, collected, and verified through an
authenticated Django test-client journey and public HTTP checks.

## Decisions & Findings

- Login now has TESC branding, a clear email field, password visibility
  toggle, remember-me control, validation messaging, and responsive layout.
- The password-recovery text directs users to the system administrator because
  no password-reset URL is currently configured in the project.
- Dashboard navigation now exposes Overview, Manage data, and Activity.
- Dashboard content is organized into account KPI cards, infrastructure,
  backups, dependency health, institution scope, and audit activity.
- The bootstrap account is staging-only, active, staff, superuser, and marked
  `must_change_password=True`.
- The supplied bootstrap password was not written to source or reports.

## Changes Made

- Updated `backend/templates/admin/base_site.html`.
- Added `backend/templates/admin/login.html`.
- Updated `backend/users/templates/admin/operations_dashboard.html`.
- Updated `backend/users/static/admin/tesc_admin.css`.
- Added a focused admin login regression test.
- Provisioned `admin@scalareye.com` on staging.
- Collected static assets and recreated staging backend/nginx services.

## Verification

- Local `manage.py check`: passed.
- Local `AdminOperationsTests`: 7 tests passed.
- Staging login markup contains the branded form, remember-me control, and
  password toggle.
- Staging CSS: HTTP 200 with `text/css`.
- Unauthenticated operations route: HTTP 302 to admin login.
- Staging account password verification: passed without exposing the password.
- Staging account flags: `is_staff=True`, `is_superuser=True`,
  `must_change_password=True`.
- Authenticated staging login: HTTP 302 to `/admin/operations/`.
- Authenticated dashboard: HTTP 200 with account metrics and audit section.
- Backend, nginx, database, and worker containers running with zero restarts.
- No production services or accounts were changed.

## Follow-ups / Deferred

- Implement a real password-reset flow if self-service recovery is required.
- Add browser-based visual verification for the responsive layout.
- Replace the bootstrap password after first login and remove or rotate any
  temporary access procedures.
- Resolve the pre-existing `iseop` model-drift warning separately.

## References

- `reports/TESC-2026-10-17-admin-dashboard-staging-deployment.md`
- `DevOps_and_Infrastructure/TESC-2026-10-17-admin-static-assets-not-served.md`
- `backend/templates/admin/login.html`
- `backend/users/templates/admin/operations_dashboard.html`

---

**Completed By:** Copilot  
**Duration:** One implementation and staging verification session
