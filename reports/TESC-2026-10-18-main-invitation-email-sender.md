# Main Invitation Email Sender

**Date:** 2026-10-18
**Project:** TESC (ScalarEye)
**Type:** Configuration / Email UX / Integration
**Status:** Deployed to staging; SMTP verification pending

## Summary

Updated main-user invitations to use the requested ZCHPC no-reply identity and
to match the quality of the existing OTP email design. The staging runtime now
reports `noreply@zchpc.ac.zw` as its default sender, but a direct SMTP
authentication probe did not complete within the bounded verification window.

## Context / Trigger

A real invitation arrived from the old account identity and used a basic
credential presentation. The user requested `noreply@zchpc.ac.zw` and a better
designed message.

## Scope

Included sender configuration, invitation task content, staging backend/Celery
runtime, and local/staging regression validation. Excluded production,
password rotation, and sending another uncontrolled credential email.

## Method

Compared the OTP and invitation tasks, inspected effective staging settings,
updated the no-reply identity, redesigned both HTML and text content, recreated
services to load environment changes, and ran bounded readiness checks.

## Decisions & Findings

- Invitation task continues to use `settings.DEFAULT_FROM_EMAIL`, keeping
  sender selection configuration-driven.
- Staging was explicitly configured with `noreply@zchpc.ac.zw`.
- The message now provides a TESC-branded credential card, portal button, and
  first-login security warning.
- SMTP authentication did not complete within the timeout, so external
  delivery is not yet proven.

## Changes Made

- `backend/core/settings.py`
  - Changed the safe default sender to `noreply@zchpc.ac.zw`.
- `backend/users/tasks.py`
  - Redesigned `send_user_invitation_task`.
- Staging `.env`
  - Updated sender and authenticated mailbox identity.
- Backend and Celery services were recreated on staging.

## Verification

- Django system check passed.
- Main and institution invitation tests: 5 passed.
- Runtime `DEFAULT_FROM_EMAIL`: `noreply@zchpc.ac.zw`.
- Invitation task registered on the staging worker.
- Backend and worker containers healthy after recreation.
- SMTP authentication probe exceeded the bounded verification window and was
  stopped; relay verification remains incomplete.

## Follow-ups / Deferred

- Confirm mailbox credentials and relay permissions for the ZCHPC sender.
- Run a controlled real invitation delivery.
- Verify the received `From` header and branded HTML rendering.
- Rotate any SMTP credential exposed during earlier work.

## References

- `Integrations_and_Auth/TESC-2026-10-18-main-invitation-sender-and-template.md`
- `backend/users/tasks.py`
- `backend/core/settings.py`

---

**Completed By:** Copilot
**Duration:** One staging configuration and template session
