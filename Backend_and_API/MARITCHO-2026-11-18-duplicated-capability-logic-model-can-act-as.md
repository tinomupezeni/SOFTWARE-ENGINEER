# model_can_act_as Duplicates Person.acts_as() Domain Logic on ORM Model

**Date:** 2026-11-18
**Project:** MARITCHO
**Environment:** Development (found in code review of PR #13, pre-merge)
**Severity:** Low
**Status:** Resolved

## Summary
`model_can_act_as` (`backend/app/apps/accounts/infrastructure/models.py:47`) reimplements the identical role-capability union logic as the new `Person.acts_as()` domain method, operating directly on the ORM model instead of converting to the domain entity first. `get_public_profile` depends on this infrastructure copy rather than the canonical domain method.

## Symptoms
- Two separate implementations of the same capability rule exist: one on the domain entity (`Person.acts_as()`), one on the ORM model (`model_can_act_as`).
- No current behavioral divergence, but the two are not guaranteed to stay in sync.

## Environment Details
- **Server/Host:** N/A (application logic)
- **Services Affected:** Public worker profile visibility
- **Related Components:** `backend/app/apps/accounts/infrastructure/models.py:47`, `backend/app/apps/workers/infrastructure/repositories.py:415` (`get_public_profile`), `Person.acts_as()`
- **Time First Observed:** 2026-11-18, during code review of PR #13

## Investigation Steps

### 1. Initial Diagnosis
Code review found a second implementation of the capability union logic introduced in the same PR that defined `Person.acts_as()`.

### 2. Root Cause Analysis
The infrastructure layer (`get_public_profile`) needed the capability check but was written against the ORM model directly instead of converting to/using the domain entity, so the logic was copied rather than reused.

### 3. Key Findings
- A future change to the capability rule (e.g. expiring capabilities, revocable roles) applied to `Person.acts_as()` and forgotten in `model_can_act_as` would leave `get_public_profile` silently enforcing a stale rule.

## Root Cause
Capability-check logic duplicated across domain and infrastructure layers instead of the infrastructure layer delegating to the single domain method.

## Prevention / Rule
**Guardrail:** Code-review checklist item — any new business-rule logic (especially authorization/capability logic) found duplicated between a domain entity and its ORM model must be flagged; the infrastructure layer must convert to the domain entity (or call a shared pure function) rather than reimplementing the rule.

This closes the gap by catching duplicated business logic at review time, before divergence can occur in a later change.

## Solution

### Immediate Fix
Removed `model_can_act_as`. The accounts repository's private `_to_entity` mapper was made public as `person_from_model`; `get_public_profile` now converts the loaded `PersonModel` to the `Person` domain entity via `person_from_model()` and calls `.acts_as(RoleEnum.WORKER)` directly.

### Long-term Fix
Done — see Immediate Fix.

## Prevention
- [ ] Code changes required

## Related Issues
- None

## References
- PR #13 (Maritcho, `experimental` -> `main`)

---

**Resolved By:** Pending
**Time to Resolution:** N/A
