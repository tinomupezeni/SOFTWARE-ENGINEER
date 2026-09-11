# Deployment Verification Patterns

**Date:** 2026-05-16
**Concept:** Strategies for ensuring a production deployment is healthy before or after it goes live.

## Pattern Comparison

| Pattern | Goal | Cost | Risk |
| :--- | :--- | :--- | :--- |
| **Staging** | Environment Parity | High (2x Infra) | "Works on Staging, fails on Prod" (DNS/SSL issues). |
| **Smoke Testing** | Immediate Vital Signs | Low | Bug is live for a few seconds before detection. |
| **Blue-Green** | Zero-Risk Switch | Medium | State/Database version conflicts. |

## The "False Positive" Trap (Senior Insight)
A common junior mistake is checking only for `HTTP 200`. A senior verification also checks:
1. **Asset Integrity:** Does the HTML point to CSS/JS files that actually exist? (Prevents 404s on styles).
2. **Environmental Leaks:** Does the JS bundle contain `localhost` or `127.0.0.1`?
3. **Dependency Health:** Can the API actually talk to the DB? (A "Deep Health Check").

## Application to Tese-Marketplace
We are starting with **Smoke Testing** (Solution 2) because it provides 80% of the value for 20% of the effort. We will harden it by checking for `localhost` strings in the delivered frontend bundle.

## Evolution Path
As Tese grows, we should move to **Blue-Green** to allow for "Private Validation" on the production server before flipping the Nginx switch.
