# HBEC Second Security Audit

**Date:** 2026-10-17
**Project:** HBEC
**Type:** Audit
**Status:** Completed

## Summary
A second source-focused security pass was performed after the initial Cloudflare security audit and explicitly excluded the four previously identified root causes. One additional high-severity, source-grounded candidate was found: an unauthenticated student synchronization endpoint capable of mutating account and institution sponsorship state. Runtime exposure remains unverified.

## Context / Trigger
The user asked whether HBEC had additional security issues after the first audit and its source remediations.

## Scope
Included student-backend internal APIs, account and institution boundaries, service authentication, tenant isolation, uploads, CI/CD, Docker/runtime configuration, mobile token storage, and LLM/tool boundaries. Excluded the already reviewed payment settings endpoint, catch-all media route, mutable active GitHub Actions references, and mutable production image defaults.

## Method
Used a fresh read-only security-review pass, then independently re-read the cited source locations. The Cloudflare security-audit evidence bar was applied: the candidate remains `needs_validation` because no approved isolated runtime sandbox was available.

## Decisions & Findings
- `SyncStudentView` at `/api/internal/sync-student/` uses `AllowAny`, omits `check_internal_auth`, and writes `User`, `StudentProfile`, and `InstitutionSponsorship` records from request-controlled values.
- The route is directly mounted under the student backend API.
- The candidate is high severity if reachable through the deployed edge, but is not classified as confirmed without local sandbox or deployment reachability evidence.
- Other reviewed areas produced hardening observations only: public artifact endpoints may need explicit classification, general service signatures lack nonce replay protection within their timestamp window, and mobile token storage did not reveal a new issue.

## Changes Made
- Created the issue record `Integrations_and_Auth/HBEC-2026-10-17-unauthenticated-student-sync.md`.
- No HBEC source files were modified.

## Verification
- Re-read `STUDENT/hbec_backend/apps/internal/views.py:291-347`.
- Re-read route registration in `STUDENT/hbec_backend/config/urls.py:21-22` and `apps/internal/urls.py:17-22`.
- Compared the view with the existing verifier at `apps/internal/views.py:103-137`.
- No live endpoint or target-controlled code was executed.

## Follow-ups / Deferred
- Validate the route with dummy data in the required isolated sandbox.
- Have the deployment owner confirm whether `/api/internal/sync-student/` is reachable from untrusted networks.
- Apply service authentication and add mutation-blocking regression tests.
- Review public artifact endpoints and replay handling as hardening follow-ups.

## References
- `STUDENT/hbec_backend/apps/internal/views.py`
- `STUDENT/hbec_backend/apps/internal/urls.py`
- `STUDENT/hbec_backend/config/urls.py`
- `HBEC-2026-10-17-unauthenticated-student-sync.md`

---

**Completed By:** Copilot
**Duration:** One audit session
