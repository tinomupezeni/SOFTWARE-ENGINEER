# TESC Minimal Blue Admin Login

**Date:** 2026-10-17  
**Project:** TESC  
**Type:** UI refinement  
**Status:** Completed

## Summary

Simplified the Django admin login page into a focused centered login card on
a blue background. The default Django administration header, breadcrumb,
navigation/sidebar, filter text, permission message, and footer were removed
from the login view while preserving the authentication form and protected
dashboard behavior.

## Context / Trigger

The initial admin redesign still exposed default Django chrome around the
login form, including the TESC administration header, Home breadcrumb, filter
text, and permission messaging. The requested experience was only the
central login area on a blue background.

## Scope

Included the admin login template, login-specific CSS, and focused login
regression assertions. Excluded the authenticated operations dashboard,
Django model permissions, login behavior, account provisioning, and
production.

## Method

The login template was given empty branding, global-navigation, breadcrumb,
user-tools, and sidebar blocks. Login-specific CSS hides remaining default
container elements and applies a full-height blue gradient behind the
centered card. The change was tested locally, transferred to staging,
collected as static assets, and verified through the public staging URL.

## Decisions & Findings

- The central form remains unchanged functionally.
- The visual shell is now login-specific and does not alter authenticated
  admin pages.
- The password visibility control, remember-me option, validation handling,
  and authentication boundary remain available.
- No database or account changes were required.

## Changes Made

- Updated `backend/templates/admin/login.html`.
- Updated `backend/users/static/admin/tesc_admin.css`.
- Updated the admin login regression test in `backend/users/tests.py`.
- Deployed the changes to staging and collected static files.

## Verification

- Local Django system check passed.
- Local `AdminOperationsTests`: 7 tests passed.
- Staging login page: HTTP 200.
- Staging CSS: HTTP 200 with `text/css`.
- Required email, password, remember-me, and password-toggle markup present.
- `TESC administration`, `Home`, filter text, permission message, and
  dashboard chrome absent from the login response.
- Unauthenticated operations dashboard still returns HTTP 302 to login.
- Nginx configuration check passed.
- Backend, nginx, database, and worker containers running with zero restarts.

## Follow-ups / Deferred

- Browser/device visual review can be performed during the user-testing
  exercise.
- The authenticated dashboard retains its branded navigation and operations
  layout; only the login page was intentionally minimized.

## References

- `reports/TESC-2026-10-17-admin-login-redesign-and-staging-bootstrap.md`
- `backend/templates/admin/login.html`
- `backend/users/static/admin/tesc_admin.css`

---

**Completed By:** Copilot  
**Duration:** One focused staging UI refinement
