---
title: Admin Backend missing LITELLM and PROMETHEUS env vars in production/staging compose
date: 2026-09-13
author: Antigravity
status: Resolved
---

# Issue summary
The `hbec-admin-backend` (and its workers/beat containers) were missing `LITELLM_MASTER_KEY`, `LITELLM_URL`, and `PROMETHEUS_URL` in both `docker-compose.production.yml` and `docker-compose.staging.yml`.

# Impact
The Admin Backend's `Model Settings` page could not sync model adapters from LiteLLM or pull usage metrics from Prometheus. Background tasks `sync_config_file_adapters` and `sync_model_usage_metrics` were silently failing with `Could not reach LiteLLM proxy... Illegal header value b'Bearer '` due to missing credentials and incorrect default URLs. This caused the admin dashboard to remain empty or stale, leaving the team unaware of model statuses and API key expiration metrics.

# Resolution
Updated the `environment` section for `admin-backend`, `admin-worker`, and `admin-beat` in both `/opt/hbec/docker-compose.production.yml` and `/home/winstontino/HBEC/docker-compose.staging.yml` (on `hbca-vps`) to properly pass down `${LITELLM_MASTER_KEY:?err}`, `LITELLM_URL=http://litellm:4000`, and `PROMETHEUS_URL=http://prometheus:9090`. Recreated the containers on production and successfully ran the sync tasks to populate the DB.

Resolved By: Antigravity
