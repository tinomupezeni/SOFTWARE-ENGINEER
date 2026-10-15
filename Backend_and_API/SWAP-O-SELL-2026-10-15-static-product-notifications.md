# Product interactions had no durable notifications

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Environment:** Development  
**Severity:** Medium  
**Status:** Resolved

## Summary
Product likes and saves were persisted only as interaction rows and did not create notification records for the listing owner. As a result, a dynamic notifications page could not accurately show or mark those events as read.

## Symptoms
- The Notifications page used static sample like/save entries.
- Existing message and comment notifications had backend persistence, but product interactions did not.
- Marking product interaction notifications read had no durable backend target.

## Environment Details
- **Server/Host:** Local Docker Compose
- **Services Affected:** Django listings API and React frontend
- **Related Components:** ProductLike, ProductSave, Notifications page
- **Time First Observed:** 2026-10-15

## Investigation Steps

### 1. Initial Diagnosis
Inspected the static Notifications page and traced its sample data dependency into the backend notification endpoints.

### 2. Root Cause Analysis
The listings like/save handlers only updated interaction rows and analytics. No notification model or creation path existed for the product owner.

### 3. Key Findings
- Message notifications and comment notifications were already durable.
- Product likes and saves had timestamps but no recipient/read state.
- A unified endpoint was needed to normalize the separate sources.

## Root Cause
Notification persistence was implemented per feature rather than through a shared marketplace notification contract, leaving product engagement events outside the notification system.

## Prevention / Rule
**Guardrail:** Every user-facing notification type must have a persisted record with recipient, actor, event type, timestamp, and read state before it is exposed in notification UI.

This schema requirement prevents frontend-only notification entries that cannot be refreshed or marked read reliably.

## Solution

### Immediate Fix
Added `ProductNotification`, created records from like/save actions, and exposed them together with message/comment notifications through `/api/listings/notifications/`.

### Long-term Fix
Keep new notification types behind the same durable contract and add pagination when notification volume exceeds the current response limit.

## Prevention
- [x] Schema and handler changes required
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [x] Documentation to update

## Related Issues
- Dynamic Notifications initiative report: `reports/SWAP-O-SELL-2026-10-15-dynamic-notifications.md`

## References
- `backend/modules/listings/models.py`
- `backend/modules/listings/views.py`
- `swappify-social-hub/src/pages/Notifications.tsx`

---

**Resolved By:** Copilot  
**Time to Resolution:** One implementation session
