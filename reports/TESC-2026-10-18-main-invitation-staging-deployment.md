# Main Invitation Staging Deployment

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Type:** Deployment / Integration Verification
**Status:** Staging deployment completed; controlled user journey pending

## Summary

Promoted the main TESC onboarding implementation to staging after confirming
the local regression suites and frontend build. The live staging backend now
generates random temporary credentials and queues post-commit invitations, and
the live frontend no longer displays static passwords.

## Context / Trigger

Staging was still running the older onboarding artifacts, causing duplicate
username errors and preventing meaningful testing of the new email invitation
flow.

## Scope

Included the main user serializer, invitation task, focused backend tests, and
main frontend settings bundle. Excluded unrelated dirty worktree changes,
institution frontend code, production, and database migrations.

## Method

Validated locally, backed up the four scoped staging files, transferred the
exact source changes, refreshed the active backend/worker containers, built the
matching main frontend image from the staging checkout with the transferred
source, and verified live runtime identity and smoke checks.

## Decisions & Findings

- Staging runs a bind-mounted/legacy container arrangement, so copying source
  into the active backend and worker containers was required in addition to
  updating the checkout.
- The main frontend was rebuilt as
  `tinotenda762/tesc-main:onboarding-4fdbcde`.
- No migrations were required; pending migrations: zero.
- Both active Celery workers registered
  `users.tasks.send_user_invitation_task`.

## Changes Made

- Deployed `settings_serializers.py`, `tasks.py`, and `tests.py` to the active
  backend/worker runtime.
- Built and activated the updated frontend image.
- Restarted only the backend, Celery workers, and main frontend container.
- Preserved a timestamped backup under `.deploy-backups/` on staging.

## Verification

- Local Django check passed.
- Local main/institution invitation suite: 5 tests passed.
- Local frontend production build passed.
- Staging backend invitation suite: 5 tests passed.
- Staging system check passed.
- Staging pending migrations: 0.
- Celery ping passed and invitation task registration was confirmed.
- Main public routes returned HTTP 200.
- Protected `/api/users/users/` returned HTTP 401 without credentials.
- Live bundle contains the new email-delivery confirmation and no
  `Default Password` or `tesc@123` onboarding strings.
- Backend and worker restart counts were zero after the final runtime check.

## Follow-ups / Deferred

- Create `massala.care@gmail.com` through the main staging UI.
- Verify actual SMTP handoff and first-login password change.
- Improve generic frontend 400 handling to display field-level validation.
- Promote to production only after the controlled staging journey passes.

## References

- `DevOps_and_Infrastructure/TESC-2026-10-18-staging-onboarding-artifact-drift.md`
- `backend/users/serializers/settings_serializers.py`
- `backend/users/tasks.py`

---

**Completed By:** Copilot
**Duration:** One deployment session
