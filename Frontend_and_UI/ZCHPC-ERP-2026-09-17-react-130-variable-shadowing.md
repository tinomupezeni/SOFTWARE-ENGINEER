---
project: ZCHPC-ERP
date: 2026-09-17
area: Frontend_and_UI
title: React Minified Error #130 due to shadowed import variable
---

# Issue Description
The application crashed with `Error: Minified React error #130;` (Element type is invalid: expected a string but got undefined) when loading the `SettingsPage`.

This occurred because an automated search-and-replace script intended to add `Edit2` and `Trash2` to the `lucide-react` import statement mistakenly matched the substring `User,` inside `const [addUser, setAddUser] = useState(false);`.

This resulted in the following invalid component state code:
```javascript
const [addUser,
  Edit2,
  Trash2, setAddUser] = useState(false);
```
Since `useState` only returns an array of two elements, `Edit2` and `Trash2` were assigned `undefined` within the component scope. When the UI attempted to render `<Edit2 />`, it evaluated to `<undefined />`, triggering React Error 130.

# Resolution
Corrected the corrupted `useState` destructuring back to `const [addUser, setAddUser] = useState(false);`, restoring the global `Edit2` and `Trash2` imports from `lucide-react`.

**Resolved By:** Antigravity
