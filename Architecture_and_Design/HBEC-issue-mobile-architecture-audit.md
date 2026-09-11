# HBEC Student Mobile App Audit (v1.0)

**Date:** 2026-05-07
**Project:** HBEC Student Mobile
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary
Audit of the HBEC Student Mobile app against enterprise engineering principles (derived from Mattermost Mobile v2). The app demonstrates a solid foundation with WatermelonDB and Feature-based modularity but has significant gaps in synchronization completeness, UI feedback, and testing rigor.

## Symptoms / Audit Findings

### 1. Incomplete Sync Lifecycle
- **Observation:** `CatalogService.ts` handles creation and updates but lacks deletion logic.
- **Risk:** Local data rot where removed subjects/topics remain on the device indefinitely.

### 2. UI Interaction Debt
- **Observation:** Core components (e.g., `SubjectListItem`) use `Pressable` without visual feedback for the `pressed` state.
- **Risk:** The app feels unresponsive or "broken" to the user during touch interactions.

### 3. Suboptimal Testing Strategy
- **Observation:** Unit tests in `src/offline/services/__tests__` mock the WatermelonDB database and collections.
- **Risk:** Tests fail to catch schema violations, constraint errors, or actual DB interaction bugs.

### 4. Lack of Standardized Logging
- **Observation:** Widespread use of `console.log` and `console.error` throughout services and components.
- **Risk:** Inability to manage log levels in production or implement remote error tracking effectively.

### 5. Architectural Coupling
- **Observation:** A single database instance manages both persistent curriculum data and transient sync queue/user profile data.
- **Risk:** Potential for performance bottlenecks as the curriculum grows; difficult to implement multi-user support.

## Root Cause Analysis
- **One-way Sync:** The sync engine was built with a "fetch and update" mindset rather than a "reconcile" mindset.
- **UI Rapidity:** Focus on layout (NativeWind/Gluestack) over interaction physics.
- **Mock-heavy Culture:** Preference for fast-running unit tests over high-fidelity integration tests.

## Solution / Recommendations

### Immediate Fixes (Technical Debt)
1.  **Reanimated Integration:** Add `react-native-reanimated` and implement basic layout animations.
2.  **Pressable Feedback:** Update `src/components/ui` and domain components to include `pressed` state styles.
3.  **Logger Utility:** Create a `src/utils/logger.ts` and replace all `console` calls.

### Long-term Architectural Changes
1.  **Full-Lifecycle Sync:** Refactor `CatalogService` and `SyncQueueService` to perform ID-diffing and remove stale local records.
2.  **In-Memory DB Testing:** Update `jest.setup.js` to provide a LokiJS adapter for tests, removing the need for manual DB mocks.
3.  **Database Separation:** Evaluate a "Dual-Database" approach if supporting multiple student accounts or extremely large curriculum sets.

## Prevention
- [ ] Implement `eslint-plugin-react-hooks` with strict enforcement.
- [ ] Add pre-commit check for `console.log` usage.
- [ ] Establish a "Sync Reconciliation" template for all new offline services.

## References
- `dev-logs/Mattermost App/lessons-engineering-principles.md`
- Mattermost Mobile v2 Architecture Guide

---

**Resolved By:** Gemini CLI (Principal Engineer Persona)
**Audit Duration:** 1 hour
