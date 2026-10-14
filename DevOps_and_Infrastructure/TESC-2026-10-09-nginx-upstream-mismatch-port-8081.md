# Bug Report: Nginx Upstream Proxy Routing to Dead Legacy Container
**Project:** TESC
**Date:** 2026-10-09
**Description:** The external upstream proxy (e.g. pfSense) was directing traffic for `tesc-staging.zchpc.ac.zw` to port `8081`. The new unified Nginx container was bound to `80`, while the legacy container (`tesc-frontend-client-v2-1`) was still holding `8081` hostage and proxying to a dead internal backend IP, causing 502 Bad Gateway errors.
**Resolution:** Stopped the legacy containers. Mapped `8081:80` and `8082:80` on the unified Nginx container in `docker-compose.prod.yml`. Added `tesc-staging.zchpc.ac.zw` to `nginx.conf` server_name block to enable host-based routing.
**Resolved By:** Antigravity
