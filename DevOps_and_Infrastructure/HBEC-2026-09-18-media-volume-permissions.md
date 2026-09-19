---
title: Permission denied 500 errors on file uploads
date: 2026-09-18
tags: [docker, permissions, admin, media]
---

### Issue
Admins reported receiving a 500 Internal Server Error when attempting to upload content (exam papers and syllabus files). Upon checking the `hbec-admin-backend` logs, the API threw a `PermissionError: [Errno 13] Permission denied: '/app/media/exam_papers/papers/...'`.

This occurred because while `/app/media` itself was correctly owned by `appuser`, subdirectories inside the Docker volume such as `/app/media/exam_papers/papers` were owned by `root`. This frequently happens if Docker volumes are populated or manipulated by root processes (or earlier container versions that ran as root) before switching to an unprivileged `appuser`. 

### Resolution
- SSH'd into the VPS.
- Ran `docker exec -u root hbec-admin-backend chown -R appuser:appuser /app/media /app/staticfiles`.
- Replicated the fix on `hbec-student-backend` to ensure its media and static volumes are correctly owned recursively.
- File uploads now succeed.

**Resolved By**: Antigravity
