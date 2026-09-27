# `POST /runs` returned 202 "accepted and durable" while discarding the submitted code

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
Run submission validated each file path against the problem's editable set, then threw the file
contents away. Nothing was written anywhere: no `RunFile` table existed, and the `Run` row carried
no submission payload. The endpoint still answered `202 Accepted` with a docstring stating "A 202
means 'accepted and durable'". So the API promised durability it did not deliver — the run row
survived, the code that was supposed to run did not. The response was indistinguishable from
success, and the contract that a future executor depends on was already broken before any executor
existed.

## Symptoms
- `POST /runs` with `files={"solution.py": "..."}` returned 202; the content was unrecoverable
- No error, no warning, nothing in the timeline recording what was submitted
- The queued event listed scenario, seed and budget — but not the files it claimed to accept
- The loss was invisible because there is no executor yet to complain about missing input

## Environment Details
- **Server/Host:** local dev, `runner/`
- **Services Affected:** run submission, future executor and verifier
- **Related Components:** `api/routes/runs.py`, `attempts/models.py`, `api/schemas.py`
- **Time First Observed:** 2026-09-27, code review while fixing the test suite

## Investigation Steps

### 1. Initial Diagnosis
Reading `_create_run` end to end: the `files` argument was used for the editable-path check and
then never referenced again. The `RunEvent` payload listed `scenario`, `problem`, `workers`,
`connections`, `seed`, `budget_ms` and `executor` — and no files.

### 2. Root Cause Analysis
```python
for path in files:
    if path not in editable:
        rejected.append(path)
# ... files is never read again
```

The endpoint was written as a validator with a storage-shaped response. The 202 and the
"accepted and durable" docstring were written for the finished feature, while the implementation
was still the validation half.

### 3. Key Findings
- Validation passing is not durability. The test only asserted `status_code == 202`, which the
  endpoint returned whether or not anything was stored — so the existing test was incapable of
  catching this.
- A run has to be reproducible from its own rows. Problems are editable content, so a pointer to
  the live `ProblemFile` would mean a re-verified or disputed run saw *today's* `solution.py`
  rather than the bytes that were graded. Storage has to be a copy, not a reference.
- The queued event is streamed to the browser as the run's self-describing history. Leaving the
  submitted files out made the timeline unable to say what was run.
- The learning content is a `Problem` whose `solution.py` is authored by staff; a learner's
  submission replaces it for that run only, so the copy must be per-run and immutable.

## Root Cause
A durability gap between the documented contract and the implemented subset. The endpoint's
response semantics ("accepted and durable") were chosen for the end state, but the persistence
half was never written, and the only test asserted the status code — which a pure validator
satisfies perfectly.

## Prevention / Rule
**Guardrail:** An endpoint whose response promises durability must have a test that reads the data
back out of storage and compares it to what was sent, byte for byte including a hash. Asserting
only the status code tests the validator, not the promise.

For learner submissions specifically: store the submitted bytes on the `Run`, never a foreign key
to editable content, so run history is immutable by construction rather than by convention.

## Solution

### Immediate Fix
Added a `RunFile` model holding the frozen submission:

```python
class RunFile(models.Model):
    """The learner's submitted code, frozen as it was at submission time.

    Stored as bytes rather than as a reference to the editable `ProblemFile` because a run has
    to stay reproducible from its own rows: the problem can be edited afterwards, and a
    re-verified or disputed run must see the code that was actually graded.
    """
    run = models.ForeignKey(Run, on_delete=models.CASCADE, related_name="files")
    path = models.CharField(max_length=255)
    content = models.TextField(blank=True)
    sha256 = models.CharField(max_length=64)
```

Rows are written in the same `transaction.atomic()` block as the `Run`, so a 202 now corresponds
to a real commit, and the queued event records `path` + `sha256` per file.

### Long-term Fix
Two tests, both of which fail against the old code:

- `test_submitted_code_is_actually_stored` — round-trips content and hash, asserts the timeline
  event lists the file
- `test_submission_survives_the_problem_being_edited_afterwards` — edits the `ProblemFile` after
  submission and asserts the stored snapshot is unchanged, which is what makes the design
  decision about copying rather than referencing enforceable

### Migration
```bash
./.venv/bin/python manage.py makemigrations attempts   # 0002_runfile
./.venv/bin/python manage.py migrate
```

## Prevention
- [x] `RunFile` table; submission persisted in the run's own transaction
- [x] `sha256` recorded so verifier and archive can be compared
- [x] Submitted files listed in the queued event
- [x] Read-back test asserting content and hash
- [x] Immutability test asserting independence from later problem edits
- [ ] `Attempt` should record which `RunFile` snapshot it executed once repetitions land
- [ ] Consider a size cap on submission content; `TextField` is currently unbounded

## Related Issues
- `Backend_and_API/ARCHCODE-2026-09-27-exceeds-budget-false-instead-of-null.md` — the same
  accept-and-claim-nothing pattern on the response side
- `reports/ARCHCODE-2026-09-27-runner-api-first-green.md`

## References
- `api/routes/runs.py` `_create_run` — the `files` argument was read once for validation only

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~20 minutes
