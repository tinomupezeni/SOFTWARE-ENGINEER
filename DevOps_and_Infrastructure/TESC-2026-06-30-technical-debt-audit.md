# Technical Debt & Security Audit

**Date:** 2026-06-30
**Project:** TESC
**Environment:** Development & Production
**Severity:** High
**Status:** Workaround Applied

## Summary
A deep-dive review into the TESC codebase and production environment revealed severe technical debts, security vulnerabilities (data leakage via committed secrets and DB dumps), and a lack of standardized testing frameworks. The codebase needs a structured cleanup sprint to ensure maintainability and security.

## Symptoms
- Git repository is bloated with massive `.sql` database dumps.
- `.env` files containing secrets are tracked in version control.
- Over 40 standalone `smoke_test_*.py` files cluttering the project root.
- Ad-hoc scripts are being used instead of formal Django management commands.
- Local development environment uses SQLite, while production uses PostgreSQL.

## Environment Details
- **Server/Host:** `user@10.50.200.35`
- **Services Affected:** Source Control, Backend Framework, Deployment Workflow
- **Related Components:** Django Backend, Git Repository, Testing Pipeline

## Investigation Steps

### 1. Initial Diagnosis
- Investigated the local Git repository structure using directory listings and file checks.
- SSH'd into the production server (`10.50.200.35`) to inspect the live Docker environment.

### 2. Root Cause Analysis
- Ran `git ls-files` to identify tracked secrets and backup files.
- Evaluated `docker ps` on the remote server to verify the database engine used in production (`postgres:15`).
- Compared local `db.sqlite3` usage against the production configuration.

```bash
# Commands used for investigation
git ls-files | grep '\.env\|sql\|backup'
ssh -o BatchMode=yes user@10.50.200.35 "docker ps"
```

### 3. Key Findings
- **Committed Secrets:** `backend/.env` is tracked in git.
- **Data Leakage Risk:** Sensitive student data backups (`tesc_db_backup_*.sql`, `full_data_backup.sql`) are committed to the repo.
- **Testing Debt:** No formal test suite (e.g., `pytest`). Instead, testing relies on dozens of manual "smoke test" scripts.
- **Environment Discrepancy:** Local development is done on SQLite, but production runs Postgres, increasing the risk of environment-specific bugs.
- **Script Clutter:** Administrative tasks are handled by floating `.py` files instead of organized Django Management Commands.
- **Infrastructure Debt:** Production containers map directly to host ports (`8000`, `8080`, `8081`) without a proper reverse proxy (NGINX/Traefik) handling SSL offloading at the host level.

Repository-side controls have since removed local environment files from the
Git index, added CI rejection for tracked environment/SQL dump files, added
institution frontend tests to CI, and added a validated Compose database
backup helper. Historical Git secrets still require rotation and history
scrubbing, while VM-level HTTPS and off-host backup scheduling remain open.

## Root Cause
Fast-paced initial development prioritized "making it work" over long-term maintainability, security hardening, and structural best practices. 

## Solution

### Immediate Fix
1. Removed `.env` files from the repository index while preserving local
   runtime files.
2. Added a CI guard that rejects tracked environment and SQL dump files.
3. Added a service-name-based database backup helper with archive validation.
4. Added institution frontend test/build gates to CI.

### Long-term Fix
1. Establish a standard `tests/` directory and adopt `pytest` for all future testing.
2. Port ad-hoc scripts into `backend/<app>/management/commands/`.
3. Update local development setup to use Docker Compose with `postgres:15` to mirror production.
4. Implement a reverse proxy on the host machine for SSL termination and unified routing.

## Prevention
- [x] Add `*.env` and `*.sql` to `.gitignore`.
- [x] Add CI enforcement to prevent committing environment and SQL dump files.
- [x] Add institution frontend tests to the CI quality gate.
- [ ] Rotate exposed credentials and scrub historical Git objects.
- [ ] Schedule off-host database backups and perform a restore drill.
- [ ] Document testing standards to prevent further proliferation of root-level smoke tests.

## Related Issues
- N/A

## References
- Git Filter-Repo documentation for scrubbing history.
- Django Testing documentation.
- Django Management Commands documentation.

---

**Resolved By:** Copilot
**Time to Resolution:** Ongoing; repository controls applied, VM/security follow-ups remain

## Current Verification

- `git ls-files` no longer includes `.env`, `backend/.env`, or SQL dumps.
- `bash -n scripts/backup_database.sh` passes.
- Institution frontend CI coverage now runs 39 tests and a production build.
- The production Compose definition includes PostgreSQL, Redis, and nginx.

## Remaining Actions

- Rotate credentials that appeared in historical repository objects.
- Use `git filter-repo` only after a coordinated force-push/clone-impact plan.
- Configure certificate-backed HTTPS and off-host backup retention on the VM.
