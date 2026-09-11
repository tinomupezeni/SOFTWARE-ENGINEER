# Engineering Principles for Scalable Mobile Apps (Mattermost Mobile)

**Date:** 2026-05-07
**Project:** Mattermost Mobile
**Type:** Architectural Lesson
**Focus:** Scalability, Reliability, Performance

## Summary
Analysis of the Mattermost Mobile v2 architecture reveals a mature, enterprise-grade React Native framework optimized for offline-first reliability and multi-server complexity. These lessons serve as a blueprint for high-performance mobile engineering.

## Key Principles & Lessons

### 1. Offline-First via High-Performance Persistence
**Concept:** Treat the local database as the primary source of truth, not a cache.
- **Dual-Database Strategy:** Isolate global app state from server-specific data to prevent cross-server corruption.
- **JSI Optimization:** Use the JavaScript Interface (JSI) for near-native SQLite performance, bypassing the traditional React Native bridge overhead.
- **Operator Pattern:** Decouple data fetching from persistence logic using "Operators" to handle complex transformations and batching.

### 2. Product-Oriented Modularity
**Concept:** Structure the codebase by business domain ("Products") rather than technical layers.
- **Isolation:** Features like Calls or AI Agents should have independent database models and action sets.
- **ClientMix Pattern:** Allow product-specific extensions to the core network client to prevent a monolithic, bloated API handler.

### 3. Strict Sync Lifecycle Management
**Concept:** Synchronization must be exhaustive.
- **Full Lifecycle:** Sync handlers must handle Create, Update, and **Delete**.
- **Removal Logic:** Implement deterministic cleanup for records no longer present on the server to prevent local data rot.

### 4. Performance-First UI Standards
**Concept:** Enforce low-level UI constraints to ensure fluid interaction.
- **Declarative Animations:** Mandatory use of `react-native-reanimated` to ensure animations run on the UI thread.
- **Component Discipline:** 
    - Ban `TouchableOpacity` in favor of `Pressable` with explicit feedback.
    - Abstract typography to prevent magic numbers in styling.
    - Extract static objects to module-level constants to prevent unnecessary re-renders.

### 5. Defensive & Empirical Verification
**Concept:** Test against reality, not just abstractions.
- **Real DB Testing:** Use real in-memory databases for integration tests to verify persistence logic.
- **CI Rigor:** Treat linting and dependency array correctness (`exhaustive-deps`) as hard build requirements.

## Implementation Guidelines

### Action Flow
1. **Remote Action:** Fetch from API.
2. **Operator:** Transform and prepare records.
3. **Database:** Batch save to persistence.
4. **Query/Observable:** Reflect changes in UI.

### UI Styling
- Use `makeStyleSheetFromTheme` for theme-aware components.
- Always use the `typography()` utility for text styles.
- Use `Platform.select()` for platform-specific tweaks.

## References
- Mattermost Mobile `CLAUDE.md` and `README.md`
- WatermelonDB Documentation
- React Native Reanimated Best Practices

---

**Logged By:** Gemini CLI (Principal Engineer Persona)
