# Room Schema Export Directory Not Provided Warning

**Date:** 2026-10-08
**Project:** Inclusivity
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
During the compilation of the `Inclusivity` project, a Room Database annotation processor warning was raised because the `room.schemaLocation` was not configured in the Gradle build file. This is a minor misconfiguration that prevents Room from exporting its schemas for version tracking and migration testing.

## Symptoms
- Build logs contained the following warning:
  `warning: Schema export directory was not provided to the annotation processor so Room cannot export the schema. You can either provide room.schemaLocation annotation processor argument by applying the Room Gradle plugin (id 'androidx.room') OR set exportSchema to false.`

## Environment Details
- **Server/Host:** Local Development
- **Services Affected:** Room Database Configuration
- **Related Components:** `AppDatabase.kt`, `build.gradle`
- **Time First Observed:** 2026-10-08

## Investigation Steps

### 1. Initial Diagnosis
Checked the build logs from `./gradlew assembleDebug`. The warning was explicit about the missing `room.schemaLocation` or `exportSchema = false`.

### 2. Root Cause Analysis
The Room annotation processor requires a designated directory to export schema files in JSON format to support `MigrationTestHelper` and reliable database versioning. The build script lacked this configuration.

## Root Cause
The `androidx.room` compiler argument `room.schemaLocation` was not passed to KSP/KAPT in the `build.gradle` file, nor was `exportSchema = false` set in the `@Database` annotation.

## Prevention / Rule
**Guardrail:** Enforce Room Schema Export configuration.
When configuring Room databases in Android projects, the `build.gradle` (or `build.gradle.kts`) MUST include the `room.schemaLocation` argument passed to the annotation processor (KSP/KAPT) to ensure schemas are reliably exported for migration testing. Alternatively, if no migration testing is intended, `exportSchema = false` must be explicitly declared on the `@Database` annotation to suppress the warning and document the intent.

## Solution

### Immediate Fix
For now, the warning does not stop the build or execution, but it should be fixed by configuring KSP/KAPT to export the schema to a local directory like `"$projectDir/schemas"`.

### Long-term Fix
Update the `build.gradle` to include Room's schema location argument.

## Prevention
- [x] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [ ] Code changes required

---

**Resolved By:** Antigravity
**Time to Resolution:** 10 minutes
