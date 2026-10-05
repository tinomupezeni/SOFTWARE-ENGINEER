# Harness paper-generate/upload paths raised raw 500s on duplicate identity and invalid AI output

**Date:** 2026-10-05
**Project:** HBEC
**Environment:** Production (Agentic Harness admin paper pipeline)
**Severity:** Medium
**Status:** Resolved

## Summary
`POST /api/v1/admin/papers/generate` (and the sibling `/papers/manual` and
`/papers/upload` routes, which all ultimately call the same storage function)
had no handling for two real, actionable failure modes: a paper whose
identity `(subject, level, paper_number, year, session, variant)` already
exists, and the AI judge producing a paper that fails internal validation. An
uncaught `IntegrityError` on the DB's own unique constraint, or an uncaught
`ValueError` from paper generation, each surfaced to the admin as a bare 500
with no actionable message — observed live as an admin re-clicking "Generate"
three times in 14 minutes against the exact same identity, each attempt
failing opaquely.

## Symptoms
- `POST /api/v1/admin/papers/generate` → `500 IntegrityError ... duplicate
  key value violates unique constraint "uq_paper_identity"`, 3 occurrences for
  the identical identity `(History, O-Level, 2, 2026, AI, 1)` within 14
  minutes — consistent with a manual retry loop against an opaque error.
- `POST /api/v1/admin/papers/generate` → `500 ValueError: The AI produced an
  invalid paper — please try again`, same endpoint, a few minutes earlier.

## Environment Details
- **Server/Host:** `hbca-vps`, `/opt/hbec`
- **Services Affected:** `hbec-harness`
- **Related Components:** `app/admin/services/upload_pipeline.py::store_paper`,
  `app/admin/router.py`'s `generate_admin_paper`/`manual_entry`/`upload_paper`
- **Time First Observed:** 2026-09-29, found via `system_error_logs` triage 2026-10-05

## Investigation Steps

### 1. Initial Diagnosis
`system_error_logs` showed the exact SQL constraint name and conflicting
identity tuple, plus a separate `ValueError` a few minutes prior on the same
endpoint — both on `/papers/generate`.

### 2. Root Cause Analysis
`store_paper`'s `db.add(paper); await db.flush()` had zero exception handling
around it — any constraint violation propagated as a raw `IntegrityError` all
the way to FastAPI's default 500 handler. `generate_admin_paper` caught
`LLMUnavailableError` but not the `ValueError` `generate_paper()` can raise on
invalid AI output, so that also fell through to a raw 500. The codebase
already has the correct pattern for the identical constraint on the
*replication* path (`app/admin/replication_handlers.py`, which catches this
exact `IntegrityError` and returns a clean, actionable skip) — it just wasn't
applied to the synchronous admin-facing paths.

## Root Cause
Two unhandled exception classes on the synchronous admin paper-creation paths
(`/papers/generate`, `/papers/manual`, `/papers/upload`), with an existing,
correct handling pattern for one of them present elsewhere in the codebase
but never reused here.

## Prevention / Rule
**Guardrail:** `tests/admin/test_upload_pipeline.py`'s new
`test_duplicate_identity_raises_a_clean_error_not_a_raw_500` asserts
`store_paper` rolls back and raises the typed `PaperIdentityConflictError`
rather than letting `IntegrityError` propagate — any future caller that
reintroduces an unguarded flush on this constraint fails this test.

## Solution

### Immediate Fix
- `store_paper` now catches `IntegrityError` on the flush, rolls back, and
  raises a new `PaperIdentityConflictError` with the conflicting identity in
  the message (mirrors `replication_handlers.py`'s existing reasoning).
- `generate_admin_paper`, `manual_entry`, and `upload_paper` in
  `app/admin/router.py` each catch `PaperIdentityConflictError` → `409`.
- `generate_admin_paper` additionally catches `ValueError` from
  `generate_paper()` → `400`, surfacing the AI judge's own
  "please try again" message instead of an opaque 500.

### Long-term Fix
None needed — this was the complete fix.

## Prevention
- [x] Code change applied
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Test coverage added (`tests/admin/test_upload_pipeline.py`)

## Related Issues
- Found while triaging the backlog of `system_error_logs` entries surfaced by
  the new `hbec-errors-mcp` tool.

## References
- `app/admin/services/upload_pipeline.py` (`store_paper`, `PaperIdentityConflictError`)
- `app/admin/router.py` (`generate_admin_paper`, `manual_entry`, `upload_paper`)
- `app/admin/replication_handlers.py` (the pre-existing correct pattern this mirrors)

---

**Resolved By:** Tinotenda Mupezeni
**Time to Resolution:** Same session as discovery
