# TourManager Infinite Redirect Loop with SubscriptionGate

**Date:** 2026-09-19
**Project:** HBEC
**Area:** Frontend and UI

## Issue Description
Users without an active subscription were experiencing an infinite page refresh loop when landing on the `/subscription` page.

## Root Cause
A routing tug-of-war between two global components:
1. `TourManager.tsx` runs globally and mounts the onboarding tour when a user hasn't completed it. If they aren't on the tour's target route (the `/` dashboard), it eagerly calls `navigate('/')`.
2. `SubscriptionGate.tsx` wraps the `/` dashboard. When a user with an inactive subscription lands there, it instantly calls `navigate('/subscription')`.

This created a cycle: `TourManager` pushes to `/` -> `SubscriptionGate` pushes to `/subscription` -> `TourManager` pushes to `/`, forever.

## Resolution
Added `useSubscription` to `TourManager` and updated its `eligible` check to include `isActive`. The tour manager will now quietly wait until the user has actually paid or activated a trial before attempting to pull them onto the dashboard for the walkthrough.

**Resolved By:** Antigravity
