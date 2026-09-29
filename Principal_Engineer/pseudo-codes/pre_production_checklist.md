# Pre-Production LLM Deployment Checklist

When you are pair-programming with LLMs (Claude Code, AGY, OpenCode), they will often write fast, highly functional code, but they frequently skip infrastructure, defensive, and production-parity checks. 

Run this checklist **before** every deployment to production.

## 1. Dependency Check
* [ ] Did the LLM tell me to `pip install` or `npm install` something?
* [ ] Is that new dependency hardcoded with a specific version in `requirements.txt` or `package.json`? (If not, the production build might pull a breaking version tomorrow).

## 2. Database & Data Integrity Check
* [ ] Did the LLM change an existing database model/schema?
* [ ] Has the Alembic/Django migration file been generated?
* [ ] **CRITICAL:** Did the LLM write a data migration script to move existing production data into the new columns/tables? (Never deploy an empty table that replaces an old one without porting data).

## 3. Configuration & Secrets Check
* [ ] Did the LLM hardcode any API keys or connection strings in the code?
* [ ] Are all new configuration variables added to `.env.example`?
* [ ] Have I updated the actual production `.env` file on the VPS with the new required keys?

## 4. Local "Prod-Parity" Check
* [ ] Have I run `docker compose -f docker-compose.prod.yml build` locally to verify the production Dockerfile doesn't crash?
* [ ] Does the new service have a `HEALTHCHECK` command defined in its `Dockerfile`?

## 5. Defensive State & Cache Check
* [ ] If the LLM wrote frontend code that uses `localStorage` or `sessionStorage`, did I explicitly ask it: *"Write logic to validate this cache against the backend and clear it if it's stale"*?
* [ ] If the LLM wrote a webhook handler, did I explicitly ask it: *"Make this webhook idempotent so it doesn't duplicate data if it receives the same payload twice"*?

## 6. Infrastructure Drift Check
* [ ] Did we add a new Docker container? 
* [ ] Is it explicitly attached to the correct unified `network` in `docker-compose.yml`?
* [ ] Does it have log size limits configured?
* [ ] If it requires files from the host machine (like uploaded APKs or images), are the `volumes` mapped correctly with appropriate read/write permissions?

---
*Pro-tip: You can paste this entire checklist directly into your LLM prompt before asking it to prepare a commit, ensuring it audits its own work against these standards.*
