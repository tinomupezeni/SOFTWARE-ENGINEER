# `over_budget` reported False for runs that had not finished, fabricating a result

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
`Run.exceeds_budget` collapsed "not measurable yet" into `False`. Because `duration_ms` is null
until a run completes, a queued run was reported as `over_budget: false` — which reads to any
client as "this run was within the latency budget". A run that has not executed had not *met*
the budget either, and the API asserted it had. This is precisely the fabricated-result failure
mode the runner was built to prevent, and it sat in the response model as a first-class field
rather than as an error.

## Symptoms
- `GET /runs/{id}` returned `"over_budget": false` for a `queued` run
- `POST /runs` → `GET /runs/{id}` round trip reported a timing verdict on work that had not run
- The `RunDetail` schema declared `bool | None`, so the API's own contract already said the
  distinction mattered — the model just never produced it

## Environment Details
- **Server/Host:** local dev, `runner/`
- **Services Affected:** run detail API, WebSocket `hello` and `closed` frames, Django admin
- **Related Components:** `attempts/models.py`, `api/schemas.py`, `api/routes/runs.py`,
  `api/routes/ws.py`, `content/admin.py`
- **Time First Observed:** 2026-09-27, `test_submit_run_accepts_and_stays_ungraded`

## Investigation Steps

### 1. Initial Diagnosis
```
>       assert detail["over_budget"] is None
E       assert False is None
```

### 2. Root Cause Analysis
```python
def exceeds_budget(self, budget_ms: int) -> bool:
    """Whether this run blew the latency budget. Only meaningful once completed."""
    return self.duration_ms is not None and self.duration_ms > budget_ms
```

The docstring said "only meaningful once completed" — the guard was right — but the return type
was `bool`, so "not measurable" was forced to encode as `False`. There is no third value
available in `bool`.

### 3. Key Findings
- `and` short-circuits: when `duration_ms is None` the expression yields `False`, the same value
  a genuinely fast run produces. The two cases are indistinguishable downstream.
- The Pydantic schema was already `bool | None` for `over_budget`, so the contract was written
  correctly and the model violated it. The mismatch was only visible at runtime.
- The same method fed three surfaces — REST detail, both WebSocket frames, and the Django admin
  — so one wrong return value propagated to all of them. The admin's `if obj.exceeds_budget(...)`
  happened to be safe only because `False` and `None` are both falsy; that was luck, not design.
- Latency is a headline feature of this product (~2.5s warm vs ~92s fresh, per
  `reports/ARCHCODE-2026-09-27-run-latency-budget.md`). A field that pre-judges it is not a
  cosmetic issue.

## Root Cause
A two-valued return type for a three-state question. The method knew the third state existed
(and documented it) but had nowhere to put it, so `False` absorbed both "within budget" and
"unknown" — and the API serialised the ambiguity as a confident claim.

## Prevention / Rule
**Guardrail:** When a field is nullable in the API schema because "unknown" is a real state, the
model that produces it must return a tri-state (`bool | None`) and must be covered by a test
asserting `is None` for the not-yet-measured case.

Concretely: forbid `bool` returns from any method whose result is exposed as a nullable schema
field, and make "unknown" explicitly unrepresentable as a measurement. A lint rule comparing
`-> bool` on model methods against the `| None` fields that consume them closes the general
version of this gap.

## Solution

### Immediate Fix
```python
def exceeds_budget(self, budget_ms: int) -> bool | None:
    """Whether this run blew the latency budget, or None while that is still unknown.

    The tri-state is deliberate. A run that has not finished has not "met" the budget
    either, and reporting False would tell the UI a queued run was fast -- which is the
    kind of fabricated result the runner exists to avoid. None means "not measurable yet".
    """
    if self.duration_ms is None:
        return None
    return self.duration_ms > budget_ms
```

`if … is None: return None` rather than the short-circuiting `and`, so "unknown" is visibly
distinct in the source instead of hidden in a boolean fold.

### Long-term Fix
`test_submit_run_accepts_and_stays_ungraded` asserts `detail["over_budget"] is None` for an
unstarted run, so the third state is now pinned by a test.

## Prevention
- [x] `exceeds_budget` returns `bool | None`
- [x] Test asserts `over_budget is None` before completion
- [ ] Add coverage asserting `over_budget is True` for a completed over-budget run — the third
      branch of the tri-state is currently unasserted
- [ ] Audit other model→schema nullable fields for the same two-valued collapse

## Related Issues
- `Frontend_and_UI/ARCHCODE-2026-09-26-fabricated-verdicts-and-editable-overclaim.md` — the same
  fabrication class, previously caught in the frontend; this one was server-side
- `Backend_and_API/ARCHCODE-2026-09-27-websocket-replay-cursor-derived-from-max-seq.md`
- `reports/ARCHCODE-2026-09-27-runner-api-first-green.md`

## References
- `api/schemas.py`: `over_budget: bool | None` — the contract was right; the model was not

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~10 minutes
