# Technical Debt & Security Audit

**Date:** 2026-06-30
**Project:** TESC
**Environment:** Development & Production
**Severity:** High
**Status:** Investigating

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

## Root Cause
Fast-paced initial development prioritized "making it work" over long-term maintainability, security hardening, and structural best practices. 

## Solution

### Immediate Fix
*(Pending execution)*
Need to run a Tech Debt sprint.
1. Remove `.env` and `.sql` files from git history using `git filter-repo` to eliminate the security risk.

### Long-term Fix
1. Establish a standard `tests/` directory and adopt `pytest` for all future testing.
2. Port ad-hoc scripts into `backend/<app>/management/commands/`.
3. Update local development setup to use Docker Compose with `postgres:15` to mirror production.
4. Implement a reverse proxy on the host machine for SSL termination and unified routing.

## Prevention
- [ ] Add `*.env` and `*.sql` to `.gitignore`.
- [ ] Implement pre-commit hooks to prevent committing secrets or large dumps.
- [ ] Document testing standards to prevent further proliferation of root-level smoke tests.

## Related Issues
- N/A

## References
- Git Filter-Repo documentation for scrubbing history.
- Django Testing documentation.
- Django Management Commands documentation.

---

**Resolved By:** Antigravity AI
**Time to Resolution:** Ongoing
