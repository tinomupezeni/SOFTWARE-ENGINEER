# Student Backend & Harness 502 — Docker Network Mismatch

**Date:** 2026-07-13
**Project:** HBEC Student Platform
**Environment:** Production (VPS)
**Severity:** High
**Status:** Resolved

## Summary
Similar to the admin backend issue on 2026-07-10, the student backend and harness containers were recreated and placed on the wrong Docker network (`hbec_hbec-network` instead of `hbec_app-net`). This caused the Nginx reverse proxy inside `student-frontend` to fail DNS resolution for `student-backend` and `harness`, resulting in 502 Bad Gateway errors for all `/api/` and `/harness-stream/` requests.

## Symptoms
- "No subjects added yet" message on Exam Practice Papers (due to `/api/curriculum/subjects/` failing).
- "I'm sorry, I encountered an error. Please try again." on Friday Learning Assistant (due to `/harness-stream/api/v1/friday/chat/stream` failing).
- Nginx error logs on `student-frontend` showing `student-backend could not be resolved (2: Server failure)` and `harness could not be resolved (2: Server failure)`.

## Environment Details
- **Server/Host:** VPS (hbec-vps)
- **Services Affected:** `student-frontend` → `student-backend` API & `harness` API
- **Related Components:** student-frontend Nginx, Docker networks

## Root Cause
When the containers were restarted (likely during the recent Redis/PgBouncer fixes), `student-backend` and `harness` were only attached to `hbec_hbec-network`. The `student-frontend` was on `hbec_app-net`. Because they were not on a shared network, Docker DNS failed to resolve the hostnames.

## Prevention / Rule
**Guardrail:** the same automated post-recreate network-membership check named in the 2026-07-10 admin-backend incident (compare every service's actual attached networks against the production compose file, fail the deploy on mismatch) — but run against **every** service in the compose file on every restart, not just whichever one broke last.

This is the identical defect recurring on a sibling service three days after the first occurrence — proof that fixing it once, for one service, isn't enough; the check has to cover the whole compose file from the start.

## Solutions Implemented

### Immediate Fix
Connected the `student-backend` and `harness` containers to the correct `hbec_app-net` network with proper DNS aliases so the `student-frontend` Nginx can route requests to them.

```bash
# Connect student-backend
docker network connect --alias student-backend hbec_app-net hbec-student-backend

# Connect harness
docker network connect --alias harness hbec_app-net hbec-harness
```

## Prevention
- Investigate why `docker compose up -d` is not merging network configurations correctly between dev and production compose files.
- Consider moving all services to a single unified compose file or pinning network definitions explicitly.

---

**Resolved By:** Antigravity Agent
**Time to Resolution:** ~15 minutes
