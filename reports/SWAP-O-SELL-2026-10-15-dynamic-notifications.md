# Dynamic Notifications

**Date:** 2026-10-15  
**Project:** Swap-O-Sell  
**Type:** Feature implementation  
**Status:** Completed

## Summary
Replaced the static Notifications page with an authenticated, API-backed feed covering product likes, saves, messages, and comments. The feed now has persistent read state, merged chronological ordering, live unread counts, and links to the relevant product, profile, or messages page.

## Context / Trigger
The Notifications page displayed hard-coded January 2025 examples and only changed local React state when a user marked an item read. The backend already persisted message and comment notifications, while product likes and saves had no notification records.

## Scope
Included the backend notification contract, product interaction notification persistence, frontend loading/read/error/empty states, and API validation. Existing notification types without backend persistence, such as follows and sales, remain intentionally unsupported rather than being fabricated.

## Method
Inspected the existing message/comment notification payloads and product interaction endpoints, then composed them behind one authenticated endpoint. Added a small product notification model for like/save events, linked creation to the existing interaction handlers, and normalized all sources into one frontend shape.

## Decisions & Findings
- A unified endpoint avoids making the frontend understand three different read-state contracts.
- Product like/save notifications are created only for interactions with another user's listing; self-interactions do not notify the owner.
- Notification identifiers are source-prefixed so individual read actions can update the correct underlying table.
- The existing static sample notifications were not used as fallback data because unsupported events would misrepresent live state.

## Changes Made
- Added `ProductNotification` and migration `modules_listings.0009_productnotification`.
- Added like/save notification creation in `like_product` and `save_product`.
- Added `GET/POST /api/listings/notifications/` for merged retrieval and read actions.
- Added frontend `Server.fetchNotifications` and `Server.markNotificationsRead`.
- Reworked `Notifications.tsx` to load live records, merge read state, display accurate tabs/counts, and link actions.

## Verification
- Frontend `npm run build` passed.
- Backend container `manage.py check` passed.
- Backend notification migration applied successfully in Docker.
- Backend files passed Python compilation.
- `git diff --check` passed.
- Existing migration drift warnings remain limited to previously known index-removal changes in listings and swapapp.

## Follow-ups / Deferred
- Add notification types for follows, sales, and other future marketplace events when those events gain durable backend records.
- Consider pagination for notification feeds beyond the current 100-item response limit.

## References
- `backend/modules/listings/models.py`
- `backend/modules/listings/views.py`
- `swappify-social-hub/src/pages/Notifications.tsx`
- `swappify-social-hub/src/server/Server.tsx`

---

**Completed By:** Copilot  
**Duration:** One implementation session
