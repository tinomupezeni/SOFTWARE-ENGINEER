# Student Backend Curriculum Cache Invalidation Missing

**Date:** 2026-09-30
**Project:** HBEC
**Environment:** Production
**Severity:** Medium
**Status:** Investigating

## Summary
Topics and subjects created or modified in the Admin backend were successfully replicating to the Student backend database via Redis Streams, but were not appearing on the Student frontend. This was traced to the Student backend's aggressive caching of curriculum API endpoints (1-hour TTL, up to 6 hours during Exam Mode) without any cache invalidation triggers inside the Redis stream consumer.

## Symptoms
- A content creator added new topics for "Sociology" on the Admin side.
- The Admin replication dashboard showed no errors for the Redis stream.
- The topics were completely missing from the Student frontend.
- Direct database queries confirmed the topics *were* present and `is_active=True` in the Student PostgreSQL database.

## Environment Details
- **Server/Host:** hbca-vps
- **Services Affected:** `hbec-student-backend`, `hbec-student-worker`
- **Related Components:** `ContentStreamConsumer._handle_topic`, `apps.curriculum.views`
- **Time First Observed:** 2026-09-30

## Investigation Steps

### 1. Initial Diagnosis
Verified if the topics were actually missing from the Student database by querying the `Topic` count for Sociology across both Admin and Student databases. Both returned exactly 74 active topics. The replication mechanism itself was working flawlessly.

### 2. Root Cause Analysis
Searched the Student backend for caching logic and found that `curriculum/views.py` heavily relies on Redis caching for high-traffic endpoints:
```python
cache_key = f"curriculum:topics:{subject.id}:{release.id}:{flat}"
cache.set(cache_key, data, curriculum_cache_ttl())
```
The `curriculum_cache_ttl()` function returns 3600 seconds (1 hour). 
Reviewed the `ContentStreamConsumer` in `apps/replication/stream_consumer.py`. When a message like `topic_published` arrives, `_handle_topic` saves the data to the database but does not clear any cache keys. 

### 3. Key Findings
- The replication flow is completely decoupled from the API layer.
- Because the stream consumer runs in a Celery worker, it modifies the database directly behind the API's back.
- The API blindly serves the Redis cache until the TTL expires, creating a perception of replication failure.

## Root Cause
A cache invalidation gap. The `ContentStreamConsumer` processes curriculum updates and writes them to the database, but fails to bust the `curriculum:*` Redis cache keys. This leaves the API serving stale data for up to an hour.

## Prevention / Rule
**Guardrail:** Introduce a robust, event-driven cache invalidation strategy using Django signals.

Rather than manually busting cache keys inside the Redis stream consumer (which is brittle), attach `post_save` and `post_delete` signals to the `Subject`, `Topic`, and `ExamBoard` models in the Student backend. These signals should use Redis wildcard deletion (`redis.scan_iter(match="curriculum:*")`) to proactively clear the relevant namespace whenever the underlying curriculum data mutates.

## Solution

### Immediate Fix
Manually cleared the Redis cache on the VPS using the Django shell:
```python
from django.core.cache import cache
cache.clear()
```
The missing topics immediately appeared on the student side.

### Long-term Fix
Pending implementation of wildcard cache invalidation in `ContentStreamConsumer` or via Django signals on the student models.

## Prevention
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update
- [x] Code changes required

## Related Issues
- The user originally believed this was tied to the Agentic Harness `HTTP 500` error or a replication failure. This investigation proved the asynchronous stream was working, but the cache was masking the success.

---

**Resolved By:** Antigravity
**Time to Resolution:** 15 minutes
