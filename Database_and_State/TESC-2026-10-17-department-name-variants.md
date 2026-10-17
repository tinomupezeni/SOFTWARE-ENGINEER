# Remaining Department Name Variants

**Date:** 2026-10-17  
**Project:** TESC  
**Environment:** Staging and Production  
**Severity:** Medium  
**Status:** Investigating

## Summary

After removing the confirmed-unused duplicate global `Administration` row,
the remaining department concern is semantic and spelling variation rather
than another exact duplicate within the same scope. The global list contains
both `human resource` and `Human Resources`; both rows are unused, but the
second carries a `/staff` permission. Institution-scoped departments repeat
common names across different institutions as expected, while some records
contain spelling or wording variants and active user assignments.

## Symptoms

- Main System settings still contains both `human resource` and
  `Human Resources`.
- Institution department lists use mixed singular/plural and spelling forms,
  including `Human Resource`, `Human Resources`, and `Human Resourses`.
- A name-only cleanup could remove permission intent or move users to the
  wrong institution department.

## Environment Details

- **Server/Host:** staging `10.50.1.37`; production `10.50.200.35`
- **Services Affected:** Django users API and TESC Settings UI
- **Related Components:** `users.Department`, department API, Settings UI
- **Time First Observed:** 2026-10-17

## Investigation Steps

### 1. Initial Diagnosis

Queried the live `users_department` data in both environments, including
scope, creation time, inline permissions, and assigned-user counts.

### 2. Root Cause Analysis

Compared department names within each institution scope using normalized
case/whitespace matching. The existing model constraint is
`unique_together = ('institution', 'name')`, which is case-sensitive and
does not define a canonical vocabulary for semantically equivalent names.

```sql
WITH dc AS (
  SELECT d.id, d.institution_id, d.name, count(u.id) AS users
  FROM users_department d
  LEFT JOIN users_customuser u ON u.department_id = d.id
  GROUP BY d.id, d.institution_id, d.name
)
SELECT institution_id, lower(trim(name)), count(*)
FROM dc
GROUP BY institution_id, lower(trim(name))
HAVING count(*) > 1;
```

### 3. Key Findings

- Staging and production have the same two global HR candidates:
  - ID 105: `human resource`, unused, empty permissions.
  - ID 146: `Human Resources`, unused, permission `/staff`.
- No remaining case-insensitive duplicate name groups were found within the
  same institution scope in either environment.
- Repeated names across different institutions are expected scoped records,
  not global duplicates.
- `Human Resourses` at Harare Polytechnic has one assigned user and cannot be
  treated as an unused typo.
- Other institution-scoped singular/plural variants have assignments in some
  environments and require institution-owner confirmation before merging.
- Staging and production differ in some newer institution-scoped rows, so
  staging data cannot be used as proof for a production cleanup.

## Root Cause

Department identity is represented by free-form display text plus a nullable
institution scope. The schema prevents only exact `(institution, name)`
duplicates and does not encode canonical names, aliases, merge targets, or
the preservation of inline permissions during reconciliation.

## Prevention / Rule

**Guardrail:** Introduce a reviewed canonical department registry with
explicit institution scope and alias/merge metadata, then validate new names
against it before adding a case-insensitive scoped uniqueness constraint.

This separates legitimate cross-institution reuse from same-scope naming drift
and makes any future merge preserve assignments and permission intent.

## Solution

### Immediate Fix

No data was changed. The audit stopped at classification because the global
HR rows have different permission payloads and the institution-scoped
variants include active assignments.

### Long-term Fix

- Obtain the canonical vocabulary for global and institution departments.
- Produce a dry-run mapping of every candidate row to a canonical target.
- Review each mapping with the owning institution and preserve users and
  permissions.
- Apply changes independently in staging and production only after backups
  and target-data preflight.
- Add creator/audit metadata and a single idempotent department creation
  service.

## Prevention

- [ ] Define canonical department names and approved aliases
- [ ] Add a read-only duplicate/variant audit to CI or operations checks
- [ ] Add merge tooling with assignment and permission preservation
- [ ] Add case-insensitive scoped uniqueness after reconciliation
- [ ] Add department creation audit metadata

## Related Issues

- `TESC-2026-10-17-duplicate-global-departments.md`

## References

- `backend/users/models.py:58-75`
- `backend/users/views/settings_views.py:45-105`
- `frontend/src/pages/Settings.tsx:573-632`
- `reports/TESC-2026-10-17-department-duplication-investigation.md`

---

**Resolved By:** Not resolved; investigation recorded by Copilot  
**Time to Resolution:** Not applicable
