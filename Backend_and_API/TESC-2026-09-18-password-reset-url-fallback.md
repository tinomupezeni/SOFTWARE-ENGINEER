# Password Reset URL Fallback Issue

**Date:** 2026-09-18
**Project:** TESC
**Area:** Backend and API

## Description
The password reset functionality generates a reset link that defaults to `localhost:8081` if the `Origin` header is absent in the request and `FRONTEND_URL` is not set in the environment variables. The `.env` file on the deployment VM (`tesc-prod`) does not define `FRONTEND_URL`, meaning any request that drops the `Origin` header (e.g., privacy extensions, older browsers, or API testing tools) will result in a broken `localhost` link being sent to the user's email. 

Additionally, the frontend error handling in `ResetPassword.tsx` expects an `error` key in the 400 response (`error.response?.data?.error`), but the backend returns a `message` key (`{"message": "Invalid link..."}`). This causes a generic fallback error to be displayed instead of the precise backend reason.

## Root Cause
1. Missing `FRONTEND_URL` environment variable configuration in `tesc-prod`.
2. Mismatch between backend error response keys (`message`) and frontend expectation (`error`).
3. (Bonus finding) The `api.ts` clients in both frontends route to `:8000` when accessed via `10.50.X.X` IP, which fails because the docker-compose deployment does not expose port 8000 to the host (it routes through Nginx on port 80).

## Resolution
Pending implementation (instructed not to change anything yet).
Requires:
1. Adding `FRONTEND_URL` to the VM's `.env`.
2. Fixing `api.ts` port logic for IP addresses.
3. Updating `ResetPassword.tsx` to read `error.response?.data?.message` or changing the backend to return `error`.

**Resolved By:** Antigravity
