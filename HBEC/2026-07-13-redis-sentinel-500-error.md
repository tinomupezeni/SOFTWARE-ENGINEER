# Login API 500 Error — Redis Sentinel Connection Factory Missing

**Date:** 2026-07-13
**Project:** HBEC Student Platform
**Environment:** Production (VPS)
**Severity:** High
**Status:** Resolved

## Summary
After applying the Redis Sentinel fix (see `2026-07-10-redis-sentinel-failover-readonly-error.md`), the `student-backend` began throwing `500 Internal Server Error` on the `/api/auth/login/` endpoint. The root cause was an incomplete `django-redis` configuration for Sentinel.

## Symptoms
- `POST https://student.hbca.tech/api/auth/login/` returned 500.
- `django.core.exceptions.ImproperlyConfigured: Settings DJANGO_REDIS_CONNECTION_FACTORY or CACHE[].OPTIONS.CONNECTION_POOL_CLASS is not configured correctly.` was logged in the `hbec-student-backend` container.
- `TypeError: SentinelConnectionPool.__init__() missing 2 required positional arguments: 'service_name' and 'sentinel_manager'` when trying to manually set `CONNECTION_POOL_CLASS`.

## Root Cause
When configuring `django_redis.client.SentinelClient`, the default connection factory (`django_redis.pool.ConnectionFactory`) does not know how to handle Sentinel connection pools. It requires `django_redis.pool.SentinelConnectionFactory` to properly instantiate the connection pool with `service_name` and `sentinel_manager`.

## Solutions Implemented

### Config Fix
Added `CONNECTION_FACTORY` to the Sentinel options block in `config/settings/production.py`.

```python
CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": f"redis://{_sentinel_service}/0",
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.SentinelClient",
            "SENTINELS": _sentinels,
            "SENTINEL_SERVICE_NAME": _sentinel_service,
            # Added this line:
            "CONNECTION_FACTORY": "django_redis.pool.SentinelConnectionFactory",
        },
    }
}
```

This fix was applied directly to the running `hbec-student-backend` container on the VPS via `sed` and the container was restarted. It was also patched in the local codebase `config/settings/production.py` to prevent regression on the next deployment.

---

**Resolved By:** Antigravity Agent
**Time to Resolution:** ~5 minutes
