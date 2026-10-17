# TESC Department Name Variant Audit

**Date:** 2026-10-17  
**Project:** TESC  
**Type:** Audit  
**Status:** Completed

## Summary

A read-only audit examined the department names remaining after the exact
global `Administration` duplicate was removed. The audit found no additional
case-insensitive duplicate names within the same institution scope, but it
identified two unused global HR variants and several institution-scoped
spelling or wording variants that cannot be merged safely without canonical
names, permission review, and user-assignment mapping.

## Context / Trigger

The Settings page continued to show `human resource` and `Human Resources`,
and the user requested investigation of similar remaining issues without an
unverified cleanup.

## Scope

Included live department rows in staging and production, institution scope,
creation timestamps, inline permission payload presence, and assigned-user
counts. Excluded deletion, renaming, reassignment, permission migration,
schema changes, and application code changes.

## Method

The same read-only SQL checks were run independently against both PostgreSQL
databases. Results were compared by scope, normalized name, permissions, and
user assignment count. The audit treated institution-scoped records as
separate namespaces and did not infer that repeated names across institutions
were duplicates.

## Decisions & Findings

- Global ID 105 `human resource` is unused and has no permissions.
- Global ID 146 `Human Resources` is unused but has the `/staff` permission.
- These two rows are semantic candidates, not exact normalized duplicates;
  deleting either one without a permission decision would be unsafe.
- No same-scope case-insensitive duplicate groups remain in either environment.
- `Human Resourses` at Harare Polytechnic has one user and must not be
  auto-collapsed.
- Singular/plural and wording variants across institutions are generally
  expected scope-local records, but their vocabulary is inconsistent.
- Production contains newer institution-scoped rows not present in staging;
  production must therefore be audited independently for any future cleanup.

## Changes Made

- No TESC application or database changes.
- Added the corresponding issue record:
  `Database_and_State/TESC-2026-10-17-department-name-variants.md`.

## Verification

- Staging and production PostgreSQL queries completed successfully.
- Same-scope `lower(trim(name))` duplicate query returned no rows in either
  environment.
- HR candidate rows, permission payloads, creation timestamps, and assigned
  user counts were inspected in both environments.
- No containers were restarted and no records were mutated.

## Follow-ups / Deferred

- Agree on canonical global and institution department vocabulary.
- Build a dry-run reconciliation report with explicit merge targets.
- Preserve users and permissions during any approved merge.
- Add a canonical registry/alias model and enforce scoped uniqueness only
  after existing data is reconciled.

## References

- `Database_and_State/TESC-2026-10-17-department-name-variants.md`
- `Database_and_State/TESC-2026-10-17-duplicate-global-departments.md`
- `reports/TESC-2026-10-17-department-duplication-investigation.md`

---

**Completed By:** Copilot  
**Duration:** One read-only audit session
