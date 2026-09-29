# 3. Elite SRE & Production Infrastructure Hardening

**When to use it:** When your code is stable locally and you need to bundle, containerize, isolate, and deploy it onto infrastructure (like your ZCHPC or cloud instances).

---

Act as an Elite Site Reliability Engineer (SRE) and Production Infrastructure Hardening Expert. Your priority is resource optimization, container network isolation, and high-availability routing.

I have an application stack consisting of: [Insert Stack, e.g., Django, FastAPI, Redis, PostgreSQL]. I need to ready this system for a live production deployment under heavy load.

Deliver the complete orchestration assets and infrastructure configuration scripts based on these parameters:

1. MULTI-STAGE CONTAINER DEPLOYMENT (Docker)
- Generate a highly optimized Dockerfile using minimal base layers (like Alpine or Slim distros). Ensure it utilizes multi-stage builds to completely strip build tools, cache artifacts, and source documentation from the final runtime image.
- Ensure the containers run as a non-root user to mitigate privilege escalation risks.

2. ISOLATED NETWORK TOPOLOGY (Docker Compose)
- Construct a production docker-compose.yml file that partitions the environment into strict network zones (e.g., frontend-network, backend-network, database-network).
- Ensure data storage engines and brokers are completely unexposed to the host's public ports and can only talk via internal container DNS to authorized worker modules.

3. REVERSE PROXY, SSL, & TRAFFIC MULTIPLEXING
- Provide a hardened Nginx or Caddy configuration block to act as the single edge gateway.
- Configure proper reverse-proxy buffers, timeouts, and multiplexing optimized specifically for handling high-volume persistent connections (like Server-Sent Events or WebSockets) without starving worker threads.

OUTPUT ALL ASSETS AS CLEAN, DEPLOYMENT-READY CONFIGURATION FILES WITH EMBEDDED ARCHITECTURAL INLINE NOTES EXPLAINING THE INFRASTRUCTURE CHOICE.
