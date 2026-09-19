---
project: ZCHPC-ERP
date: 2026-09-17
area: Frontend_and_UI
title: Frontend ignoring backend 400 Validation Errors during Delete operations
---

# Issue Description
The user reported a `400 Bad Request` in the console when attempting to delete a department. 
The API backend accurately returned a `400` status with `{ "error": "Cannot delete department with 1 employees", "code": "DEPARTMENT_HAS_EMPLOYEES" }` because the domain model strictly forbids deleting non-empty organizational units.

However, the UI was ignoring the JSON payload entirely. The catch block simply logged the generic `AxiosError: 400` to the console and displayed a generic fallback string instead of the specific business rule violation message.

# Resolution
Updated the `SettingsPage.tsx` catch block (and similar delete endpoints) to parse and display the server's error message if available:
```javascript
.catch(err => {
    const errorMsg = err.response?.data?.error || "Failed to delete department";
    toast.error(errorMsg);
});
```
This ensures domain-layer validation rules are surfaced cleanly to the end user.

**Resolved By:** Antigravity
