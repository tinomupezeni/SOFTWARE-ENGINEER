# Internal harness→student endpoints are throttled like public anonymous traffic

**Date:** 2026-09-11
**Project:** HBEC
**Environment:** Staging (found while bulk-testing PR #42's content-ingestion fix)
**Severity:** Medium
**Status:** Investigating (root-caused, not yet fixed)

## Summary
Every internal, HMAC-authenticated endpoint under `STUDENT/hbec_backend/apps/internal/views.py`
(`SyncPaperView`, `StudentContextView`, `MarkingResultView`, `SBPTemplateView`,
`SBPProjectContextView`, `SBPStepFeedbackView`, `LeaderboardRosterView`,
`CurriculumContextView`, `MarkingSchemeLookupView`, `PaperForAdoptionView`) is
subject to DRF's default `AnonRateThrottle` at **30 requests/minute per source
IP** — the same limit a random unauthenticated public request gets. Since all
harness→student traffic originates from one container IP on the internal
docker network, that 30/minute budget is shared across every one of these
endpoints combined, not per-endpoint.

## Symptoms
- A bulk re-sync script (582 papers, re-syncing PR #42's content-ingestion
  fix through the pipeline) tripped a client-side circuit breaker
  (`app/shared/circuit_breaker.py`'s `student_api` breaker,
  `fail_threshold=3`) after only ~30 successful requests, then mostly
  failed for the rest of the run.
- The underlying HTTP error, once isolated from the circuit breaker's own
  cascading `CircuitOpenError` noise: `429 Too Many Requests` from
  `POST /api/internal/sync-paper/`.
- No error appears in the student backend's own logs for a 429 — DRF
  throttling returns the 429 before the view's `logger` calls run, so this
  is invisible from that side entirely.

## Environment Details
- **Files:** `STUDENT/hbec_backend/apps/internal/views.py` (`InternalAuthMixin`
  and every view built on it), `STUDENT/hbec_backend/config/settings/base.py`
  (`DEFAULT_THROTTLE_CLASSES`, `DEFAULT_THROTTLE_RATES`)
- **Related:** `AGENTIC_HARNESS/app/shared/internal_client.py`
  (`_student_api_breaker = CircuitBreaker("student_api", fail_threshold=3,
  reset_timeout=30)`) — a reasonable defensive circuit breaker, but its
  strict `half_open_max=2` trial-call limit means once tripped by a burst of
  429s, it can take several 30-second reset cycles to recover if any
  request in a half-open trial window also 429s, which is likely if the
  caller hasn't actually slowed down.

## Investigation Steps
1. Bulk-resync script processed papers as fast as the loop would go
   (~7 requests/second observed).
2. Circuit breaker opened after 3 consecutive failures; from that point,
   most of the run's "failures" were the breaker's own `CircuitOpenError`
   (rejecting calls locally, never reaching the network) rather than real
   HTTP errors — this was the first thing to rule out.
3. Filtered the real (non-`CircuitOpenError`) failures and found
   `HTTPStatusError: Client error '429 Too Many Requests'`.
4. Read `InternalAuthMixin.check_internal_auth()` — it verifies the HMAC
   signature and returns a 403 on failure, but does not touch
   `throttle_classes` or `permission_classes`. Every view built on it falls
   through to DRF's global defaults.
5. Confirmed in `config/settings/base.py`: `DEFAULT_THROTTLE_CLASSES` is
   `[AnonRateThrottle, UserRateThrottle]`, `anon: 30/minute`. Since
   `verify_internal_signature` is a custom HMAC check (not a DRF
   authentication backend), `request.user` is anonymous from DRF's
   perspective — so only the 30/minute anon rate applies, keyed by the
   calling IP.

## Root Cause
`InternalAuthMixin`-based views were never given their own throttle scope
or an exemption from the default anonymous rate limit. HMAC verification
proves the caller is the harness, but DRF's throttle machinery doesn't know
that — it only sees an unauthenticated request from one IP, so it applies
the same budget meant for public, potentially-abusive anonymous traffic.

## Solution
Not applied yet — needs a decision on the right shape (see Prevention).
Immediate workaround for the bulk-resync task: pace the script well under
30/minute and add retry-with-backoff on `CircuitOpenError`/429 rather than
treating either as a terminal failure.

## Prevention
- [ ] Code changes required — give `InternalAuthMixin` views their own
      throttle scope (e.g. a `DEFAULT_THROTTLE_RATES["internal"]` at a much
      higher rate, or exempt them from throttling entirely, since the HMAC
      check already gates access) rather than sharing the public anon
      budget. Needs a decision on which, not just a rate bump.
- [ ] Monitoring/alerts to add — a 429 on an internal endpoint during
      normal (non-bulk) operation would currently be silent to anyone
      watching only the student backend's own logs, since DRF's throttle
      response short-circuits before the view's logging runs.
- [ ] Documentation to update — n/a

## Related Issues
- Found while independently verifying PR #42 (content-ingestion pipeline
  fix, `logs/tino_look_at_this.md` et al.) at scale — not a defect in that
  PR; the sync logic itself is correct, this is purely a rate-limit
  interaction discovered by testing it against real bulk volume for the
  first time.

## References
- `STUDENT/hbec_backend/apps/internal/views.py` (`InternalAuthMixin`, `SyncPaperView`)
- `STUDENT/hbec_backend/config/settings/base.py` (`DEFAULT_THROTTLE_RATES`)
- `AGENTIC_HARNESS/app/shared/internal_client.py` (`_student_api_breaker`)
- `AGENTIC_HARNESS/app/shared/circuit_breaker.py`

---

**Resolved By:** Not resolved — logged, workaround pending
**Time to Resolution:** N/A
