# Flutter Secure Storage Offline Cache Type Poisoning

**Date:** 2026-10-03
**Project:** ClubZero
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary
The Flutter app utilizes an offline-first caching strategy via `flutter_secure_storage`. When the backend API response schema for `/clubs/{club_id}/stats` was changed (the `history` array elements changed from `bool` to `int`), the app crashed immediately on load because it attempted to parse the legacy cached JSON data using the new UI models before the network request had a chance to fetch the updated schema.

## Symptoms
- Flutter client threw `type 'bool' is not a subtype of type 'int' in type cast` resulting in a complete UI render failure (red screen of death).
- The crash occurred instantly upon opening the app, before any network requests were made.
- Recompiling and restarting the app did not resolve the issue, as the cache persisted across sessions.

## Environment Details
- **Server/Host:** Android Device (SM S906U1)
- **Services Affected:** `DashboardProvider._fetchSeats()`, `DashboardScreen`, `StatsScreen`
- **Related Components:** `flutter_secure_storage`
- **Time First Observed:** 2026-10-03

## Investigation Steps

### 1. Initial Diagnosis
Checked Flutter stack traces and found the crash was occurring at `dashboard.stats!['history'] as List?)?.cast<int>()`. 

### 2. Root Cause Analysis
Analyzed `DashboardProvider` and realized `_fetchSeats()` synchronously loads from `_storage.read(key: statsCacheKey)` and triggers a UI rebuild using the stale data before waiting for `_clubService.fetchStats()` to return the new data.

### 3. Key Findings
- The offline cache acts as a persistent snapshot of the previous API schema.
- Because the cache is loaded before network initialization, any destructive schema change applied to the backend will instantly break the client if the client does not gracefully handle legacy cache formats.

## Root Cause
The client assumed the cached JSON data exactly matched the expected type signatures of the current Dart code. When the backend schema migrated from booleans to integers, the old cached data became a "poison pill" that threw unhandled type cast exceptions, preventing the app from continuing execution to fetch the new valid data.

## Prevention / Rule
**Guardrail:** Implement strict JSON validation (e.g. `try-catch` blocks around `jsonDecode` + data casting) when reading from local offline storage, and fallback to `null` (triggering a blocking loading state) if the cache schema fails validation.

By wrapping the local cache restoration in a try-catch block, schema mismatches will gracefully clear the cache and wait for the network request instead of catastrophically crashing the UI thread.

## Solution

### Immediate Fix
Invalidated the cache manually by incrementing the cache key in `DashboardProvider` (e.g., changing `dashboard_stats_cache_$clubId` to `dashboard_stats_cache_v3_$clubId`), forcing the app to bypass the poisoned secure storage entry and fetch fresh data from the network.

### Long-term Fix
Implement defensive deserialization in `DashboardProvider._applyData()` to catch type cast errors and automatically wipe the specific cache key if validation fails.

## Related Issues
- ClubZero-2026-10-03-fastapi-duplicate-routes.md (Occurred simultaneously, confounding the debugging process).

---

**Resolved By:** Antigravity
**Time to Resolution:** 10m
