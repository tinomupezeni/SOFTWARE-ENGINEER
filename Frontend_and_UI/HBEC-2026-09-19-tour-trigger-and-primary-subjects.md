# Tour Trigger Prematurely Firing and Missing Primary Subject Auto-Selection

**Date:** 2026-09-19
**Project:** HBEC
**Area:** Frontend and UI

## Issue Description
1. **App Tour Premature Firing:** The `TourManager` was triggering on the `/subscription` page instead of waiting for the student to successfully land on their home dashboard (`/`). This caused the onboarding tour to run in the wrong context for first-time students who hadn't paid yet.
2. **Primary School Subject Burden:** Primary school students (who all take a standard 6 subjects) were being forced to manually click and select all 6 subjects during the onboarding/personalization wizard, which caused unnecessary friction.

## Root Cause
1. `TourManager.tsx` had an `eligible` check that only looked for `status === 'authenticated' && isOnboarded && hasCompletedTour !== true`, completely ignoring the current URL/route. Because the component mounts globally, it triggered on `/subscription` and tried to navigate them away prematurely.
2. `PersonalizationPage.tsx` did not interpret the selected `grade` value to apply any intelligent defaults when fetching the subsequent subject options.

## Resolution
- **TourManager Fix:** Added `location.pathname === '/'` to the `TourManager` trigger block so that the tour only kicks off once the user has successfully bypassed any gates and arrived at the dashboard.
- **Primary Subject Auto-Selection Fix:** Updated `PersonalizationPage.tsx` to inspect the selected grade code. If it identifies as a primary grade (e.g. contains `grade`, `ecd`, or `primary`), it automatically populates the `answers` state with all returned subject values, presenting them pre-checked to the student for confirmation.

**Resolved By:** Antigravity
