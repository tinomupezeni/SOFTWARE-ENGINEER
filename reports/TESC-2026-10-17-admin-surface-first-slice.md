# TESC Admin Surface First Slice

**Date:** 2026-10-17  
**Project:** TESC  
**Type:** Architecture Decision / Feature Slice  
**Status:** Completed locally; staging validation deferred

## Summary

TESC's first admin release will use Django's existing `/admin/` surface,
expanded with safe registrations for user and access-control models and a
small operations dashboard. The initial release focuses on users, roles,
audit activity, presence estimation, and dependency health while disabling
hard deletion through the admin interface.

## Context / Trigger

The project needs an operational interface for a one-week user-testing
exercise. The existing Django admin route was enabled, but TESC model
registrations were placeholders and there was no consolidated view of users,
recent activity, or runtime dependency status. Chemglee's custom admin was
reviewed as prior art, but a new frontend was judged unnecessary for the
first time-boxed release.

## Scope

Included:

- Django admin registrations for `CustomUser`, `Role`, `Permission`,
  `Department`, `AuditTrail`, and `TrustedDevice`.
- User activation/deactivation actions with audit records.
- Read-only audit and trusted-device administration.
- Operations dashboard showing bounded user aggregates, institution counts,
  recent audit activity, a documented `last_activity` presence estimate, and
  database/cache health.
- Negative tests for non-staff dashboard access and sensitive-field
  non-exposure.

Excluded:

- Hard deletion of users, roles, permissions, departments, audit records, or
  trusted devices.
- Institution-scoped admin roles.
- Editing academic/student records.
- A separate React admin application.
- Production or staging deployment.

## Method

The work followed a bounded task contract and reviewed the existing TESC
authentication, role, audit, session-activity, and URL structures before
implementation. The security boundary was documented in the repository's
`.stride.md`, and focused Django tests were added for the protected dashboard,
soft deactivation, audit creation, and non-staff denial behavior.

## Decisions & Findings

- Django admin is the fastest safe foundation for the one-week exercise
  because it already has session authentication, CSRF protection, model
  permissions, and a routed entry point.
- The dashboard's presence metric is deliberately an estimate based on active
  users with `last_activity` in the previous 15 minutes. It is not presented
  as a definitive concurrent-session count because the application uses JWT
  authentication rather than a server-side session registry.
- Hard deletion is disabled in the first slice to preserve referential
  integrity and provide a reversible operational control.
- OTP values, encrypted person attributes, trusted-device tokens, and
  password values are not exposed in dashboard output or admin list pages.
- The local PostgreSQL test command is blocked by the absence of a local
  PostgreSQL listener; repository SQLite mode provides a passing focused
  regression run but is not equivalent to PostgreSQL integration proof.

## Changes Made

- `backend/users/admin.py`: registered access-control and audit models,
  added safe list/search/filter configuration, disabled deletion, and added
  audited activation actions.
- `backend/users/admin_views.py`: added the protected operations dashboard.
- `backend/users/templates/admin/operations_dashboard.html`: added the
  dashboard presentation.
- `backend/templates/admin/base_site.html`: added TESC branding and a
  dashboard link.
- `backend/core/urls.py`: routed `/admin/operations/`.
- `backend/core/settings.py`: enabled project-level admin template overrides.
- `backend/users/tests.py`: added three focused admin security and behavior
  tests.
- `.stride.md`: documented the admin trust boundaries and negative
  requirements.

## Verification

- `cd backend && .venv/bin/python manage.py check` passed.
- `cd backend && USE_SQLITE=True .venv/bin/python manage.py test users.tests.AdminOperationsTests --verbosity 1` passed: 4 tests.
- `git diff --check` passed.
- PostgreSQL-backed test execution was attempted and blocked by
  `connection refused` on `localhost:5432`; no shared or production database
  was used.

## Follow-ups / Deferred

- Run the same focused tests against disposable PostgreSQL and Redis-backed
  services.
- Deploy to staging only after the PostgreSQL proof is available.
- Perform a real staging browser journey: admin login, dashboard, user
  deactivation/reactivation, audit verification, and denied non-staff access.
- Decide whether institution administrators need a separate tenant-scoped
  admin surface.
- Add worker/task health only after a reliable Celery inspection contract is
  defined; the current dashboard intentionally reports database/cache health
  only.
- Revisit a custom React admin shell if the user-testing group needs richer
  navigation than Django admin provides.

## References

- `backend/users/models.py`
- `backend/users/utils.py`
- `backend/users/middleware.py`
- `backend/users/admin.py`
- `backend/users/admin_views.py`
- `.stride.md`
- Chemglee prior art: `/home/shadowe/Projects/chemglee-concept-site/admin`

---

**Completed By:** Copilot  
**Duration:** One implementation session
