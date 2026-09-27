# Budget documented as "enforced as an assertion" when it is only observed

**Date:** 2026-09-27
**Project:** ArchCode
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
`archcode/settings.py` carried the comment "Enforced as an assertion rather than a comment,
because a 92s regression is invisible until a learner sits through it." Nothing enforces it.
`ARCHCODE_ATTEMPT_BUDGET_MS` is reported at `/healthz`, carried on run and event payloads, and
compared by `Run.exceeds_budget` — but no code path fails when a run exceeds it, because nothing
executes yet. The same claim appeared in `README.md` and was fixed in `ac90a35`; the code comment
was missed and kept asserting something untrue.

## Symptoms
No runtime symptom. A reader — human or agent — trusting the comment would reasonably assume a
test or guard exists that fails on a regression, and would skip adding one. That is the actual
harm: the comment discourages the work that is still outstanding.

## Environment Details
- **Server/Host:** local dev
- **Services Affected:** none at runtime; documentation correctness
- **Related Components:** `runner/archcode/settings.py`, `runner/README.md`
- **Time First Observed:** 2026-09-27, while amending `settings.py`

## Investigation Steps

### 1. Initial Diagnosis
The comment was written next to the value when the budget was introduced, describing the *intent*
for a guard that had not been built.

### 2. Root Cause Analysis
Two distinct claims were fused into one sentence: the budget is *configured and surfaced* (true),
and it is *enforced* (false). The second describes the executor's job, which does not exist.

### 3. Key Findings
- `Run.exceeds_budget` is a genuine tri-state `bool | None`: `None` means "not yet measurable".
  That is the honest encoding of "nothing has run yet", and it contradicts the "enforced" claim.
- The number was also stale in the same comment: "~92s" where the measured cold path is ~101.3s.
- The README's "The budget is 2500 ms per attempt, and it is an assertion rather than a comment"
  was the same defect in a more prominent location, and was fixed first. The code comment was the
  copy that got missed — the point being that an aspirational comment is a bug whether or not the
  thing it describes is imminent.

## Root Cause
An intent comment was written as a description of existing behaviour, at a point where the
guardrail it referenced had not been implemented.

## Prevention / Rule
**Guardrail:** A comment must not describe behaviour that does not exist. When the budget becomes
a real assertion, the comment should say *what enforces it* — the test, the constraint, or the
executor path — not the virtue of having one.

## Solution

### Immediate Fix
```python
# This value is reported at /healthz, carried on run and event payloads, and compared by
# Run.exceeds_budget -- but nothing *fails* on it, because nothing executes yet. It becomes
# a real assertion when the executor lands.
```
The README was corrected in `ac90a35`.

### Long-term Fix
When the executor lands, the comment should name the enforcing code path.

## Prevention
- [x] Settings comment corrected
- [x] Cold-path figure corrected to ~101.3s
- [x] README corrected in `ac90a35`
- [ ] Re-check this comment when the executor lands and make it name the guard

## References
- `reports/ARCHCODE-2026-09-27-run-latency-budget.md` — the measurement behind the number
- `reports/ARCHCODE-2026-09-27-runner-api-first-green.md` — where `exceeds_budget` became tri-state

---

**Resolved By:** Claude (opencode)
**Time to Resolution:** ~5 minutes
