# Inverted check constraint made every run un-creatable

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** Critical
**Status:** Resolved

## Summary
`attempts.models.Run` declared two `CheckConstraint`s meant to enforce "a graded run has a
verdict, and only a graded run has a verdict". One of them had its boolean sense flipped, and
the resulting predicate rejected the *default* state of every new run. Any `Run.objects.create`
raised `IntegrityError`, so `POST /runs` could not accept a single submission — the API's core
path was dead on arrival, with no error at import, check, or migrate time to warn about it.

## Symptoms
- `POST /runs` failed with a 500 on every request, including the simplest valid submission.
- Surfaces looked contradictory: the error named a *null verdict* as the failing condition on a
  run that was correctly `queued` with no verdict.
- `manage.py check` passed. `migrate` succeeded. The constraint was created without complaint —
  the schema was wrong, not the DDL.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/Club Zero/runner`
- **Services Affected:** FastAPI run submission, Django `attempts` app
- **Related Components:** `attempts/models.py`, `attempts/migrations/0001_initial.py`
- **Time First Observed:** 2026-09-27, during the first API test run

## Investigation Steps

### 1. Initial Diagnosis
The test suite was red with `IntegrityError` and an `assert 404 == 202` on submissions. Because
several unrelated things were also broken at the time, the constraint violation was initially
read as fallout from the settings bug rather than as its own defect.

### 2. Root Cause Analysis
Dumped the offending row from the error detail and compared it against the intended predicate:

```
DETAIL:  Failing row contains (3c408282-…, , queued, null, 1, …)
                                        ^^^^^^ status=queued
                                             ^^^^ verdict=NULL
```

A `queued` run with a `null` verdict is the *correct* initial state. So the constraint was
rejecting correct data, which meant the predicate itself was wrong. Reading it back:

```python
# before
models.CheckConstraint(
    condition=~models.Q(verdict__isnull=True) | models.Q(status=RunStatus.GRADED),
    name="verdict_only_when_graded",
)
```

### 3. Key Findings
- `~Q(verdict__isnull=True)` evaluates to "a verdict exists", not "no verdict exists". The `~`
  was applied to the *negated* form, inverting the whole clause.
- So the constraint read "a verdict exists OR status is graded" — which bans every ungraded
  run, the exact opposite of its name.
- Both directions of the rule are needed and are separate constraints:
  `graded_run_has_verdict` covers graded⇒verdict, `verdict_only_when_graded` covers
  verdict⇒graded. One was right, one was inverted.
- A `CheckConstraint` is not validated by `manage.py check`; it is only exercised when a row
  that violates it is written. Nothing in the pre-migration checks would ever have caught this.

## Root Cause
A double negative in a Django `Q` object. `verdict__isnull=True` already means "has no verdict",
so negating it yields "has a verdict". Written as `~Q(verdict__isnull=True) | Q(status=GRADED)`,
the constraint asserts that either a verdict exists or the run is graded — permitting a verdict
on a queued run and forbidding a queued run with no verdict. The bug is invisible in review
because the clause *looks* like a negation of "not null" and the intent reads naturally at a
glance.

## Prevention / Rule
**Guardrail:** Write "must not" constraints in the `~Q(field)` form rather than
`~Q(field__isnull=True)`, and pair every `CheckConstraint` in a Django model with a test that
asserts the *valid* rows it is meant to permit are accepted — not only that the invalid row is
rejected.

The failure mode here was asymmetric coverage: the test suite only asserted the negative
("a graded run with no verdict is rejected"), so a constraint that rejected valid rows
satisfed it. A permitted-row assertion is what turns a constraint into a two-sided contract.

## Solution

### Immediate Fix
Corrected the polarity and regenerated the initial migration, since nothing had shipped:

```python
models.CheckConstraint(
    condition=models.Q(verdict__isnull=True) | models.Q(status=RunStatus.GRADED),
    name="verdict_only_when_graded",
)
```

```bash
rm -f attempts/migrations/0001_initial.py content/migrations/0001_initial.py
./.venv/bin/python manage.py makemigrations content attempts
./.venv/bin/python manage.py migrate
```

### Long-term Fix
Kept the negative-case test, tightened it to name the constraint so it cannot pass for the
wrong reason, and made it assert the constraint's *name*:

```python
with pytest.raises(IntegrityError) as excinfo:
    with transaction.atomic():
        Run.objects.filter(pk=run.pk).update(status=RunStatus.GRADED, verdict=None)
assert "graded_run_has_verdict" in str(excinfo.value)
```

`test_submit_run_accepts_and_stays_ungraded` now covers the permitted side, because creating an
ordinary `queued` run is exactly the case this constraint used to block.

## Prevention
- [x] Constraint polarity corrected and initial migration regenerated
- [x] Negative-case test asserts the specific constraint name
- [x] Positive case covered by every ordinary run-creation test
- [ ] Add a permitted-row assertion for each remaining `CheckConstraint` (`tier_b_never_graded`,
      `sandbox_file_not_editable`) — same asymmetric-coverage gap, not yet closed
- [ ] Consider a CI step that creates one representative row per model, so a constraint that
      rejects the default state fails before it reaches a test

## Related Issues
- `Backend_and_API/ARCHCODE-2026-09-27-django-lazysettings-drops-lowercase-names.md` — the other
  defect red in the same run; the `IntegrityError` was initially misattributed to it
- `reports/ARCHCODE-2026-09-27-runner-api-first-green.md`

## References
- Django `CheckConstraint` semantics: `Q(verdict__isnull=True)` is already "no verdict";
  `~` on top of it inverts the clause
- PostgreSQL `CHECK` constraints are only evaluated on write — never at `CREATE TABLE` time

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~20 minutes
