---
title: Multi-Tenant Offline Storage Isolation
date: 2026-09-24
project: HBEC
status: resolved
---

# Issue
The frontend's offline caching layer (\`localStorage\` and \`DuckDB\`) was inherently single-tenant. When a user logged out or their session was revoked (e.g. by an Admin deleting the account), the cached data remained on the device. If the same device was used to sign up or log in as a different user (even with the same email), the new session would instantly hydrate with the previous user's data (practice sessions, chat history, notes, themes) because the storage keys were global.

# Root Cause
Storage keys in \`localStorage\` (like \`hbc_notes\`) and the DuckDB database name (\`hbec_offline.db\`) were hardcoded and global to the browser, with no scoping by \`user_id\`.

# Solution
Implemented a transparent, multi-tenant scoping mechanism:
1. **Global localStorage Override**: Patched \`Storage.prototype\` early in the initialization phase to automatically append the \`user_id\` (extracted from the JWT token) to all application storage keys. Existing unscoped keys are automatically migrated to their scoped equivalents upon first login.
2. **DuckDB Isolation**: Modified \`initializeDuckDB\` to use a dynamic database name (\`hbec_offline_{userId}.db\`).
3. **Session Switching**: Added an \`onAuthChanged\` event listener to \`api.ts\` which triggers \`OfflineContext\` to seamlessly close the active DuckDB instance and re-initialize it for the new user during a login/logout cycle.

This ensures students sharing the same physical device are completely isolated from each other's offline progress and cached data.

Resolved By: Antigravity
