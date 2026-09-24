# Topics Share Button Unresponsive

**Date:** 2026-09-24
**Project:** HBEC
**Environment:** Staging / Development
**Severity:** Medium
**Status:** Resolved

## Summary
The "Share" button for Topics was completely unresponsive. A user clicked it and nothing happened. Further, the previous implementation used a single-item share button inside a dropdown instead of a bulk selection interface as expected. Finally, when testing the API route, a 404 error was triggered because the route erroneously included a double `/api/api/` prefix.

## Symptoms
- Clicking "Share" on a topic silently did nothing on the UI.
- No modal or dialog appeared.
- A `TypeError: h is not a function` error appeared in the console previously when the dropdown version was implemented incorrectly.
- When an API request was finally fired, a `POST https://staging-admin.hbca.tech/api/api/curriculum/topics/share/ 404 (Not Found)` error occurred.

## Environment Details
- **Server/Host:** Admin Frontend
- **Services Affected:** React Frontend (`TopicsManager.tsx`, `TopicList.tsx`, `TopicShareModal.tsx`)
- **Related Components:** Admin Backend (`TopicShareView`)
- **Time First Observed:** 2026-09-24

## Investigation Steps

### 1. Initial Diagnosis
Reviewed the console logs which indicated `onClick` in `TopicList` was crashing because the prop passed down was not a function.

### 2. Root Cause Analysis
- The `TopicShareModal` component was completely missing from the JSX returned by `TopicsManager`. Although it was imported, it was never rendered.
- The `TopicList` was recursively passing down `onShare` to children `TreeRow` components but one level of the prop drilling was missed, causing `onShare` to be undefined at the point of invocation.
- The API fetcher `curriculumApi.ts` manually prepended `/api/` to the route `/api/curriculum/topics/share/`, but the global `apiFetch` wrapper already prepends `/api/` by default.

### 3. Key Findings
- The UI did not allow bulk sharing, contrary to user expectations.
- React components that manage modals must actually render the modal component in their output.
- Custom fetch wrappers should have their base URLs and path requirements clearly documented so developers don't double-prefix.

## Root Cause
- The `TopicShareModal` was omitted from the `TopicsManager` return statement.
- The UI was designed for single-item sharing and suffered from prop-drilling errors.
- The fetch wrapper URL resolution caused a double `/api/api/` string concatenation.

## Prevention / Rule
**Guardrail:** Ensure comprehensive frontend end-to-end (E2E) testing (e.g., using Cypress or Playwright) is implemented for critical user workflows, including clicking the share button and validating the modal opens. Furthermore, linting rules (e.g., `eslint-plugin-react`) should flag imported but unused components to prevent missing modals.

E2E tests that physically interact with the DOM will catch silent failures like missing modal components, and linting rules will flag unused imports, preventing developers from forgetting to render imported components.

## Solution

### Immediate Fix
- Redesigned `TopicList.tsx` to move the "Share Topics" button to the top header for bulk actions.
- Rewrote `TopicShareModal.tsx` to accept a list of all topics and render checkboxes to allow multi-selection of topics and target grades.
- Rendered `<TopicShareModal>` inside `TopicsManager.tsx` and wired its `isOpen`, `onClose`, and `topics` props correctly.
- Removed the redundant `/api/` prefix in `shareTopics` fetcher within `curriculumApi.ts`.

### Long-term Fix
- Implement E2E tests for the curriculum management workflows.
- Centralize API path resolution logic to automatically handle leading slashes gracefully.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- N/A

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 30 minutes
