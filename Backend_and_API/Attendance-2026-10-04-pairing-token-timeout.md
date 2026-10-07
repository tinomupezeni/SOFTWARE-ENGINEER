# Issue Log

**Date:** 2026-10-04
**Project:** Attendance
**Area:** Backend_and_API

## Description
Flutter mobile clients were receiving a 400 Bad Request error when attempting to pair with the backend using a valid QR pairing code generated from the Laravel dashboard.

## Root Cause
The pairing tokens were hardcoded to expire in Redis after strictly 300 seconds (5 minutes). Because onboarding, deploying the mobile app, and scanning can take longer than 5 minutes in a realistic enterprise environment (e.g. IT sends an employee a pairing code, but they don't scan it immediately), the token was naturally expiring and locking the user out.

## Resolution
Modified the `POST /admin/devices/pairing-token` FastAPI route in `admin.py`. Increased the Redis `setex` TTL from 300 seconds to 86400 seconds (24 hours), ensuring pairing tokens remain valid long enough for practical distribution and scanning.

## Resolved By
Antigravity
