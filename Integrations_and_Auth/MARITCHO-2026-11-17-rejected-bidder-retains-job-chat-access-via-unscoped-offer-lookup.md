# Rejected/losing job bidder keeps permanent chat and job-detail access via unscoped offer lookup

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** High
**Status:** Resolved — fixed on `experimental` before merge (commit 5944c6d)

## Summary
`JobOfferRepository.get_for_job` (`backend/app/apps/jobs/infrastructure/repositories.py:427-429`)
returns every `job_offers` row ever created for a job, with no status/lifecycle filtering — because
the `JobOffer` domain entity and `JobOfferModel` table have no status concept at all (no
REJECTED/EXPIRED/WITHDRAWN). Three authorization call sites treat "a `job_offers` row exists for this
worker and job" as permanent proof of being an authorized party to the job: `_require_job_party`
(`backend/app/apps/messaging/domain/services.py:28-42`), `chat_socket`
(`backend/app/apps/messaging/interface_adapters/router.py:99-138`), and `GetJobUseCase.execute`
(`backend/app/apps/jobs/domain/services.py:107-131`). Once a worker submits an offer on a job, they
keep chat and job-read access to that job forever, even after the buyer books a different worker.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- Behaviorally: Worker A and Worker B both submit offers on a job. Buyer books Worker A
  (`BookJobUseCase.execute` sets `job.worker_id = worker_id` for Worker A only — it never deletes or
  updates Worker B's `job_offers` row). Worker B — who lost the job — can still indefinitely:
  send/read messages in the buyer/Worker-A chat (`SendMessageUseCase`, `ListMessagesUseCase`,
  `MarkMessagesReadUseCase` all route through `_require_job_party`), open the job's chat websocket
  (`chat_socket`), and call `GET /jobs/{id}` to see budget/problem_description/buyer linkage for a job
  they are no longer part of.

## Environment Details
- **Server/Host:** N/A (backend FastAPI service)
- **Services Affected:** Job chat (REST + websocket), job detail read endpoint
- **Related Components:** `JobOfferRepository`, `_require_job_party`, `chat_socket`, `GetJobUseCase`
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding claimed `get_for_job` has no status/expiry filter and that three call sites treat
"has an offer row" as permanent party proof. Read each implementation directly off the `pr-12` branch
(`git show pr-12:<path>`) rather than trusting the claim.

### 2. Root Cause Analysis
- `get_for_job`:
  ```python
  async def get_for_job(self, job_id: uuid.UUID) -> dict[uuid.UUID, JobOffer]:
      result = await self._db.execute(select(JobOfferModel).where(JobOfferModel.job_id == job_id))
      return {model.worker_id: _job_offer_to_entity(model) for model in result.scalars().all()}
  ```
  No `WHERE` clause beyond `job_id` — every offer row for the job is returned, keyed by `worker_id`.
- `JobOfferModel` (`backend/app/apps/jobs/infrastructure/models.py:143-169`) has only
  `id, job_id, worker_id, quoted_amount, availability_note, created_at, updated_at` — there is no
  status column in the schema at all, and `upsert()` only ever inserts or updates a row, never deletes
  one. So there is no "status" to filter even if the repository wanted to.
- `_require_job_party`:
  ```python
  is_party = user_id in (job.buyer_id, job.worker_id)
  if not is_party and offers is not None and user_role == RoleEnum.WORKER:
      job_offers = await offers.get_for_job(job_id)
      is_party = user_id in job_offers
  ```
- `chat_socket` (websocket) duplicates the identical pattern inline rather than calling
  `_require_job_party`.
- `GetJobUseCase.execute` duplicates the same pattern again, gating only the street
  address/landmark fields (per ADR-004) behind `is_direct_party`, but granting full read access
  (budget, problem_description, buyer linkage) to anyone with any offer row.
- `BookJobUseCase.execute` (`backend/app/apps/jobs/domain/services.py:434+`) sets
  `job.worker_id = worker_id` for the booked worker only; it never touches other workers'
  `job_offers` rows, confirming losing bidders' rows are permanent.

### 3. Key Findings
- Three independent call sites (messaging REST, messaging websocket, job-read) each reimplement the
  same flawed "any offer row = authorized party" check instead of sharing one authorization helper
  that at least takes assignment status into account.
- The underlying data model has no concept of offer status, so even a per-call-site fix is blocked
  until the schema itself can express "this offer lost."
- The websocket handler (`chat_socket`) duplicates the check inline rather than reusing
  `_require_job_party`, so a future fix to the REST path alone would still leave the websocket path
  vulnerable.

## Root Cause
`JobOffer`/`job_offers` was designed as a pure upsert record of "a worker's current price quote for a
job" with no lifecycle/status field, and three separate authorization checks downstream conflated
"has ever submitted an offer" with "is currently an authorized party to this job." Booking a different
worker changes `Job.worker_id` but does not revoke or mark the losing bidders' offer rows, so the
party checks continue to pass for them indefinitely.

## Prevention / Rule
**Guardrail:** Add an authorization regression test that: buyer posts a job, Worker A and Worker B
both submit offers, buyer books Worker A, then asserts Worker B gets 403/websocket-close on
`GET /jobs/{id}` (full fields), on sending/reading chat messages, and on opening the chat websocket.
Run it in CI on any PR touching `JobOfferRepository`, `_require_job_party`, `chat_socket`, or
`GetJobUseCase`.

This guardrail directly encodes the failure scenario in the Root Cause above (a stale offer row
outliving the booking decision) as an executable check, which a schema-level fix alone cannot
guarantee stays enforced at all three call sites once someone touches one of them independently.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed, currently-exploitable authorization gap found
during review of PR #12; it has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Add a status/lifecycle concept to `job_offers` (e.g. an enum column defaulted to `PENDING`, set to
  `LOST`/`SUPERSEDED` by `BookJobUseCase` for every other worker's offer on the same job at booking
  time), and change `get_for_job`'s authorization callers to only treat a `PENDING` (or, pre-booking,
  any) offer as proof of party-hood once the job has moved to `BOOKED` or later.
- Alternatively/additionally, once `job.status` is `BOOKED` or later, stop consulting offers entirely
  for party-hood and rely solely on `job.buyer_id`/`job.worker_id` — the offer-based check only needs
  to apply pre-booking (e.g. for pre-award chat/clarification), not after a worker has been chosen.
- Consolidate the three duplicated inline checks (`_require_job_party`, `chat_socket`,
  `GetJobUseCase.execute`) into one shared authorization helper so a future fix only has one call
  site to update.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — consider alerting on message/job-read access from a worker with a
      non-pending/non-assigned offer once status exists
- [ ] Documentation to update — none yet; depends on chosen schema fix
- [x] Code changes required — add offer status/lifecycle field and gate all three call sites on it,
      or restrict offer-based party-hood to pre-booking jobs only (not yet implemented)

## Related Issues
- Verified against a candidate finding surfaced while reviewing MARITCHO PR #12 (branch `pr-12`).
- Related in kind (authorization check treating stale/weak evidence as permanent proof of access) to
  `Integrations_and_Auth/MARITCHO-2026-11-16-media-download-idor.md`, though that one was a dropped
  check during a refactor rather than a data-model gap.

## References
- `backend/app/apps/jobs/infrastructure/repositories.py:427-429` (`get_for_job`)
- `backend/app/apps/jobs/infrastructure/models.py:143-169` (`JobOfferModel`)
- `backend/app/apps/messaging/domain/services.py:28-42` (`_require_job_party`)
- `backend/app/apps/messaging/interface_adapters/router.py:99-138` (`chat_socket`)
- `backend/app/apps/jobs/domain/services.py:107-131` (`GetJobUseCase.execute`)
- `backend/app/apps/jobs/domain/services.py:434+` (`BookJobUseCase.execute`)
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)
