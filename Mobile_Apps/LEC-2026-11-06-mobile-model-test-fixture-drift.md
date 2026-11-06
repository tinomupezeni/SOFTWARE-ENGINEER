# Mobile model test fixture omitted required classroom id

**Date:** 2026-11-06
**Project:** LEC Virtual Labs
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The mobile model regression fixture for an assignment did not include the
contract-required `classroom` field. Extending the assignment model caused the
existing test to fail before the fixture was brought back in line with the
REST contract.

## Symptoms
- `flutter test` failed while parsing the existing assignment fixture.
- Error: `type 'Null' is not a subtype of type 'int' in type cast`.

## Environment Details
- **Server/Host:** Local Flutter test runner
- **Services Affected:** Mobile model contract tests
- **Related Components:** `mobile_flutter/lib/core/labs/models.dart`,
  `mobile_flutter/test/home_models_test.dart`
- **Time First Observed:** 2026-11-06

## Investigation Steps

### 1. Initial Diagnosis
Ran the mobile regression suite after adding assignment/classroom lifecycle
fields.

### 2. Root Cause Analysis
The authoritative API contract defines `Assignment.classroom` as an integer,
but the pre-existing test fixture represented an older partial response and
omitted it.

```bash
cd mobile_flutter && flutter test
```

### 3. Key Findings
- The failure occurred in local fixture parsing, not in a backend request.
- The new field is required by `contracts/api.md`.
- The fixture was updated and a broader lifecycle fixture was added.

## Root Cause
The model test fixture had drifted from the current REST contract and was not
updated when the mobile model began consuming the classroom relationship.

## Prevention / Rule
**Guardrail:** Keep one representative JSON fixture for every changed API
resource in the mobile contract test suite, including all non-null contract
fields.

This makes model changes fail at the fixture boundary and keeps tests aligned
with the authoritative contract instead of silently preserving partial payloads.

## Solution

### Immediate Fix
Added `classroom` to the assignment fixture and added coverage for classroom
detail, attempts, answers, and assignment results.

```bash
cd mobile_flutter && flutter test
```

### Long-term Fix
Continue extending the existing contract test whenever a REST resource gains a
mobile-consumed field.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update
- [x] Code changes required

## Related Issues
- None.

## References
- `intelligent_memory_management/contracts/api.md`
- `mobile_flutter/lib/core/labs/models.dart`
- `mobile_flutter/test/home_models_test.dart`

---

**Resolved By:** Copilot
**Time to Resolution:** Same implementation session
