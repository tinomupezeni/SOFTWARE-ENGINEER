# PRINCIPAL AUDIT: Shipwright Deployment Tool
**Date:** 2026-05-20
**Auditor:** Principal Engineer (Gemini CLI)
**Context:** Evaluation during recovery of Savens Blog infrastructure.

## 1. Executive Summary
Shipwright is a promising deployment orchestrator, but it currently lacks the **observability depth** and **contextual intelligence** required for world-class production stability. While it successfully handles basic transport and orchestration, it fails to provide high-signal feedback when complex network tiers (like SSL-terminating reverse proxies) are involved.

## 2. Identified Weaknesses (Critical Engineering Signals)

### A. Health Check "Blindness"
- **Issue**: Shipwright reported a failed health check at `http://159.198.42.231/health/` because it encountered a `308 Permanent Redirect`.
- **Principal Verdict**: A redirect to HTTPS is a **Success Signal** for an infrastructure layer. Shipwright's inability to follow redirects or recognize 30x codes as "Healthy" in an SSL-first world is a major friction point.
- **Impact**: Blocked CI/CD pipelines and false "Failure" alerts for correctly functioning systems.

### B. Mismatched Observability (Docker API vs. Logic)
- **Issue**: Shipwright reported "Healthy: 0 / Unhealthy: 0" while containers were clearly running and the backend was marked "healthy" by Docker's internal health check.
- **Principal Verdict**: Shipwright is not effectively surfacing the **Docker Daemon State**. If a container has an internal `HEALTHCHECK` defined in its Dockerfile, Shipwright should prioritize that signal over its own external HTTP probe.

### C. File Transport UX (Password Fatigue)
- **Issue**: Shipwright prompts for the VPS password multiple times (Structure, SCP, Pull, Start, Verify).
- **Principal Verdict**: This breaks the "Flow State" of a Principal Engineer. 
- **Impact**: It feels like a collection of scripts rather than a unified tool.

## 3. Mandatory Improvements for World-Class Impact

### 1. The "Protocol-Aware" Health Prober
- **Feature**: Shipwright must support `-L / --location` logic. 
- **User Message Update**:
  - *Current*: `○ UNHEALTHY: Connection failed: error sending request for url`
  - *Proposed*: `○ REDIRECTED: Received 308 (HTTPS Required). Following to https://...` or `✅ SECURE: Redirected to HTTPS (Valid signal)`.

### 2. Multi-Signal Verification (The "Trust but Verify" Pattern)
- **Feature**: Implement a 2-stage verification:
  - **Stage 1**: Check `docker inspect` for `State.Health.Status == "healthy"`.
  - **Stage 2**: Perform the external HTTP probe.
- **Benefit**: If Stage 1 passes but Stage 2 fails, the tool can accurately report: *"Container is internally healthy, but the external endpoint is unreachable (check your firewall/proxy routing)."*

### 3. SSH Connection Multiplexing
- **Feature**: Use a single persistent SSH session or `ControlMaster` to handle all phases of the deployment.
- **Benefit**: Zero password fatigue and significantly faster execution.

### 4. Semantic Dry-Runs
- **Feature**: The dry-run should perform a "Network Pre-flight".
- **Action**: Check if the target port is open and if the existing proxy (Caddy/Nginx) is responding.

## 4. Final Verdict
Shipwright is **80% of the way to being the ultimate tool**. The remaining 20% lies in **Contextual Empathy**—understanding that production environments are not just containers, but a delicate balance of networking, security headers, and hardware instruction sets.
