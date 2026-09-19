---
project: ZCHPC-ERP
date: 2026-09-17
area: Frontend_and_UI
title: Login Audit Logs parsing error due to backend pagination wrapping
---

# Issue Description
The `Logs.tsx` UI component in the Main ERP was hardcoded to expect an array of logs directly on the `axios` response data body. However, the `AuditLogListView` on the Django backend returns a paginated-style object dictionary `{"count": 143, "results": [...]}`. 

Because `data.data` was an object and not an array, `logs.length > 0` evaluated to false (checking length on an object returns undefined), causing the frontend to incorrectly display "No logs available" despite the database containing hundreds of login audit entries.

# Resolution
Updated `Logs.tsx` to safely fallback to `data.data.results` when retrieving the array.
```javascript
// Before
setLogs(data.data);

// After
setLogs(data.data.results || data.data);
```

**Resolved By:** Antigravity
