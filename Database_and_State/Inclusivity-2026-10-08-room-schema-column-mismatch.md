# Room Schema Column Mismatch (TileTimePattern)

**Date:** 2026-10-08
**Project:** Inclusivity
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary
A Room compile-time error occurred during the build due to a mismatched column name between the DAO and the Entity definition for `TileTimePattern`.

## Symptoms
- The Android project failed to compile with the error `[SQLITE_ERROR] SQL error or missing database (no such column: usageCount)`.
- The `TileTimePatternDao` attempted to query `usageCount`, but the `TileTimePattern` entity defined the column as `count`.
- Furthermore, `lastUsedAt` was missing in `TileTimePattern` but referenced when creating it in `LearningEngineImpl`.

## Environment Details
- **Server/Host:** Local Desktop
- **Services Affected:** Room Database Compilation
- **Related Components:** `TileTimePattern.kt`, `TileTimePatternDao.kt`
- **Time First Observed:** During Gradle build of new LearningEngine feature.

## Investigation Steps

### 1. Initial Diagnosis
The Gradle build failed with `kaptDebugKotlin FAILED`. The error message pointed to `TileTimePatternDao.java` failing to compile due to `usageCount` missing.

### 2. Root Cause Analysis
Checked `TileTimePattern.kt` and found it declared `count` instead of `usageCount`. It was out of sync with `TileContext.kt` which used `usageCount` and `lastUsedAt`.

### 3. Key Findings
- `TileTimePatternDao` used `usageCount` in its `ORDER BY` clause.
- `TileTimePattern` had `count` and was missing `lastUsedAt`.

## Root Cause
Inconsistent schema definitions when creating new entities. The DAO was written assuming a schema matching `TileContext`, but the entity was created with different field names.

## Prevention / Rule
**Guardrail:** Use a Room schema validation or always ensure that newly created Entities and DAOs are strictly aligned by running `kapt` or `ksp` immediately after creating/modifying them, before proceeding to implement business logic that depends on them.
This will catch mismatched column references at the very beginning of the feature development.

## Solution

### Immediate Fix
Updated `TileTimePattern.kt` to:
```kotlin
    val usageCount: Int = 0,
    val lastUsedAt: Long? = null
```

### Long-term Fix
Ensure all entities sharing similar logic (e.g., usage patterns) implement a common interface or are created with consistent naming conventions.

## Prevention
- [x] Code changes required (Updated entity)

## Related Issues
- Related to the introduction of `LearningEngine`.

---

**Resolved By:** Antigravity
**Time to Resolution:** 5 minutes
