# TESC Admin Sidebar Navigation Redesign

**Date:** 2026-10-17
**Project:** TESC (ScalarEye)
**Type:** UI Refactor
**Status:** Completed and deployed to staging

## Summary

Redesigned the authenticated Django administration shell with a persistent
blue sidebar inspired by the Chemglee admin experience. The navigation now
groups the main operational areas, highlights the active page, provides a
clear sign-out action, and adapts for narrow screens without changing
authorization or data behavior.

## Context / Trigger

The existing authenticated admin surface exposed only a small set of top
links and did not provide a usable information architecture for the growing
operations dashboard. The requested direction was a Chemglee-inspired
left-panel navigation model while retaining TESC branding and Django Admin
security boundaries.

## Scope

Included the authenticated admin base template, navigation styling, active
route states, responsive layout behavior, and focused regression coverage.
The login page, public portals, Django authorization rules, and staging or
production deployment were intentionally excluded from this change.

## Method

Reviewed the existing TESC admin templates and CSS, inspected Chemglee's
sidebar and admin styling as prior art, then implemented the navigation in
the shared Django admin shell. Existing named admin URLs and Django's request
path were reused so navigation remains tied to registered admin views rather
than introducing a second routing or permission system.

## Decisions & Findings

- A persistent left sidebar is a better fit than adding more top-level links
  because it keeps operational areas visible while users work in changelists
  and the operations dashboard.
- Navigation is grouped into Workspace, People & access, and Monitoring to
  reduce scanning cost and make the dashboard's information architecture
  discoverable.
- Active states are derived from the current admin path and do not grant
  access; Django's existing staff and model permissions remain authoritative.
- The raw Django navigation sidebar is suppressed to avoid competing
  navigation surfaces.
- The login-specific shell remains unaffected and continues to render only
  the minimal blue login experience.

## Changes Made

- Updated `backend/templates/admin/base_site.html` with the sidebar, grouped
  links, active states, and sign-out link.
- Extended `backend/users/static/admin/tesc_admin.css` with the sidebar,
  content offset, active states, and responsive narrow-screen behavior.
- Added authenticated sidebar assertions to
  `backend/users/tests.py`.

## Verification

- `USE_SQLITE=True .venv/bin/python manage.py check`
- `USE_SQLITE=True .venv/bin/python manage.py test users.tests.AdminOperationsTests --verbosity 1`
- `git diff --check`

All eight focused admin tests passed and Django reported no system-check
issues. The runtime templates and CSS were copied to staging with matching
SHA-256 fingerprints, and the previous staging files were backed up before
replacement. Staging static collection, migration checks, authenticated
sidebar smoke, public route checks, static CSS delivery, dependency
readiness, zero-restart checks, and the deployment-window backend error scan
all passed.

## Follow-ups / Deferred

- Perform an authenticated browser/device visual check at desktop and mobile
  widths; the current verification used live HTTP checks and an authenticated
  Django request.
- Consider permission-aware hiding of individual sidebar links if the admin
  role model later includes restricted staff roles; link visibility must not
  replace server-side authorization.

## References

- `backend/templates/admin/base_site.html`
- `backend/users/static/admin/tesc_admin.css`
- `backend/users/tests.py`
- Chemglee prior art:
  `/home/shadowe/Projects/chemglee-concept-site/backend/templates/admin/base_site_old.html`

---

**Completed By:** Copilot
**Duration:** One implementation session
