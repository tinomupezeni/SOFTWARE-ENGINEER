# Self-witness guard on sprint commitments silently bypassed (UUID vs string)

**Date:** 2026-11-03
**Project:** ProjectFlow (projectflow_backend)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
The new `sprints` app's `tag_witnesses` action was supposed to reject a
commitment owner tagging themselves as their own witness, but the guard
compared a `UUID` object to a list of JSON-decoded strings, so the
comparison was always false and the block never fired.

## Symptoms
- `POST /api/sprints/sprint-commitments/<id>/tag_witnesses/` with
  `user_ids: [<owner's own id>]` returned `201` and created a
  `CommitmentWitness` row letting the commitment's owner witness their own
  entry — exactly the case the Sprint Ledger spec says must be blocked.
- No exception, no log line; the request just silently did the wrong thing.

## Environment Details
- **Server/Host:** Local dev (sqlite)
- **Services Affected:** `sprints` app, `SprintCommitmentViewSet.tag_witnesses`
- **Related Components:** `CommitmentWitness` model
- **Time First Observed:** During the initial smoke test of the new feature,
  before any commit — caught by a manual end-to-end API test exercising the
  self-witness case, not by an automated test (none existed yet for this new
  code).

## Investigation Steps

### 1. Initial Diagnosis
Ran a scripted request through `SprintCommitmentViewSet.as_view()` tagging
the owner as their own witness and expected a `400`; got a `201` with the
witness row created.

### 2. Root Cause Analysis
```python
user_ids = request.data.get("user_ids") or []
if commitment.user_id in user_ids:
    raise ValidationError(...)
```
`request.data` from a JSON body deserializes `user_ids` as a list of Python
`str`. `commitment.user_id` is a `uuid.UUID` instance. `UUID.__eq__` only
returns `True` against another `UUID` (or a value `UUID()` can coerce
losslessly) — comparing it to a plain string via `in` is always `False`,
even when the string is the UUID's own canonical text.

### 3. Key Findings
- Every other ownership check in the same file compares `.id` fields
  directly (model-to-model, both UUIDs), which is why this pattern hadn't
  caused problems elsewhere in the codebase yet — this was the first place
  a UUID pk was compared against ids taken straight from a request body.

## Root Cause
Comparing a `UUID` instance to raw JSON strings without normalizing both
sides to the same type, so the equality check always failed.

## Prevention / Rule
**Guardrail:** Whenever a check compares a model's UUID pk field against
caller-supplied ids from a request body, normalize both sides to the same
type first (`str(model.pk) in {str(v) for v in raw_ids}`), and cover the
"should be rejected" branch with an explicit test — not just the happy
path — any time a view takes a list of ids as input.

This closes the gap because the comparison can no longer silently
type-mismatch, and a dedicated negative-path test would have caught this
before merge even without noticing the type issue by inspection.

## Solution

### Immediate Fix
```python
user_ids = {str(uid) for uid in (request.data.get("user_ids") or [])}
if str(commitment.user_id) in user_ids:
    raise ValidationError("A commitment's owner cannot witness their own commitment.")
```
`sprints/views.py` — `SprintCommitmentViewSet.tag_witnesses`.

### Long-term Fix
None needed beyond the fix above; this was caught before the `sprints` app
was ever deployed.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (done)

## Related Issues
- Found alongside [[PROJECTFLOW-2026-11-03-sprint-stale-prefetch-cache]],
  same feature build, same smoke-test pass.

## References
- `sprints/views.py` (ProjectFlow backend repo)

---

**Resolved By:** tinomupezeni
**Time to Resolution:** < 15 minutes
