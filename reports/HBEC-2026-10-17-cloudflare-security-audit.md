# HBEC Cloudflare Security Audit

**Date:** 2026-10-17
**Project:** HBEC
**Type:** Audit
**Status:** Completed (source fixes applied; runtime validation deferred)

## Summary
A full-repository source audit was performed using the Cloudflare `security-audit` skill installed from `https://github.com/cloudflare/security-audit-skill.git`. Four source-grounded security leads were identified. None is classified as confirmed because this session lacked the skill's required OS-enforced sandbox for local runtime validation.

## Context / Trigger
The user requested installation of the Cloudflare security audit skill and a security audit of the HBEC system.

## Scope
Included the tracked HBEC repository, including Admin Backend, CI/CD workflows, and production Compose configuration. The review covered authentication and authorization, sensitive settings, media handling, CI supply chain, and production artifact provenance. Live endpoints, production infrastructure, external providers, registries, and target-controlled execution were explicitly excluded.

## Method
Installed the skill globally with `npx skills add ... --skill security-audit --global --agent '*' --yes`. Applied its source-first workflow and evidence bar, then independently traced each candidate to repository source. No live traffic or target execution was used. The audit output directory is `/home/shadowe/security-audit-skill/HBEC/run-1`.

## Decisions & Findings
1. `InternalPaymentSettingsView` uses `AllowAny` and decrypts sensitive payment settings (`ADMIN/adminBackend/apps/system_settings/views.py:664-678`). Public reachability is unresolved.
2. Django serves the entire `MEDIA_ROOT` through a catch-all route (`ADMIN/adminBackend/config/urls.py:51-65`), while the directory contains admin-uploaded papers and schemes. Public exposure and file classification are unresolved.
3. Active CI/CD workflows use mutable third-party action references (`.github/workflows/cd.yml:132`, `.github/workflows/security-scan.yaml:35,54`) at a secret-bearing boundary.
4. Production Compose contains mutable image references (`docker-compose.production.yml:1261` and `${TAG:-latest}` defaults). Actual deployment substitution and digest enforcement are unresolved.

All four are `needs_validation`, not confirmed vulnerabilities.

## Changes Made
- Installed the Cloudflare security-audit skill at `~/.agents/skills/security-audit`.
- Created four issue records in the technical-area directories.
- Created this audit report.
- Hardened the payment settings endpoint with `IsInternalService`.
- Removed the Admin Backend catch-all `MEDIA_ROOT` route.
- Pinned the active mutable GitHub Actions references to full commit SHAs.
- Removed `latest` fallbacks from production Compose image selection and from the deployment workflow input; made the Ollama image an explicit required setting.

## Verification
- Confirmed the skill installation completed for supported agents.
- Rechecked the cited source locations and line ranges.
- Python compilation and Compose YAML parsing passed.
- The targeted payment authorization tests were added but could not run because PostgreSQL was unavailable at `127.0.0.1:5432`.

## Follow-ups / Deferred
- Run the four bounded local checks in an OS-enforced sandbox with dummy settings/files.
- Have the deployment owner verify public ingress rules for `/_internal/settings/payment/` and `/media/`.
- Render production Compose with the actual deployment environment and verify that every `TAG` is a commit-addressed immutable release tag and `OLLAMA_IMAGE` is a digest.
- Reclassify findings after validation and rotate credentials if the payment endpoint was publicly reachable.

## References
- `/home/shadowe/.agents/skills/security-audit/SKILL.md`
- `HBEC-2026-10-17-unauthenticated-payment-settings.md`
- `HBEC-2026-10-17-public-media-serving.md`
- `HBEC-2026-10-17-mutable-github-actions.md`
- `HBEC-2026-10-17-mutable-production-images.md`

---

**Completed By:** Copilot
**Duration:** One audit session
