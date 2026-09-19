# Docker Keys Permissions Drift Causing 502 Bad Gateway

**Date:** 2026-09-19
**Project:** HBEC
**Area:** DevOps and Infrastructure

## Issue Description
The `student-backend-staging` container entered a crash loop, returning `502 Bad Gateway` and `504 Gateway Timeout` to all requests. The container logs showed a `PermissionError: [Errno 13] Permission denied: '/run/secrets/jwt_private.pem'` during the Django boot sequence.

## Root Cause
- Earlier in the session, a `sudo chown -R $USER:$USER /opt/hbec` command was run on the host VPS to fix a broken Git repository ownership issue (where `root` owned everything).
- This recursively changed the ownership of the JWT keys in `/opt/hbec/docker/keys/` to the SSH user (`winstontino`). The file permissions were `600` (read/write only for owner).
- Because `student-backend-staging` runs internally as the non-root `appuser` (uid 1000) instead of `root`, it could no longer read the bind-mounted key file, causing Django to immediately crash on startup when attempting to load the JWT configuration.

## Resolution
- Ran `chmod 644 /opt/hbec/docker/keys/*.pem` on the VPS to make the keys world-readable on the host. Since they are bind-mounted read-only into the containers, this safely grants read access to any internal non-root user (e.g., `appuser`) without compromising the container boundary.
- Restarted `hbec-student-backend-staging`, which successfully booted and resumed serving traffic.

**Resolved By:** Antigravity
