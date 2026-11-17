# GPS coordinates leak to a worker who only offered, not booked, on a job

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** High
**Status:** Resolved — fixed on `experimental` before merge (commit 5944c6d)

## Summary
`GetJobUseCase.execute` (`backend/app/apps/jobs/domain/services.py:107-131`) lets a worker who has
merely submitted an offer (not yet booked) read a job's details, redacting only `job.address` and
`job.landmark_narrative` with a comment citing "ADR-004: Keep street address hidden until the worker
is booked." The `Job` entity also carries `latitude`/`longitude` fields, which this redaction never
touches, and `JobOut` (`backend/app/apps/jobs/interface_adapters/schemas.py`) serializes them
unconditionally — so `GET /jobs/{job_id}` returns the exact GPS coordinates of a job to any worker who
has submitted a cheap/free offer on it, before being hired.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- Any worker can submit an offer on a job purely to pull its exact latitude/longitude before being
  hired, defeating the ADR-004 privacy intent the redaction code itself references.

## Environment Details
- **Server/Host:** N/A (backend FastAPI service)
- **Services Affected:** Job detail read endpoint (`GET /jobs/{job_id}`)
- **Related Components:** `GetJobUseCase`, `Job` entity, `JobOut` schema
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding claimed the address redaction in `GetJobUseCase.execute` was incomplete because
it doesn't also clear `latitude`/`longitude`. Read the entity, use case, and schema directly off the
`pr-12` branch to confirm.

### 2. Root Cause Analysis
- `Job` entity (`backend/app/apps/jobs/domain/entities.py`) has `latitude: Decimal | None` and
  `longitude: Decimal | None`, fully separate fields from `address`/`landmark_narrative`.
- `GetJobUseCase.execute`, line 129: `job.address = ""` followed by `job.landmark_narrative = None`.
  `job.latitude`/`job.longitude` are never assigned — they pass through unmodified on the same `Job`
  object returned to the router.
- `JobOut` declares `latitude`/`longitude` unconditionally, with no redaction-aware logic — it's a
  straight `from_attributes` serialization of whatever is on the `Job` entity.
- `OpenJobCandidate`/`OpenJobOut` (the reverse worker-browsing view, elsewhere in the same codebase)
  explicitly documents excluding "address/landmark_narrative/latitude/longitude/buyer_id" as a
  deliberate privacy boundary — confirming the team's own intent was to withhold coordinates from
  non-booked workers, which makes this a genuine regression/gap in `GetJobUseCase`, not a judgment
  call.

### 3. Key Findings
- The redaction in `GetJobUseCase.execute` was written by analogy to the address field alone, missing
  that location is represented twice (free-text address/landmark and numeric lat/long) in this
  domain, and only one representation was redacted.
- The new test added alongside this behavior (`backend/tests/test_messaging.py::test_offering_worker_can_message_buyer_before_booking`)
  only asserts `job_view.json()["address"] == ""` — it never asserts on `latitude`/`longitude`, so the
  leak passes CI as-is.

## Root Cause
`GetJobUseCase.execute`'s ADR-004 redaction enumerates specific fields to blank (`address`,
`landmark_narrative`) instead of redacting by category ("anything that discloses precise location"),
so when the job gained a second, independent location representation (`latitude`/`longitude`), the
redaction logic was not updated to cover it.

## Prevention / Rule
**Guardrail:** Add a test asserting that `GET /jobs/{id}` for a non-booked-but-offering worker returns
`latitude: null` and `longitude: null` alongside `address: ""` and `landmark_narrative: null` —
i.e. assert on the full set of location-disclosing fields together, not just address, so a future
reviewer/CI run cannot miss one half of the redaction again.

This closes the gap because the Root Cause was an incomplete enumeration of location fields; a single
test that lists every location field together makes the enumeration explicit and verifiable instead
of implicit and easy to under-cover.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed, currently-exploitable privacy gap found during
review of PR #12; it has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Add `job.latitude = None` and `job.longitude = None` to the same redaction block in
  `GetJobUseCase.execute` that already clears `address`/`landmark_narrative`.
- Consider a single `job.redact_location()` method on the `Job` entity that clears every
  location-disclosing field at once, so future location fields are redacted by construction rather
  than requiring every call site to remember to add them.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — none
- [ ] Documentation to update — none
- [x] Code changes required — clear `latitude`/`longitude` in `GetJobUseCase.execute`'s redaction
      block (not yet implemented)

## Related Issues
- Verified against a candidate finding surfaced while reviewing MARITCHO PR #12 (branch `pr-12`).
- Same PR also introduced `Integrations_and_Auth/MARITCHO-2026-11-17-rejected-bidder-retains-job-chat-access-via-unscoped-offer-lookup.md`,
  which governs who is allowed to reach `GetJobUseCase.execute` in the first place; this entry is
  about what that use case discloses once reached.

## References
- `backend/app/apps/jobs/domain/services.py:107-131` (`GetJobUseCase.execute`)
- `backend/app/apps/jobs/domain/entities.py` (`Job.latitude`/`Job.longitude`)
- `backend/app/apps/jobs/interface_adapters/schemas.py` (`JobOut`)
- `backend/tests/test_messaging.py::test_offering_worker_can_message_buyer_before_booking`
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)
