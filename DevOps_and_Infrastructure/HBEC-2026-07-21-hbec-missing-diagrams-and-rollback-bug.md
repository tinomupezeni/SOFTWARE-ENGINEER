# Incident Log: Missing Interactive Diagrams & Rollback Keys Deletion (2026-07-21)

## Issue 1: Missing Diagrams (API Key Omission)
**Symptom:** After successfully deploying the new interactive diagram plotting code (`experimental` -> `master`), the frontend still failed to generate diagrams for students.
**Root Cause:** The `GOOGLE_API_KEY` in the VPS `.env` file was completely blank (`""`). The `hbec-harness` relies on Gemini (the primary model tuned to output the specific `plot spec` for the `InteractivePlot` component) to generate interactive visuals. When it encountered `API key not valid`, the system intelligently fell back to the Groq `llama3.1-70b` model, which lacks the prompt-tuning needed to reliably output these visuals.
**Resolution:** Explicitly injected the valid `GOOGLE_API_KEY` into the VPS `.env` and restarted the `hbec-harness` container.
**Prevention / Rule:** **Guardrail:** a fail-fast startup check on the harness that validates every LLM provider key referenced by its model-routing config actually authenticates (a real, cheap test call) and crashes the container on boot if one doesn't — instead of silently routing around it to a weaker fallback model with no error anywhere.

## Issue 2: CD Pipeline Rollback Deleting JWT Keys
**Symptom:** Pushing to `master` caused the `hbec-student-backend` and `hbec-admin-backend` containers to crash again due to the `IsADirectoryError: [Errno 21] Is a directory: '/run/secrets/jwt_private.pem'` error. 
**Root Cause:**
1. In a prior pipeline failure, the `rollback-vps` job in `.github/workflows/cd.yml` successfully backed up `.env` and `docker/secrets/`, but **omitted** `docker/keys/`.
2. The job then executed `sudo rm -rf /opt/hbec/*`, which permanently deleted the un-backed-up `docker/keys/` directory on the host.
3. The rollback job ran `docker compose up -d`. Because the host file `jwt_private.pem` was missing, Docker Compose created an empty directory in its place.
4. During the next deployment, `deploy-vps` successfully extracted the codebase over the existing directories (leaving the empty `jwt_private.pem` directory intact), resulting in the same silent backend crash.
**Resolution:** 
1. Re-copied the JWT keys to the VPS manually via `scp`.
2. Patched `.github/workflows/cd.yml` to explicitly backup and restore `/opt/hbec/docker/keys` during rollbacks.
3. Added missing Langfuse environment variables to the `.env` generation script in `cd.yml` to prevent `LANGFUSE_DB_PASSWORD` crashes.
**Prevention / Rule:** **Guardrail:** drive the rollback job's backup step and the deploy job's restore step from one shared, single-source-of-truth path list (e.g. a checked-in `deploy_paths.txt`) instead of two independently maintained lists that can silently drift apart — and require the backup archive to be verified as containing every listed path before any `rm -rf` of the live directory is allowed to run.
