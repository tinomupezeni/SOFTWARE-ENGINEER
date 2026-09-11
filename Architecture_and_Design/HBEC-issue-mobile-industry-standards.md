# HBEC Mobile Audit: Advanced Engineering & Industry Standards (v1.1)

**Date:** 2026-05-07
**Project:** HBEC Student Mobile
**Persona:** Principal Engineer
**Focus:** Observability, Security, UX Physics, Accessibility

## Summary
While the base architecture is sound (WatermelonDB + Expo 51), the app lacks several "Tier-1" mobile engineering standards required for enterprise-grade deployments. This audit focuses on observability, advanced security, and inclusive design.

## Technical Gaps & Risks

### 1. Observability: The "Blind Production" Risk
- **Issue:** Error handling is localized to `Alert.alert` and `console.error`.
- **Principal View:** Without a remote observability platform (Sentry, Bugsnag, or Firebase), we have zero visibility into crashes or silent failures in the field.
- **Risk:** We only learn about bugs when a student manually reports them, which is too late for an educational platform.

### 2. Security: Vulnerability to Educational MitM
- **Issue:** No Certificate Pinning (SSL Pinning) implementation.
- **Principal View:** Students often use shared school or public Wi-Fi. These environments are prone to Man-in-the-Middle (MitM) attacks.
- **Risk:** Attackers can intercept or modify curriculum content/exam data. SSL pinning is a standard requirement for "Pro" educational tools.

### 3. UX Physics: Feedback vs. Interruption
- **Issue:** Widespread use of `Alert.alert` for non-fatal errors (e.g., 429 Rate Limiting, 500 Server Busy).
- **Principal View:** Alerts are "blocking" UI. They force the student to stop their learning flow to acknowledge a system error.
- **Risk:** High cognitive load and frustration. Industry standard is to use **Toast notifications** for transient errors and **Inline Empty States** for missing data.

### 4. Accessibility: Inclusive Education
- **Issue:** Fixed typography and layout in components like `SubjectListItem`.
- **Principal View:** A student app must respect **Dynamic Type** (system font scaling) and provide `accessibilityLabel`s for screen readers (TalkBack/VoiceOver).
- **Risk:** Excluding students with visual impairments, which may violate educational accessibility standards.

### 5. Resource Management: Storage Awareness
- **Issue:** `DownloadManager` cleanup is time-based/manual.
- **Principal View:** The app does not listen to system-level storage pressure events or optimize image caching beyond basic file storage.
- **Risk:** App being purged by the OS if it consumes too much background storage without notifying the system it can release cache.

## Recommendations

### Short-Term (Standardization)
1.  **Remote Monitoring:** Integrate Sentry (Expo support is excellent) to capture both JS errors and native crashes.
2.  **Modern Notifications:** Replace non-fatal Alerts with a Toast library (e.g., `react-native-toast-message` or custom Gluestack toast).
3.  **Haptic Feedback:** Integrate `expo-haptics` for "success" or "error" states during sync/marking to provide physical confirmation.

### Long-Term (Enterprise Hardening)
1.  **SSL Pinning:** Implement certificate pinning for `api.hbca.tech` using `expo-build-properties` or native modules.
2.  **Adaptive Typography:** Refactor styling to use relative units or `typography()` helpers that respect system font scaling.
3.  **Image Optimization:** Use `expo-image` for all artifacts and subject icons to benefit from its superior caching and "blurhash" support.

## Prevention & Workflow
- [ ] Add `Sentry.wrap` to `App.tsx`.
- [ ] Audit all `Pressable` components for `accessibilityRole` and `accessibilityLabel`.
- [ ] Implement a "Network Resilience" test case in Maestro that simulates slow/flaky school Wi-Fi.

---

**Logged By:** Gemini CLI (Principal Engineer Persona)
