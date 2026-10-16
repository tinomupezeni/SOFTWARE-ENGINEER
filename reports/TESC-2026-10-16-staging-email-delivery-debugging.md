# TESC Staging Email Delivery Debugging and Repair

**Date:** 2026-10-16
**Project:** TESC / ScalarEye
**Type:** Production-like staging debugging and deployment
**Status:** Completed

## Summary
Deep tracing showed that the SMTP relay and app password were functioning. Application-triggered email failed because staging bypassed OTP when `DEBUG=True`, had no Celery worker in its Compose definition, and could not initialize its database due to an invalid migration dependency. The fixes were deployed locally to the staging Docker runtime, verified through the real login endpoint, and pushed to the `staging` branch.

## Context / Trigger
Direct email sent from the configured mailbox arrived successfully, while emails initiated by the application did not. The goal was to identify the exact failing layer and verify a real system-triggered message to `mupezeni2001@gmail.com`.

## Scope
Included SMTP configuration validation, Django authentication flow, Celery task execution, staging Compose services, database migration initialization, and a real OTP login test. External Gmail mailbox inspection and mail-server queue administration were outside the repository/runtime boundary.

## Method
1. Verified DNS, SMTP TLS, authentication, recipient acceptance, and relay queue acceptance.
2. Traced OTP and password-reset call sites through serializers, views, and Celery tasks.
3. Inspected staging Compose services and worker commands.
4. Built and started the corrected staging services.
5. Ran migrations and fixed the invalid migration graph.
6. Triggered the real login endpoint and verified Celery task completion.

## Decisions & Findings
- SMTP authentication with `mails.hpc.ac.zw:587` and the HPC app password succeeded.
- Staging `DEBUG=True` incorrectly acted as an OTP bypass.
- `docker-compose.staging.yml` had no Celery worker, so asynchronous email tasks could not be consumed.
- The staging database was uninitialized because migration loading failed on a missing `academic.0019_student_academic_st_status_f931b2_idx_and_more` dependency.
- Email task exceptions were swallowed after Sentry capture, reducing operational visibility.
- The real login endpoint subsequently returned `requires_otp`, and the Celery worker logged successful completion.

## Changes Made
- Added explicit `OTP_BYPASS`, defaulting to `False`.
- Removed `settings.DEBUG` from OTP bypass conditions.
- Added a dedicated staging Celery worker service.
- Replaced the staging backend idle command with Gunicorn.
- Added logging and exception propagation to email tasks.
- Removed the nonexistent migration dependency from academic migration `0020`.
- Added `OTP_BYPASS=False` to the environment template.
- Pushed commit `d97a459` to the TESC `staging` branch.

## Verification
- `python manage.py check`: passed.
- Staging images built successfully.
- Backend and Celery containers running.
- All Django migrations applied successfully after the migration fix.
- Real login request returned HTTP 200 with `requires_otp: true`.
- Celery received task `ef44ccbd-4c20-4f85-a897-321f6513007b`.
- Celery completed the OTP email task successfully in approximately 2.5 seconds.
- Temporary staging test user was deleted after verification.

## Follow-ups / Deferred
- Confirm final Gmail inbox placement for the latest system-triggered message.
- Add migration graph validation and a Celery smoke test to CI/deployment gates.
- Move SMTP credentials out of tracked `.env` files and rotate the exposed password.
- Add mail queue/delivery-log visibility for outbound Gmail troubleshooting.

## References
- `TESC-2026-10-16-staging-otp-email-bypassed.md`
- `TESC-2026-10-16-staging-celery-worker-missing.md`
- `TESC-2026-10-16-staging-migration-graph-invalid.md`
- TESC commit `d97a459`

---

**Completed By:** Copilot
**Duration:** One debugging and deployment session
