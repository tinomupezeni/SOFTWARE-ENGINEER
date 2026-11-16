# Media download endpoint lost its ownership/role authorization check (IDOR)

**Date:** 2026-11-16
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #11, branch `fix/solid-trade-picker-sheet`)
**Severity:** Critical
**Status:** Investigating (not yet fixed — flagged in PR review, awaiting fix/merge decision)

## Summary
During a code review of MARITCHO PR #11 ("responsive web layout, BFF wiring, and pgvector semantic
search", WEB-012/CORE-008), `download_media` in `backend/app/apps/media/router.py` was found to have
silently dropped its ownership/OPS-role authorization check in this branch. The endpoint now lets any
authenticated user download any other user's media (job photos, voice notes) by UUID — a broken
access control / IDOR regression.

## Symptoms
- Not yet observed in production; found via static code review of the diff before merge.
- Behaviorally: any logged-in user (worker or buyer) who obtains or guesses a `media_id` (these are
  returned in job/offer/chat payloads, so they're easily discoverable) can `GET /media/{media_id}`
  and receive another user's private media file.

## Environment Details
- **Server/Host:** N/A (backend FastAPI service, `backend/app/apps/media/router.py`)
- **Services Affected:** Media download endpoint (`download_media`)
- **Related Components:** Job photo / voice-note media storage, authorization middleware
- **Time First Observed:** 2026-11-16, during code review of PR #11

## Investigation Steps

### 1. Initial Diagnosis
Ran the `code-review` skill (medium effort) against PR #11's full diff (3565 lines / 50 files). One
of 8 finder angles flagged `media/router.py:95` as a changed authorization check; verification pass
confirmed it against the pre-PR version of the file.

### 2. Root Cause Analysis
Compared `download_media` before and after the diff:
- **Before:** `if model is None or (model.owner_id != current_user.id and current_user.role.value != "OPS"):` → 403/404 for non-owners who aren't OPS staff.
- **After:** `current_user` is discarded (`_ = current_user`) and the check is reduced to `if model is None:` only — ownership and role are never checked again.

### 3. Key Findings
- The authorization branch was removed, not merely refactored elsewhere — no equivalent check exists
  anywhere else in the request path.
- `media_id` values are not secret — they're returned in normal job/offer/chat API responses, so this
  is trivially exploitable by any authenticated account, not just one with insider access.
- The route still requires authentication (a valid `current_user` is resolved), which likely masked
  the regression from a quick smoke test — only cross-account authorization is missing.

## Root Cause
A refactor in PR #11 (likely while wiring the BFF/profile/review changes) replaced the
ownership-or-OPS-role authorization check in `download_media` with a no-op (`current_user` discarded),
leaving only an existence check. This removed per-resource access control on a private-media
endpoint.

## Prevention / Rule
**Guardrail:** Add an authorization regression test for `download_media` (and any other
owner-or-role-gated media/resource endpoint) that asserts a non-owner, non-OPS user receives 403 when
requesting another user's resource by ID — run in CI on every PR touching `media/router.py` or similar
ownership-gated routers.

Unit/integration tests are the only mechanism that would have caught a silent authorization-check
deletion during a routine refactor; a manual review alone is reactive, not preventive, and this
exact class of regression (a check silently dropped during unrelated refactor) is cheap to catch
with a one-line negative-authorization test per protected endpoint.

## Solution

### Immediate Fix
Not yet applied — flagged during PR review before merge. Recommended fix: restore the ownership/role
check in `backend/app/apps/media/router.py` around line 95:
```python
if model is None or (model.owner_id != current_user.id and current_user.role.value != "OPS"):
    raise HTTPException(status_code=404, detail="Media not found")
```

### Long-term Fix
- Add the regression test described above.
- Audit other endpoints touched in the same PR for similarly dropped authorization checks, since this
  one was found by review rather than by a failing test.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — consider access-pattern alerting on media downloads across owners
- [ ] Documentation to update — none
- [x] Code changes required — restore the authorization check before merging PR #11

## Related Issues
- MARITCHO PR #11 (`fix/solid-trade-picker-sheet`, WEB-012/CORE-008) — code review also surfaced
  several non-security findings (inconsistent relevance scoring, duplicated taxonomy, missing
  search debounce) tracked in the PR review itself, not logged separately here as they are not bugs
  in the "something concrete that was broken" sense until confirmed/fixed.

## References
- PR: MARITCHO #11, branch `fix/solid-trade-picker-sheet`
- File: `backend/app/apps/media/router.py:95`

---

**Resolved By:** N/A (not yet resolved)
**Time to Resolution:** N/A
