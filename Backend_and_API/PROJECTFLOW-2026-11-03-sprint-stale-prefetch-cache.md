# Sprint commitment actions returned stale witnesses/evidence from DRF's prefetch cache

**Date:** 2026-11-03
**Project:** ProjectFlow (projectflow_backend)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
Detail actions on the new `sprints` app's `SprintCommitmentViewSet`
(`tag_witnesses`, `decide_witness`, `add_evidence`) created or updated a
related `CommitmentWitness`/`CommitmentEvidence` row and then re-serialized
the same in-memory commitment instance to build the response — but that
instance's `witnesses`/`evidence` reverse relations had already been
prefetched (empty or stale) by `get_object()` before the write, so the API
response didn't reflect the change it had just made.

## Symptoms
- `POST .../tag_witnesses/` with one witness returned `201` with
  `"witnesses": []` in the body, even though the `CommitmentWitness` row was
  correctly created in the database (visible on the very next request).
- `POST .../witness/confirm/` returned `200` with the witness's `status`
  still `"pending"` in the response, even though the row was correctly
  updated to `"confirmed"` in the database.
- Both looked like the write itself had failed; it hadn't — only the
  response body was wrong.

## Environment Details
- **Server/Host:** Local dev (sqlite)
- **Services Affected:** `sprints` app, `SprintCommitmentViewSet` detail
  actions (`tag_witnesses`, `decide_witness`, `add_evidence`)
- **Related Components:** DRF `ModelViewSet.get_object()`,
  `prefetch_related("evidence", "witnesses")` in `get_queryset()`
- **Time First Observed:** Manual end-to-end smoke test of the new feature,
  before any commit.

## Investigation Steps

### 1. Initial Diagnosis
A full create → tag-witness → confirm → close flow run through the view
layer showed the confirm response reporting `"pending"` right after a
request that should have set it to `"confirmed"`.

### 2. Root Cause Analysis
Reproduced directly against the ORM, bypassing DRF entirely:
```python
qs = SprintCommitment.objects.select_related("task").prefetch_related("witnesses")
obj = qs.get(pk=c0.pk)          # mimics ModelViewSet.get_object()
list(obj.witnesses.all())        # empty — populates _prefetched_objects_cache now
CommitmentWitness.objects.create(commitment=obj, witness=some_user)
list(obj.witnesses.all())        # still empty — reads the stale cache, not the DB
```
Django's `prefetch_related()` only takes effect (and populates
`obj._prefetched_objects_cache`) the first time the related manager's bare
`.all()` is evaluated — which, for a queryset result returned via `.get()`,
happens during that same `.get()` call. Every view action then fetched the
commitment via `get_object()` (prefetch cache populated at that moment),
performed a write through a *separate* query (`.get()`/`.create()` on the
related manager, which doesn't touch the cached instance), and then called
`self.get_serializer(commitment)`, whose nested serializers read
`commitment.witnesses.all()` / `.evidence.all()` — hitting the now-stale
cache from before the write, not the database.

### 3. Key Findings
- `obj.witnesses.get(...)` and `.create(...)` always hit the database fresh
  (they build a new queryset), but they return different Python objects
  than whatever sits in `obj._prefetched_objects_cache` — mutating the
  fresh object doesn't update the cached list.
- `obj.refresh_from_db()` reliably clears `_prefetched_objects_cache`
  entirely, confirmed empirically before applying the fix.
- This pattern will recur in any DRF action that (a) fetches via
  `get_object()` off a `get_queryset()` with `prefetch_related` on the
  relation being mutated, and (b) serializes the same instance afterward.

## Root Cause
A `prefetch_related()` cache populated at `get_object()` time was read again,
unrefreshed, after the same request mutated the underlying relation —
Django does not auto-invalidate it just because new rows were written
through a different queryset.

## Prevention / Rule
**Guardrail:** In any DRF action that both fetches an object via a
`prefetch_related`-decorated `get_queryset()` and mutates one of those
prefetched relations before building the response, call
`instance.refresh_from_db()` immediately before serializing. Flag this at
code-review time whenever a detail `@action` both writes a related row and
reuses `self.get_serializer(same_instance)` for its response — the
same-instance reuse is the tell.

This closes the gap because `refresh_from_db()` is confirmed (not assumed)
to drop the entire `_prefetched_objects_cache`, so the next relation access
always re-queries the database.

## Solution

### Immediate Fix
Added `commitment.refresh_from_db()` right before building the response in
`add_evidence`, `tag_witnesses`, and `decide_witness` in `sprints/views.py`.

### Long-term Fix
None needed beyond the fix above; same smoke-test pass that found
[[PROJECTFLOW-2026-11-03-sprint-witness-uuid-string-bypass]] caught this
before the `sprints` app was ever deployed.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required (done)

## Related Issues
- Found alongside [[PROJECTFLOW-2026-11-03-sprint-witness-uuid-string-bypass]],
  same feature build, same smoke-test pass.

## References
- `sprints/views.py` (ProjectFlow backend repo)
- Django docs: `QuerySet.prefetch_related()` caching behavior

---

**Resolved By:** tinomupezeni
**Time to Resolution:** < 20 minutes
