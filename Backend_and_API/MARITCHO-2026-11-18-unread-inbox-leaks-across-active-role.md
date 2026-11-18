# Unread-Inbox Query Leaks Offer-Based Conversations Across Active Role

**Date:** 2026-11-18
**Project:** MARITCHO
**Environment:** Development (found in code review of PR #13, pre-merge)
**Severity:** High
**Status:** Investigating

## Summary
The new unread-inbox query's `is_party` check in `unread.py` grants offer-based access purely on `worker_id == user_id`, without the active-role condition (`user_role == RoleEnum.WORKER`) that the equivalent job-party checks and the websocket close-code check both require. This creates a data leak: a conversation is listed with real preview text and unread count even though the role-checked paths for the same job reject access.

## Symptoms
- Dual-role account submits a worker offer on a job, then switches active mode to BUYER.
- `GET /messages/unread` still lists that job's conversation with preview text and unread count.
- Opening the chat, marking it read, or connecting the websocket for the same `job_id` is rejected with 403.

## Environment Details
- **Server/Host:** N/A (application logic)
- **Services Affected:** Messaging inbox/unread count API
- **Related Components:** `backend/app/apps/messaging/infrastructure/unread.py:47`, `_require_job_party`, `_socket_close_code`
- **Time First Observed:** 2026-11-18, during code review of PR #13

## Investigation Steps

### 1. Initial Diagnosis
Code review compared the new unread query's party check against the pre-existing job-party and websocket access checks and found the active-role condition missing.

### 2. Root Cause Analysis
The unread query was written independently of `_require_job_party` and reused only the membership half of the condition (`worker_id == user_id`), dropping the active-role half (`user_role == RoleEnum.WORKER`) that the other two access paths enforce.

### 3. Key Findings
- Three code paths governing access to the same conversation (unread list, chat/mark-read, websocket) now disagree on the access rule.
- The leak exposes conversation existence, preview text, and unread count — not full message history — but is still a confidentiality gap tied to role, not identity.

## Root Cause
Inconsistent reimplementation of job-party access logic: the unread query checks only account membership in the job, while sibling checks also require the account's currently active role to match the party role.

## Prevention / Rule
**Guardrail:** Extract a single shared `is_job_party(user, job)` (or capability-based `Person.acts_as()`-driven) predicate function and require every access check touching job/conversation party membership — unread query, chat access, websocket — to call it, enforced via a lint/grep-based contract check or shared test fixture that asserts all three paths return the same boolean for the same inputs.

This closes the gap because the bug exists only because the three checks were implemented separately instead of from one shared predicate; a shared function makes future divergence impossible without being caught in review.

## Solution

### Immediate Fix
Not yet applied — PR #13 is under review, changes requested.

### Long-term Fix
Replace the ad hoc `is_party` check in `unread.py` with the same capability/role-aware predicate used by `_require_job_party` and `_socket_close_code` (see [[maritcho-2026-11-18-job-party-active-role-vs-capability]] for the related decision on which rule — active-role vs. capability-based — should be canonical).

## Prevention
- [ ] Code changes required (unify party-check logic)
- [ ] Monitoring/alerts to add (none currently detect cross-role data exposure)

## Related Issues
- [[maritcho-2026-11-18-job-party-active-role-vs-capability]]
- [[maritcho-2026-11-18-search-open-jobs-active-role-bug]]

## References
- PR #13 (Maritcho, `experimental` -> `main`)

---

**Resolved By:** Pending
**Time to Resolution:** N/A
