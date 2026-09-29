Code Integration, Pull Request Review & Merge Engineering Handbook

## Metadata

```yaml
id: 15
title: Code Integration, PR Review & Merge Engineering
scope: >-
  End-to-end code integration lifecycle for small teams: git branching
  strategy, pull request standards, code review, CI/CD quality gates,
  database migration safety, API versioning, configuration/secrets/feature
  flag rollout, and release/rollback procedures — including how to review
  contributions from AI coding agents.
stack:
  - git
  - github-actions
  - postgresql
  - docker
  - coolify
triggers:
  - "Project uses git with a pull request-based workflow"
  - "Project has a CI/CD pipeline gating merges to the trunk branch"
  - "Project runs database migrations against PostgreSQL in production"
  - "Project integrates AI coding agents (e.g. Claude Code) into the review/merge workflow"
applies_to:
  - project: TESE-MARKET (BFF)
    fit: high
    notes: "FastAPI + Postgres + Docker stack matches the guide's migration-timeout and CI/CD examples directly. Not yet reviewed against this project directly."
  - project: HBEC
    fit: high
    notes: "Stack matches (Django, FastAPI, Postgres, Docker, GitHub Actions), but per HBEC's own CLAUDE.md most CI workflows are disabled — only a Gitleaks secret scan and a VPS deploy job run, with no automated lint/test/coverage gate. The guide's core thesis (automated quality gates blocking merge) is aspirational here, not yet adopted."
  - project: shipwright
    fit: medium
    notes: "Rust CLI tool; the guide's PR-size, branching, and release-integration guidance is language-agnostic, but its worked examples (Django/FastAPI/Laravel, Postgres locking) don't map directly. Not yet reviewed against this project directly."
  - project: TESC
    fit: high
    notes: "Django + Postgres 15 + GitHub Actions self-hosted runner already in place (per MANIFEST guides 6/8/10), which overlaps with this guide's CI and migration-safety sections. Not yet reviewed against this project directly for PR/merge process specifically."
  - project: SMEPulse
    fit: medium
    notes: "Next.js/Prisma + Postgres with CI-gated tests for apps/webhook already established (per MANIFEST guide 8), but no Postgres migration-locking or PR/branching review yet against this guide. Not yet reviewed against this project directly."
rewire_notes: >-
  Worked examples are GitHub Actions + Coolify + PostgreSQL-specific (Django,
  FastAPI/Alembic, and Laravel timeout snippets); swap for the project's
  actual pipeline/host (e.g. a different CI runner, Traefik/nginx instead of
  Coolify) while keeping the gate ordering (lint -> test -> build -> deploy)
  and the lock_timeout/statement_timeout migration guidance, which is
  host-agnostic.
```

---


How to Use This Handbook
This handbook defines the engineering standard for managing, reviewing, and integrating source code changes within modern software engineering teams. It is structured as an authoritative reference and an enforceable protocol that governs the transition of code from local development environments into shared production systems.   

In modern software engineering, code integration is not merely an administrative task of executing version control commands or updating tracking boards. It is a critical engineering boundary. Code integration serves as the junction where isolated feature development connects with continuous integration, automated testing, security scanning, and automated deployment pipelines.   

┌────────────────────────────────────────────────────────────────────────┐
│                      Software Development Life Cycle                   │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [Feature Branch] ──► [Continuous Integration]                        │
│                                │                                       │
│                                ▼                                       │
│                        [Code Review Gate]                              │
│                                │                                       │
│                                ▼                                       │
│                        [Merge Queue Stage]                             │
│                                │                                       │
│                                ▼                                       │
│                        [Staging Isolation]                             │
│                                │                                       │
│                                ▼                                       │
│                        [Production Delivery]                           │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
The standard established in this handbook balances velocity and safety for teams of 1 to 10 developers. This scale of engineering requires low-friction, highly automated workflows. Because these environments typically lack dedicated release or build engineers, production safety must be maintained using automated guardrails, strict pull request reviews, and deterministic merge strategies.   

This handbook also defines the standards for integrating AI coding agents (such as Claude Code, Gemini CLI, and automated review suites) into the engineering pipeline. It treats these agents as autonomous contributors that must adhere to the same quality gates and validation protocols as human engineers. By formalizing these standards, the team ensures that both human developers and AI agents can collaborate without introducing architectural drift, security vulnerabilities, or logical regressions.   

1. Git Workflow Strategy
The branching strategy used by an engineering organization establishes the structure for how code is integrated, verified, and released. Selecting a strategy requires balancing feature isolation against the integration overhead of long-lived branches.   

Branching Strategies
┌────────────────────────────────────────────────────────────────────────┐
│                        GitHub Flow Branching                           │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  main:   ────────────────────────────────────────────────────────────► │
│               \                                         /              │
│  feature:      └───[Commit]───[Commit]───[PR Review]───┘               │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────────────┐
│                       Trunk-Based Development                          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  main:   ───[Commit]───[Commit]───[PR]───[Commit]───[Commit]─────────► │
│                 \                  /                                   │
│  short-lived:    └───[1-2 Commits]┘                                    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
Strategy Attribute	
GitHub Flow

Git Flow

Trunk-Based Development

Branch Longevity	Short-lived (1 to 3 days)	Long-lived (weeks to months)	Short-lived (hours to <24 hours)
Primary Trunk	main	master and develop	main
Release Mechanism	Direct from branch or main	Dedicated release branches	Automated tags from main
Verification Gate	Pull request review	Staging environment tests	Pre-merge CI pipelines
Integration Overhead	Low to moderate	High (frequent merge conflicts)	Minimal (continuous alignment)
Ideal Team Size	1 to 5 developers	Larger enterprise teams	1 to 10+ developers and AI agents
  
The Integration Tax of Long-Lived Branches
When branch lifespans extend beyond a single day, the cost of eventually merging them into the trunk branch compounds non-linearly. This friction is characterized by several key patterns:   

1. Contextual and Architectural Drift
As a feature branch remains isolated, other developers merge changes into the trunk. This creates a widening gap between the codebase of the isolated branch and the current state of the main application. The rate of context drift D can be modeled as:   

D=r⋅t 
2
 
where r represents the rate of modifications on the main branch, and t represents the time the feature branch remains unintegrated.

2. Diff Noise and Review Exhaustion
When a branch diverges significantly, the eventual pull request diff becomes large and difficult to review. Reviewers must parse hundreds of modified lines, many of which may be conflicts or formatting adjustments rather than the core change, leading to superficial approvals.   

3. Late-Stage Design Incompatibilities
Two parallel feature branches may compile and pass automated tests in isolation, but fail when merged together. This occurs because the systems were developed under conflicting assumptions about the state of shared modules or database schemas, delaying the discovery of critical bugs.   

4. Release Stabilization Bottlenecks
Long-lived branching models often require dedicated "release" branches to isolate and stabilize code before a deployment. This stabilization period frequently involves manual testing and cherry-picking fixes, which slows down the delivery pipeline and diverts engineering time from feature development.   

Workflow Recommendations for Solo Developers and Small Teams (1-10 Devs)
For solo developers and small teams, the recommended strategy is Scaled Trunk-Based Development. This workflow requires all developers and AI agents to integrate their changes into the main branch multiple times per day.   

To maintain stability on the main branch without a dedicated release team, the strategy utilizes short-lived feature branches (with a maximum lifespan of 24 hours) that are integrated via pull requests. These pull requests act as structured proposals and are verified by automated continuous integration (CI) suites before merging.   

┌────────────────────────────────────────────────────────────────────────┐
│                        Scaled Trunk-Based Workflow                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  1. Create Short-Lived Branch (e.g., `feat/usr-101-auth-logic`)        │
│  2. Commit Incremental, Tested Changes Locally                         │
│  3. Push Branch to Origin & Create Pull Request                        │
│  4. Run CI Pipeline (Linting, Unit Tests, Static Security Scanning)   │
│  5. Review Code (Required peer review or AI checklist validation)     │
│  6. Merge and Squash into Main Branch                                  │
│  7. Automated Staging Deployment and Post-Merge Smoke Tests            │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
Monorepo vs. Multi-Repository Workflows
When managing monorepos (e.g., combining a Django API, React frontend, and infrastructure configuration in a single repository), the team must configure path-based triggers in their CI pipelines to prevent running unnecessary tests. For example, modifications inside frontend/ must not trigger the integration test suite for backend/.   

In multi-repository setups, dependent changes must be integrated in a specific order: first publish backward-compatible updates to the dependency or API repository, and then update the consuming application's branch.   

2. Branch Management
To maintain a clean repository and ensure automated integration pipelines run efficiently, teams must adhere to a standardized branch lifecycle.

Branch Classifications and Naming Standards
All branches must be prefixed with a standard category identifier. This prefix is used by automated CI systems to determine which pipeline stages to run.   

Branch Category	Naming Pattern	Operational Objective
Feature	feat/[ticket-id]-[slug]	
New functional capabilities or enhancements (e.g., feat/usr-412-oauth-api).

Bugfix	fix/[ticket-id]-[slug]	
Defect remediation and bug fixes (e.g., fix/bug-908-stripe-token-error).

Release	release/v[semver]	
Short-lived stabilization branches for formal version tagging.

Hotfix	hotfix/[ticket-id]-[slug]	
Critical production fixes branched directly from main.

Refactor	refactor/[slug]	
Code restructuring without behavioral modifications.

Infrastructure	infra/[slug]	
Updates to Docker configurations or CI pipeline definitions.

  
Ownership & Collaborative Modalities
A branch must have a single assigned owner—either a developer or an AI agent identifier. Multiple authors must not push commits to the same branch simultaneously to prevent race conditions during integration.   

If collaboration is required on a complex feature, developers should break the work down into smaller sub-tasks. Each sub-task can then be developed on its own short-lived branch and merged into main behind a feature flag.   

Synchronization Policies
Feature branches must be updated daily with the current state of the main branch. This synchronization must be performed using git rebase rather than merge commits to keep the repository history clean and linear.   

Bash
# Synchronize local branch with the main branch safely
git fetch origin
git checkout feat/usr-412-oauth-api
git rebase origin/main
Automatic Branch Cleanup
To prevent stale branches from accumulating in the repository, the integration pipeline must automate branch deletion. GitHub repositories must be configured to automatically delete feature branches once their pull request is merged.   

Branch Protection Rules
The main branch must be strictly protected on GitHub to prevent accidental updates and force all changes through the review process. The repository settings must enforce:

Require a Pull Request: Direct pushes to the main branch are disabled.

Require Approvals: At least one peer approval is required before a merge.   

Require Status Checks: Mandatory CI pipeline checks, linting, and security scans must pass successfully.   

Require Linear History: Merges must be performed using squash merges or fast-forward rebase strategies.   

3. Pull Request Standards
A pull request (PR) is not simply a repository dump of code modifications; it is a formal engineering proposal. It must present a clear, logical, and self-contained change that is easy for the team to review and integrate.   

Pull Request Scope and Size Limits
To ensure thorough and effective code reviews, the scope of a pull request must remain small.   

The Rule of 200: A pull request must not exceed 200 lines of modified, added, or deleted code, excluding auto-generated files (such as database schema lockfiles, translation blocks, or dependencies).   

Single Logical Concern: A pull request must address a single functional goal. Mixing features, refactoring, and dependency upgrades in a single PR is prohibited.   

Commit Quality and Organization
Commits within a pull request should represent logical steps in the development of the feature. Each commit must compile cleanly and pass tests on its own to keep the repository history readable and easy to debug.   

Commit messages must follow the Conventional Commits specification:

[Category]([Scope]):[Imperative Verb Description]
Allowed categories include feat, fix, docs, style, refactor, perf, test, build, ci, and chore.

Essential Pull Request Metadata
Every pull request must contain structured documentation that covers:

The Problem: A description of the current issue, bug, or limitation being addressed.

The Solution: A technical overview of the implementation and the design decisions made.

The Risks: An evaluation of the potential impact on performance, security, and integration stability.

Database Impact: Detailed notes on any schema changes or migration requirements.   

Rollback Strategy: Clear, actionable instructions for reverting the changes if a production issue occurs.   

Validation Proof: Evidence that the changes are correct and functional, such as output logs, automated test results, or UI screenshots.   

4. Code Review Engineering
Code reviews are a systematic engineering gate designed to preserve and improve the health of the codebase. Reviewers must evaluate changes against the team's established design, quality, and performance standards.   

Google's Standard of Code Health
Reviewers should evaluate pull requests based on whether the changes improve the overall health of the codebase, even if the implementation is not perfect. There is no single "perfect" solution; instead, the focus is on continuously improving system quality and consistency. Reviewers must reject solutions designed for speculative future requirements.   

The Twelve Review Priority Vectors
Reviewers must evaluate code changes across twelve core vectors, ordered from highest priority to lowest:   

┌────────────────────────────────────────────────────────┐
│                 Code Review Priority Vector            │
├────────────────────────────────────────────────────────┤
│ 1. System Design and Component Architecture            │
│ 2. Functional Correctness and Logic Quality            │
│ 3. Automated Test Coverage and Reliability             │
│ 4. Non-Functional Requirements (Latency, Memory)        │
│ 5. Security Safeguards and OWASP Compliance           │
│ 6. Observability Integration (Structured Logs, Traces) │
│ 7. API and Database Compatibility Patterns             │
│ 8. Code Maintainability and Cognitive Complexity        │
│ 9. Variable, Function, and Class Naming Context       │
│ 10. Commentary Quality (Why, Not What)                 │
│ 11. Code Consistency and Styling Guidelines           │
│ 12. Documentation Accuracy and Completeness            │
└────────────────────────────────────────────────────────┘
1. System Design and Component Architecture
Assess whether the changes align with the project's overall architecture. Verify that component boundaries are respected and that the changes do not introduce circular dependencies.   

2. Functional Correctness and Logic Quality
Confirm the implementation behaves as expected and addresses all edge cases, such as handling null inputs, empty collections, and network failures.   

3. Automated Test Coverage and Reliability
Ensure the pull request includes robust automated tests that validate both success and failure states.   

4. Non-Functional Requirements
Verify the change does not introduce performance issues, such as N+1 database queries, resource leaks, or blocking synchronous operations in async environments.

5. Security Safeguards
Check for common vulnerabilities, ensure inputs are sanitized, and confirm that access controls are correctly enforced.   

6. Observability Integration
Confirm that critical events are logged using structured formats (e.g., JSON logs with context variables) to support production debugging.   

7. API and Database Compatibility
Ensure database migrations are safe to run and that any API modifications maintain backward compatibility.   

8. Code Maintainability
Review the implementation to ensure it is clear, straightforward, and avoids unnecessary complexity.   

9. Variable, Function, and Class Naming
Confirm that all names are descriptive and clearly communicate the purpose of the underlying component.   

10. Commentary Quality
Verify that code comments explain why the implementation was built a certain way, rather than simply restating what the code does.   

11. Code Consistency and Styling
Ensure the modifications follow the project's formatting and styling conventions.   

12. Documentation Accuracy
Confirm that any user-facing or technical documentation is updated to reflect the new implementation.   

Code Review Etiquette
Reviewers must write comments that are constructive, educational, and focused on the code. Use phrases like "the system expects" or "this function could be simplified" rather than "you wrote this incorrectly".   

Non-blocking suggestions should be prefixed with [nit] to clarify they are optional, allowing the author to address them at their discretion.   

5. Merge Readiness Verification
Before a branch can be integrated into the main branch, it must pass a series of automated quality gates and verification checks.   

                     Automated Integration Pipeline
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  [Push to PR] ──► [Linter & Code Formatters]                            │
│                            │                                            │
│                            ▼                                            │
│                   [Unit & Integration Tests]                            │
│                            │                                            │
│                            ▼                                            │
│                   [Static Security Scanning]                            │
│                            │                                            │
│                            ▼                                            │
│                   [OpenAPI Contract Verification]                       │
│                            │                                            │
│                            ▼                                            │
│                   [Database Schema Safety Check]                        │
│                            │                                            │
│                            ▼                                            │
│                   [Green Build Gate: Ready to Merge]                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
Automated Quality Gates
1. Code Compilation and Builds
The application must compile without errors, and Docker production container builds must complete successfully in the CI environment.   

2. Test Suite Execution
All unit and integration tests must pass cleanly. Flaky tests are treated as failures, and merging code with failing tests is strictly prohibited.   

3. Code Coverage Targets
Code coverage must not drop below the project baseline, which is typically set at a minimum of 80% for critical business logic.   

4. Linter and Static Analysis Passes
Static analysis tools (such as Ruff for Python, ESLint for React, and Larastan for Laravel) must run successfully with zero high-severity errors.   

5. Dependency Vulnerability Scans
Dependency checkers (such as Dependabot or Snyk) must confirm that the changes do not introduce packages with known security issues.

Manual and Administrative Gates
Peer Sign-Off: The pull request must receive at least one approval from a human engineer.

Migration Safety Verification: If the change contains a database migration, developers must confirm that it uses lock-safe patterns and includes a rollback script.   

API Schema Matching: Any API modifications must be documented in the OpenAPI schema and verified as backward-compatible.   

Feature Flag Rollout: High-risk or complex features must be deployed behind feature flags so they can be easily toggled off in production if necessary.   

6. Integration Testing
Unit tests confirm that code components work in isolation, but integration testing ensures the entire system functions correctly as a cohesive unit.   

Post-Merge Validation Environment
The validation pipeline must run integration tests within a dedicated environment that closely mirrors production. For self-hosted environments, this is managed using a localized staging runner with Docker Compose to spin up isolated dependencies (such as PostgreSQL databases, Redis caches, and external service mocks).   

YAML
# docker-compose.integration.yml
version: '3.8'
services:
  app-test:
    build:
      context: .
      dockerfile: Dockerfile.test
    environment:
      - DATABASE_URL=postgresql://test_user:test_pass@db-test:5432/test_db
      - REDIS_URL=redis://redis-test:6379/0
    depends_on:
      - db-test
      - redis-test

  db-test:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=test_user
      - POSTGRES_PASSWORD=test_pass
      - POSTGRES_DB=test_db
    tmpfs:
      - /var/lib/postgresql/data

  redis-test:
    image: redis:7-alpine
Key Integration Scenarios
To catch failures before they reach production, integration testing must validate several core interaction vectors:

Cross-Module State Boundaries
Verify that events emitted by one system module (such as a billing service) are correctly received and processed by downstream modules (such as a notification service).

Schema and ORM Alignment
Confirm that database mapping definitions in the ORM align with the actual database schema. This is checked by running an automated migration sanity run in the CI pipeline:

Bash
# Validate Django ORM models against the database migration history
python manage.py makemigrations --check --dry-run
API Contract Fidelity
Confirm that updates to API responses do not break client assumptions. This is validated by running schema validation checks against API specifications in the pipeline.   

Client and Version Compatibility
Verify that updates to the API do not break older, deployed client apps (such as Flutter mobile apps) that cannot be forced to update immediately.   

Configuration Health Check
Confirm that configuration parameters, environment variables, and connections to external APIs are valid in the target runtime environment.

7. Merge Conflict Resolution
Merge conflicts occur when changes are made to the same file in parallel. To maintain repository stability, conflicts must be resolved using a structured, reproducible process.   

Standard Conflict Resolution Workflow
                        Git Conflict Resolution Flow
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  Step 1: Check out local feature branch                                   │
│  │                                                                        │
│  ▼                                                                        │
│  Step 2: Fetch remote trunk updates (`git fetch origin`)                  │
│  │                                                                        │
│  ▼                                                                        │
│  Step 3: Run interactive rebase (`git rebase origin/main`)                 │
│  │                                                                        │
│  ▼                                                                        │
│  Step 4: Resolve conflict markers in affected files                       │
│  │                                                                        │
│  ▼                                                                        │
│  Step 5: Run tests and verify compilation locally                         │
│  │                                                                        │
│  ▼                                                                        │
│  Step 6: Stage resolved changes and continue (`git rebase --continue`)    │
│  │                                                                        │
│  ▼                                                                        │
│  Step 7: Push updated branch to remote (`git push --force-with-lease`)    │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
Step 1: Synchronize Local State
Fetch the latest changes from the remote repository to ensure the local representation of the target branch is accurate:

Bash
git checkout main
git pull origin main
git checkout feat/your-feature-branch
Step 2: Initiate Rebase
Rebase the feature branch onto the target trunk. Rebasing is preferred over direct merge commits because it maintains a clean, linear history.   

Bash
git rebase main
Step 3: Resolve Conflict Markers
When Git identifies a conflict, open the affected files and locate the conflict markers:

<<<<<<< HEAD
# Existing implementation on main
=======
# New implementation on the feature branch
>>>>>>> feat/your-feature-branch
Analyze the context of both changes. Resolve the conflict by selecting the appropriate logic, then remove the conflict markers and save the files.

Step 4: Staging and Rebase Completion
After resolving the conflicts in a file, stage it and continue the rebase:

Bash
git add resolved_file.py
git rebase --continue
Once the rebase is complete, run the local test suite to confirm that the changes compile and all tests pass.

Step 5: Update the Remote Branch
Update the remote branch using a protected force push, which ensures no commits made by other developers are accidentally overwritten:

Bash
git push origin feat/your-feature-branch --force-with-lease
Specific Conflict Paradigms
Database Migration Timelines
If two parallel branches generate database migration files with conflicting sequence numbers, the migration pipeline will fail during deployment.   

To resolve this issue:

Roll back the local migration.

Delete the conflicting migration file.

Rebase the branch onto main to pull the latest migration file.   

Regenerate your migration file so it is placed correctly at the end of the sequence.   

Dependency Lockfiles
Conflicts in lockfiles (such as poetry.lock or package-lock.json) must not be resolved manually.

To resolve a lockfile conflict safely:

Checkout the lockfile from the target trunk: git checkout main -- poetry.lock.

Run the package manager's installation command to regenerate the file automatically (e.g., poetry install or npm install). This ensures the lockfile structure remains valid.

Stage the regenerated lockfile and continue the rebase.

8. Database Migration Integration
Applying migrations to a live production database is one of the most high-risk activities in software deployment. A simple table locking error can quickly cascade and take down an entire application.   

PostgreSQL locking Behaviors and Outage Mechanics
Most database outages during deployments are caused by locking conflicts rather than logical code bugs. In PostgreSQL, DDL commands require specific lock levels on the targeted tables.   

                     PostgreSQL Lock Conflict Matrix
┌──────────────────────────┬────────────────────────────────────────────────────────┐
│ DDL Command              │ Table Lock Level Required                              │
├──────────────────────────┼────────────────────────────────────────────────────────┤
│ CREATE TABLE             │ ShareRowExclusive (Allows concurrent reads) │
│ DROP TABLE               │ AccessExclusive (Blocks all reads and writes)          │
│ CREATE INDEX             │ Share (Blocks all writes) [cite: 12, 39, 40]           │
│ CREATE INDEX CONCURRENTLY│ ShareUpdateExclusive (Allows concurrent reads & writes)│
│ ALTER TABLE ADD COLUMN   │ AccessExclusive (Blocks all reads and writes)          │
└──────────────────────────┴────────────────────────────────────────────────────────┘
The major issue is not just the lock itself, but the Lock Queue Problem. When a migration script requests an AccessExclusiveLock, it joins a first-in, first-out (FIFO) queue and waits for any long-running queries to complete.   

While the migration is waiting in the queue, all subsequent queries (including simple SELECT statements) are blocked behind it, which can quickly exhaust the database connection pool and cause a system-wide outage.   

The Expand-and-Contract Pattern (Parallel Change)
To avoid downtime, any destructive schema change (such as renaming or dropping a column) must be broken down into backward-compatible steps deployed across multiple releases.   

                       The Expand-and-Contract Lifecycle
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Phase 1: Expand                                                            │
│  [ Create New Schema Element ] ──► [ Dual Write to Both Old & New Elements ] │
│                                                                             │
│  Phase 2: Sync                                                              │
│  [ Run Idempotent Batch Migration to Backfill Historic Data ]               │
│                                                                             │
│  Phase 3: Pivot                                                             │
│  [ Update Application Code to Read and Write Only to New Schema Element ]   │
│                                                                             │
│  Phase 4: Contract                                                          │
│  [ Safely Remove Obsolete Schema Elements and Stop Writing to Them ]        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
Step 1: Expand the Schema
Create the new column as a nullable field alongside the existing one.   

SQL
-- Migration: Add the new column without dropping the old one
ALTER TABLE users ADD COLUMN first_name_new varchar(255);
Step 2: Update Application Code (Dual Writing)
Deploy an update to the application code so that it writes data to both the old and new columns, but continues reading exclusively from the old column.   

Step 3: Backfill Historical Data
Run a backfill script to copy existing data from the old column to the new column. This migration must be processed in small, throttled batches to avoid locking too many rows at once.   

SQL
-- Idempotent batch backfill using cursor-based keys and sleep delays to prevent lock contention
UPDATE users 
SET first_name_new = first_name_old 
WHERE id IN (
    SELECT id FROM users 
    WHERE first_name_new IS NULL AND first_name_old IS NOT NULL 
    ORDER BY id LIMIT 1000
);
Step 4: Transition Reads
Deploy another application update so that the code now reads exclusively from the new column.

Step 5: Contract the Schema
Once you confirm that the system is stable and no processes are referencing the old column, remove the old field from the database.   

SQL
-- Remove the obsolete schema element
ALTER TABLE users DROP COLUMN first_name_old;
Safety Rules: Timeouts and Isolation Limits
To prevent migrations from blocking production traffic, every migration run must configure explicit timeout limits.   

lock_timeout: Controls how long a migration will wait to acquire a lock before failing and freeing the queue. The standard limit is 2 seconds.   

statement_timeout: Limits the maximum execution time of any individual query within the migration. The standard limit is 15 seconds.   

Django Postgres Timeout Configuration
In Django, timeouts can be configured globally by adding settings to the database configuration block:   

Python
# settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'production_db',
        'OPTIONS': {
            'options': '-c lock_timeout=2000 -c statement_timeout=15000',
        }
    }
}
FastAPI and Alembic Postgres Timeout Configuration
For FastAPI applications using Alembic, configure connection timeouts inside the env.py script:   

Python
# migrations/env.py
def run_migrations_online():
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
        connect_args={
            "options": "-c lock_timeout=2000 -c statement_timeout=15000"
        }
    )
Laravel Postgres Timeout Configuration
For Laravel applications, apply timeouts to database connections inside the database configuration:   

PHP
// config/database.php
'pgsql' => [
    'driver' => 'pgsql',
    'host' => env('DB_HOST', '127.0.0.1'),
    'database' => env('DB_DATABASE', 'production_db'),
    'options' => [
        PDO::AP_OPTIONS => '-c lock_timeout=2000 -c statement_timeout=15000',
    ],
],
9. API Compatibility
APIs serve as the interface boundaries of a system. Maintaining backward compatibility is essential to ensure that changes do not disrupt connected clients.   

Architectural Patterns for API Versioning
Date-Based Versioning (Stripe Model)
Under this model, version names are based on the date they are released (e.g., 2026-03-31). The application uses an internal compatibility layer to translate requests and responses between the latest implementation and the client's pinned API version.   

                     Date-Based Version Translation Flow
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Client (Pinned to v2024-05-12)                                             │
│  │                                                                          │
│  ├──► Request Payload: [old_structure]                                      │
│  │                                                                          │
│  ▼                                                                          │
│  API Compatibility Layer (Translates v2024-05-12 ──► vLatest)               │
│  │                                                                          │
│  ├──► Normalized Request: [latest_structure]                                │
│  │                                                                          │
│  ▼                                                                          │
│  Core Application Logic (Executes task using latest structure)             │
│  │                                                                          │
│  └──► Response Data: [latest_response]                                      │
│                                                                             │
│  ▼                                                                          │
│  API Compatibility Layer (Translates vLatest ──► v2024-05-12)               │
│  │                                                                          │
│  └──► Client Response Payload: [old_response_format]                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
Namespace-Based Versioning
Route namespace prefixes (such as /api/v1/ and /api/v2/) are used to isolate major version releases. This approach is easy to manage but can lead to code duplication if multiple versions must be supported simultaneously.   

Contract Testing Workflows
To prevent API changes from breaking client applications, integration pipelines must run automated contract tests using tools like Pact or Spectral.   

The contract pipeline is designed around three main steps:

Spec Generation: The backend generates an OpenAPI schema file during the CI run.   

Linter Validation: The pipeline verifies that the schema matches the project's style guide (e.g., parameter naming conventions and response definitions).   

Diff Analysis: The pipeline compares the generated OpenAPI schema against the current production version to identify and block backward-incompatible modifications:

Bash
# Compare the new schema against the current production version
openapi-cop --spec ./schema-new.yaml --baseline ./schema-production.yaml
Change Rules: Additive vs. Restructuring Changes
Additive Changes are Safe: Adding optional fields, new endpoints, or additional query parameters is backward-compatible and does not break clients.   

Restructuring Changes Require Versioning: Renaming fields, changing data types, removing endpoints, or adding required parameters are breaking changes. These changes must only be released behind a new API version or an explicit compatibility layer.   

10. Configuration & Environment Integration
System configuration changes are a frequent source of deployment failures. Environment variables, secrets, and feature flags must be managed with the same rigor as code.

Standard for Managing Environment Variable Updates
New environment variables must be declared in the repository's configuration template (e.g., .env.example) before code changes are merged into main. The pull request must not be merged until the production environment has been updated with the new variable.

┌────────────────────────────────────────────────────────┐
│      Safe Environment Variable Integration Sequence    │
├────────────────────────────────────────────────────────┤
│ 1. Define variables in local configuration template    │
│ 2. Configure variables in target environments          │
│ 3. Run CI checks to verify configuration health        │
│ 4. Merge pull request into main branch                 │
│ 5. Deploy application changes to production            │
└────────────────────────────────────────────────────────┘
Secrets Rotation and Storage Standards
Never Commit Secrets: Plain-text secrets, API keys, or certificates must never be committed to source control.   

External Variable Management: Secrets must be injected into container runtimes using environment variables managed by the hosting platform (such as Coolify, GitHub Secrets, or a secure vault).   

Encryption Standards: Local secrets used for development must be encrypted on disk, or stored in local environments that are explicitly ignored in the project's .gitignore file.

Volume Mapping and Secret File Gotchas
When using Docker Compose, volume-mapping files into containers requires strict prerequisite checks. If a mapped file (such as a private key or certificate) does not exist on the host before running `docker compose up -d`, Docker will automatically create an empty directory with the file's name in its place. This often causes applications to crash with `IsADirectoryError` upon starting. 
To prevent this, CD deployment pipelines must always explicitly generate, touch, or copy the required host files into place before invoking Docker Compose.

Feature Flag Delivery Model
Feature flags decouple code deployment from feature activation.   

Default Disabled: New features must be deployed in a disabled state by default.   

Graceful Fallbacks: If a feature flag is disabled, the system must gracefully fall back to the existing logic path without throwing exceptions.

Proactive Cleanup: Feature flags are intended for temporary rollouts. Once a feature is stable in production, the team must schedule a chore task to remove the flag and clean up the old code path.

11. CI/CD Integration
Automated continuous integration and deployment pipelines ensure that every code change is validated before it is deployed to production.   

┌─────────────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Continuous Integration                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Trigger: Push to main OR Pull Request                                  │
│                                                                         │
│  Stage 1: Linting and Static Analysis                                   │
│  ├── Run Code Linters & Formatters                                      │
│  └── Scan Dependencies for Known CVEs                                   │
│                                                                         │
│  Stage 2: Test Suite Execution                                          │
│  ├── Run Unit & Integration Tests in Parallel                           │
│  └── Generate and Verify Code Coverage Metrics                          │
│                                                                         │
│  Stage 3: Containment Validation                                        │
│  ├── Build Docker Production Containers                                 │
│  └── Run Container Vulnerability Scans                                  │
│                                                                         │
│  Stage 4: Automated Verification (PR Only)                              │
│  ├── Spawn Isolated Preview Container                                   │
│  └── Execute End-to-End Smoke Tests                                     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
Practical GitHub Actions Workflow for Coolify Deployments
This workflow automates building the application as a Docker image, running tests, pushing to the GitHub Container Registry (GHCR), and triggering a rolling update on Coolify.   

YAML
name: Build and Deploy

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test-and-verify:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Set up Python Environment
        uses: actions/setup-python@v5
        with:
          python-node-version: '3.11'
          cache: 'pip'

      - name: Install Application Dependencies
        run: |
          python -m pip install --upgrade pip
          pip install ruff pytest pytest-cov -r requirements.txt

      - name: Execute Code Linters
        run: ruff check .

      - name: Run Unit and Integration Tests
        run: pytest --cov=app --cov-report=xml

  build-and-push:
    needs: test-and-verify
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract Docker Image Metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=latest
            type=sha,format=long

      - name: Build and Push Production Docker Image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: Deploy Rolling Update via Coolify API
        run: |
          curl --fail --request GET '${{ secrets.COOLIFY_WEBHOOK }}' \
            --header 'Authorization: Bearer ${{ secrets.COOLIFY_TOKEN }}'
Pull Request Preview Deployments
To support review validation, pull requests should trigger automated isolated deployments using Coolify's PR Previews feature. This configuration creates a temporary, self-contained container instance for each PR, routed through a unique wildcard domain (e.g., pr-42.test.app.io) to allow reviewers to test changes in an isolated runtime environment.   

12. Regression Prevention
A regression occurs when a new code change breaks existing functionality. To prevent regressions, the integration pipeline must run a multi-layered verification suite at key stages of the deployment.   

The Role of DORA Metrics in Integration Quality
The DORA research program demonstrates that high-performing software organizations balance deployment velocity and system stability. The four core DORA metrics serve as key performance indicators for the engineering team:   

Deployment Frequency: How often code is successfully deployed to production.   

Lead Time for Changes: The time it takes for a commit to go from being merged to running in production.   

Change Failure Rate: The percentage of deployments that cause production failures or require immediate rollbacks.   

Failed Deployment Recovery Time (MTTR): The time required to restore service after a production failure.   

Standardizing code reviews, automated integration tests, and rollback safety procedures directly supports these goals, allowing teams to maintain a low Change Failure Rate while increasing deployment velocity.   

Regression Prevention Architecture
┌────────────────────────────────────────────────────────┐
│             Regression Prevention Framework            │
├────────────────────────────────────────────────────────┤
│ 1. Local Pre-Commit Hook Executions                     │
│ 2. Automated Pull Request Integration Run              │
│ 3. Automated Post-Merge Smoke Validation               │
│ 4. Active Metric and Latency Monitoring Checks         │
│ 5. Automated Sentry Log Exception Triggers             │
└────────────────────────────────────────────────────────┘
Pre-Commit Validation
Configure local pre-commit hooks (using tools like husky or pre-commit) to run linters and static checks before code is committed to a branch.

Multi-Tier Automated Tests
Maintain a balance of fast unit tests for local validation and comprehensive integration tests that execute in the CI pipeline.   

Active Production Telemetry
Configure application performance monitoring (APM) and logging tools (such as Sentry or Prometheus) to detect anomalies immediately following a deployment. If error rates exceed normal baselines, the alert system must notify the team to initiate an automated rollback.   

13. AI-Assisted Code Reviews
Integrating contributions generated by AI agents (such as Claude Code or Codex) requires special review practices. While AI agents can generate code quickly, their output can introduce specific types of quality and security issues that require human oversight.   

Specific Risks of AI-Generated Code
1. Phantom Changes and Functional Drift
AI agents sometimes generate pull request descriptions that claim to implement specific functionality or bug fixes that are missing from the actual code changes. Human reviewers must verify that every modification listed in the description matches the codebase diff.   

2. Architectural and Structural Drift
AI agents operate primarily within localized contexts and may write code that works in isolation but violates established project architectural patterns. Reviewers must ensure that agents reuse existing modules and utilities instead of writing redundant implementations.   

3. Overengineering and Speculative Abstractions
AI agents often generate complex classes or abstract layers to handle hypothetical future requirements. Human reviewers must ensure that all contributions focus on simple, maintainable code that meets the current requirements.   

4. Logical Hallucinations and Vulnerable Logic
AI-generated code may reference libraries that do not exist, use incorrect function arguments, or introduce security vulnerabilities (such as hardcoded values or weak validation controls).   

The AI-Review Integration Pattern (SKILL.md)
To ensure AI coding agents operate consistently, teams must define project standards inside a SKILL.md or similar instruction file in the repository root. This file provides the agent with structured rules for linting, security, and verification, allowing it to validate its own code before opening a pull request.   

Repository Agent Skill Configuration
Standard of Verification: All code changes must be accompanied by matching unit tests.

Structural Rules: Avoid creating duplicate logical layers; reuse helper functions inside utils/.

PostgreSQL Rules: Never generate blocking ALTER TABLE statements without configuring lock_timeout options.   

PR Rules: Validate the PR description to ensure it contains no phantom change descriptions.   

14. Release Integration
Merging code into the main branch is the beginning of the deployment process, not the end. The code must transition safely from the trunk to production without disrupting users.   

Staging Validation Process
Once a change is merged into main, it must be deployed to a staging environment that mirrors the production environment.   

The validation pipeline on staging follows three core steps:

Automated Migration Execution: Apply database migrations to the staging database and verify they run successfully.   

Integration Verification: Run automated end-to-end tests against the staging app to verify core user workflows are functioning correctly.   

Manual Validation: Developers should perform quick manual checks on staging to confirm that the changes behave as expected.   

Automated Release Notes
Upon a successful staging deployment, the pipeline should generate a draft release note containing:

A summary of the changes included in the release.

A list of modified database structures and API schemas.   

References to closed issue tickets.

Critical deployment and rollback procedures.   

Rolling Deployments and Rollbacks
For self-hosted Coolify environments, updates are deployed using rolling container replacements to ensure zero downtime.   

If an issue is detected in production, the team must have a verified plan to restore service.   

Toggle Feature Flags: If the issue is associated with a new feature, toggle the corresponding flag off in the platform dashboard to immediately disable the code path.   

Platform-Level Rollback: In the Coolify console, navigate to the application's deployments tab, locate the last working version, and click Redeploy to immediately revert to the stable container image.   

15. Common Integration Failures
Understanding common failure patterns helps engineering teams design processes to prevent them.   

Failure Mode Class	
Root Cause Pattern

Preventative Integration Control

The Lock Queue Outage	
A migration waits to modify a hot table, blocking subsequent database queries and exhausting connections.

Enforce strict lock_timeout limits on all migrations in the database connection.

Out-of-Sequence Runs	
An application update runs before its database migration completes, causing queries to fail.

Configure deployment tasks to execute and verify migrations before updating the application code.

Broken API Contracts	
An update modifies API responses, immediately breaking frontend or third-party integrations.

Use contract testing tools (such as Spectral) to validate API changes against specifications.

Environment Variable Drift	Code is deployed that relies on a new environment variable that has not yet been added to the production runtime.	Configure deployment pipelines to validate that all required environment variables are present before starting the new container version.
Stale Cache Invalidation	A schema update is deployed, but the application continues to read obsolete structures from a Redis cache.	Enforce explicit cache invalidation steps or include version keys in cached objects.
Lockfile Out-of-Sync	Developers modify dependencies in parallel, resulting in a broken lockfile that causes build failures in the CI pipeline.	Resolve lockfile conflicts by pulling the latest trunk version and running the package manager's install command to regenerate the lockfile cleanly.
  
Standardized Pull Request Templates
FEATURE PROPOSAL
Summary
Motivation
Technical Implementation Notes
Risks and Mitigations
Risk Class	Risk Description	Planned Mitigation Strategy
Performance		
Security		
Compatibility		
Testing Evidence
Database Impact
Does this pull request include database schema modifications? (Yes/No)

If yes, confirm that you have run the migration locally and verified the generated SQL.

Rollback Plan
Disable feature flag: FLAG_NAME

Revert to stable deployment version using Coolify.

BUG REMEDIATION
Defect Summary
Technical Root Cause Analysis
Correction Details
Preventive Actions
Testing Evidence
[ ] A regression test has been added that reproduces the bug and verifies the fix.

[ ] The entire test suite passes without errors in the CI environment.

Rollback Strategy
PRODUCTION HOTFIX
Hotfix Objective
Root Cause Analysis
Proposed Solution and Verification
Release and Integration Checklists
[ ] The changes are minimal and address only the hotfix objective.

[ ] Local tests pass successfully.

[ ] The rollback strategy is documented and verified.

[ ] The fix will be cherry-picked back into the main branch after deployment.

CODEBASE REFACTORING
Refactor Scope
Verification and Safety Gates
[ ] Public API signatures and interfaces remain unchanged.

[ ] Existing test suites pass without modification.

[ ] Performance benchmarks confirm the change does not introduce latency.

Rollback Strategy
SECURITY REMEDIATION
Security Vulnerability Detail
Remediation Strategy
Verification
[ ] Run security scanners to verify the vulnerability is resolved.

[ ] Confirm no secrets or keys have been committed.

Rollback Plan
PERFORMANCE OPTIMIZATION
Performance Baseline
Optimization Details
Performance Benchmark Comparison
Metric Measurement	Baseline Performance	Optimized Performance	Measured Improvement
Latency (P99)			
Database Queries			
Verification Evidence
Rollback Plan
DATABASE SCHEMA MIGRATION
Schema Modification Details
Safety and Lock Analysis
List any DDL operations included in the migration:

Describe potential locking risks and how they will be managed:

Verify lock timeout configurations are in place:

Step-by-Step Deployment Instructions
Run pre-release migrations:

Deploy new application code:

Run post-release migrations (if applicable):

Rollback and Recovery Instructions
Comprehensive Merge & Integration Checklists
1. Branch Creation Checklist
[ ] Does the branch name follow the standard pattern: Category/Issue-ID-Description?

[ ] Is the branch based on the latest commit of the target trunk branch?

[ ] Is the branch owned by a single engineer or designated AI agent?   

[ ] Have you verified that no other branch is addressing the same concern?

2. Before Opening a PR Checklist
[ ] Does the change address a single, distinct responsibility?

[ ] Does the pull request size remain under the 200-line standard?   

[ ] Have you pulled the latest changes from main and resolved any conflicts locally?   

[ ] Have all local tests passed successfully?

[ ] Are all commit messages formatted using Conventional Commits?

3. Pull Request Review Checklist
[ ] Does the implementation fit into the project's architecture?   

[ ] Is the code easy to read and understand?   

[ ] Are edge cases and potential error conditions handled correctly?   

[ ] Does the change include comprehensive unit and integration tests?   

[ ] Is system observability maintained with appropriate logs and metrics?   

4. Merge Readiness Checklist
[ ] Have all automated CI pipeline checks passed successfully?   

[ ] Have the code coverage targets been met (>80% for business logic)?   

[ ] Have security scanners verified that no vulnerabilities are introduced?

[ ] Has the pull request received the required number of human approvals?

[ ] Is a rollback plan documented and verified in the PR description?   

5. Conflict Resolution Checklist
[ ] Have you fetched the latest commits from main before resolving conflicts?

[ ] Have conflicts been resolved by rebasing onto main?   

[ ] Did you verify that the changes compile cleanly after resolving conflicts?

[ ] Have you run the local test suite to confirm everything works?

[ ] Did you push the updated branch using --force-with-lease?

6. Integration Testing Checklist
[ ] Have integration tests verified module-to-module compatibility?

[ ] Have API endpoints been validated against the OpenAPI schema?   

[ ] Have migrations been tested to ensure they align with ORM models?

[ ] Does the code prevent N+1 database queries and performance regressions?

[ ] Do client applications remain compatible with any API changes?   

7. Database Migration Review Checklist
[ ] Do DDL operations avoid long-running lock times in production?   

[ ] Are lock timeout and statement timeout configurations in place?   

[ ] Does the migration avoid blocking table-level lock queues?   

[ ] Are data migrations processed in small, throttled batches?   

[ ] Is there a verified rollback script for the migration?   

8. API Compatibility Review Checklist
[ ] Are all API modifications backward-compatible with older clients?   

[ ] Have API changes been validated against the schema using contract tests?   

[ ] Does the change avoid removing or renaming existing fields?   

[ ] Are mobile clients supported with appropriate API versioning?   

[ ] Has a deprecation schedule been defined and communicated?   

9. Configuration Review Checklist
[ ] Have all new environment variables been documented in the template?

[ ] Have secrets been configured securely in all target runtimes?   

[ ] Do feature flags allow the code to be safely enabled or disabled?   

[ ] Do feature flag states fallback gracefully to older logic paths?

[ ] Is there a plan to clean up temporary feature flags once stable?

10. CI Pipeline Review Checklist
[ ] Do all build steps run reliably in the CI environment?   

[ ] Are linting and static analysis tools configured correctly?

[ ] Do dependency scans run automatically to catch vulnerabilities?

[ ] Does the pipeline block merges if any quality gates fail?   

[ ] Are build artifacts and containers scanned for vulnerabilities?

11. Deployment Readiness Checklist
[ ] Has the target deployment environment been updated with required variables?

[ ] Are database migrations scheduled to run before application code?   

[ ] Have rollback steps been documented and tested for the deployment?   

[ ] Has the release been verified as stable in the staging environment?   

[ ] Has a low-traffic window been scheduled for high-risk deployments?

12. Post-Merge Verification Checklist
[ ] Confirm that the automated deployment completed successfully.

[ ] Run smoke tests on staging to verify core system behaviors.   

[ ] Monitor production logs and error tracking tools for spikes in exceptions.

[ ] Verify that system latency and SLOs remain within acceptable bounds.   

[ ] Confirm that any database changes migrated successfully without locking errors.

Merge Decision Trees
1. Is this PR ready for review?
                       [ Is this PR ready for review? ]
                                      │
                         Is the size < 200 lines?
                                ├── No  ──► Break down into smaller PRs.
                                └── Yes ──► Does it pass local tests and linting?
                                               ├── No  ──► Fix errors before requesting review.
                                               └── Yes ──► Has it been rebased onto main?
                                                              ├── No  ──► Rebase and resolve conflicts.
                                                              └── Yes ──► Open the Pull Request for review.
2. Is it safe to merge?
                           [ Is it safe to merge? ]
                                      │
                         Have all CI checks passed?
                                ├── No  ──► Fix CI build issues.
                                └── Yes ──► Has it received required approvals?
                                               ├── No  ──► Secure sign-off from reviewers.
                                               └── Yes ──► Are migrations safe and tested?
                                                              ├── No  ──► Redesign schema changes.
                                                              └── Yes ──► Safe to Merge into trunk.
3. Should the branch be rebased?
                       [ Should the branch be rebased? ]
                                      │
                        Is the branch up to date with main?
                                ├── Yes ──► Rebase is not required.
                                └── No  ──► Are there active conflicts on origin?
                                               ├── Yes ──► Run local rebase and resolve conflicts.
                                               └── No  ──► Rebase branch to verify pipeline stability.
4. Should conflicts be resolved manually?
                    [ Should conflicts be resolved manually? ]
                                      │
                        Are conflicts in auto-generated files?
                                ├── Yes ──► Use tools to regenerate lockfiles automatically.
                                └── No  ──► Are conflicts in custom source code?
                                               ├── No  ──► Verify file states before merging.
                                               └── Yes ──► Resolve conflicts manually in an editor.
5. Is another integration test required?
                    [ Is another integration test required? ]
                                      │
                        Does the PR modify API interfaces?
                                ├── Yes ──► Execute API contract tests.
                                └── No  ──► Does the PR include database schema changes?
                                               ├── Yes ──► Run database schema validation checks.
                                               └── No  ──► Standard integration suite is sufficient.
6. Should deployment be blocked?
                         [ Should deployment be blocked? ]
                                      │
                        Do migrations violate safety rules?
                                ├── Yes ──► Block deployment for schema correction [cite: 12].
                                └── No  ──► Are critical environment variables missing?
                                               ├── Yes ──► Block deployment until variable updates.
                                               └── No  ──► Proceed with rolling deployment.
7. Is rollback possible?
                           [ Is rollback possible? ]
                                      │
                        Does deployment contain migration DDL?
                                ├── Yes ──► Verify rollback migrations are functional.
                                └── No  ──► Is code protected by a feature flag?
                                               ├── Yes ──► Disable feature flag in management UI.
                                               └── No  ──► Rollback application using Coolify.
8. Should this feature use a feature flag?
                  [ Should this feature use a feature flag? ]
                                      │
                        Is the feature large or high-risk?
                                ├── Yes ──► Add feature flag to control rollout.
                                └── No  ──► Does it impact public API interfaces?
                                               ├── Yes ──► Add feature flag to manage rollout safely.
                                               └── No  ──► Standard direct deployment is safe.
Integration Playbooks
Playbook 1: Large Refactors
To safely execute a large refactor, use the Strangler Fig Pattern to replace code paths incrementally without disrupting active development.   

┌────────────────────────────────────────────────────────┐
│               Strangler Fig Pattern Flow               │
├────────────────────────────────────────────────────────┤
│ 1. Define Abstract Interface and Routing Abstractions  │
│ 2. Run Parallel Systems and Execute Both Codepaths      │
│ 3. Log Output Diffs to Identify Inconsistencies        │
│ 4. Pivot Production Traffic to the New Codebase        │
│ 5. Safely Deprecate and Remove Obsolete Libraries       │
└────────────────────────────────────────────────────────┘
Step 1: Establish Abstract Interface Boundaries
Create an abstract interface class that defines the inputs and outputs for the service being refactored.

Python
class PaymentProcessorInterface:
    def process_transaction(self, amount: float) -> bool:
        raise NotImplementedError()
Step 2: Implement Parallel Codepaths
Create implementations for both the legacy code and the refactored logic. Use a routing layer or feature flag to control which pathway is executed.   

Python
class LegacyProcessor(PaymentProcessorInterface):
    def process_transaction(self, amount: float) -> bool:
        # Legacy code path
        return True

class RefactoredProcessor(PaymentProcessorInterface):
    def process_transaction(self, amount: float) -> bool:
        # Optimized code path
        return True
Step 3: Run Parallel Codepaths in Production
During the early rollout phase, configure the routing system to execute both code paths but only return the results of the legacy processor. Compare the outputs of both systems to identify discrepancies or bugs.   

Step 4: Pivot Production Traffic
Once you confirm that the refactored processor is stable and returns correct results, switch the routing layer to return the outputs of the new processor.   

Step 5: Safely Remove Obsolete Logic
After verified stability under production loads, delete the legacy code implementation and the routing conditions.   

Playbook 2: Database Migrations
To run database migrations on large production tables without causing lock contention or downtime:   

Step 1: Add Column as Nullable
Add the new column to the table without any constraints or default values to minimize lock wait times:   

SQL
-- Acquire short lock to append nullable column
SET lock_timeout = '2s';
ALTER TABLE users ADD COLUMN age_int integer;
Step 2: Backfill Historical Data in Batches
Run an automated script to backfill data into the new column in small, throttled batches. This prevents locking the entire table and avoids exhausting database connections.   

SQL
-- Backfill batch transaction with cursor-based ordering
UPDATE users 
SET age_int = CAST(age_string AS integer) 
WHERE id IN (
    SELECT id FROM users 
    WHERE age_int IS NULL AND age_string IS NOT NULL 
    ORDER BY id LIMIT 500
);
Step 3: Set Constraint NOT VALID
Add any required constraints using the NOT VALID option. This allows the constraint to be created quickly without blocking table writes while validation is pending.   

SQL
-- Create validation constraint without blocking active table writes
ALTER TABLE users ADD CONSTRAINT check_age_bounds CHECK (age_int >= 0) NOT VALID;
Step 4: Validate the Constraint Concurrently
Validate the constraint in a separate transaction. This scans the existing rows to verify compatibility without locking the table.   

SQL
-- Validate constraint concurrently to complete the safety check safely
ALTER TABLE users VALIDATE CONSTRAINT check_age_bounds;
Playbook 3: Breaking API Changes
To safely implement a breaking API modification:   

Step 1: Create a Separate Endpoint Version
Do not modify the existing endpoint directly. Create a new, isolated route to handle the updated logic.   

Python
# Legacy API Route
@app.get("/api/v1/user")
def get_user_v1():
    return {"user_name": "Jane Doe"}

# Updated API Route
@app.get("/api/v2/user")
def get_user_v2():
    return {"first_name": "Jane", "last_name": "Doe"}
Step 2: Establish a Compatibility Translation Layer
If the database schema was modified, implement a compatibility layer to translate requests from old client structures to match the new schema structure, keeping older clients functional.   

Step 3: Coordinate Frontend Migration
Update web clients and internal tools to use the /api/v2/ routes. Verify that the v1 routes are only used by older, un-updated mobile clients.   

Step 4: Execute Deprecation and Sunset
Once older client usage drops below an established threshold, notify consumers and retire the /api/v1/ endpoint cleanly.   

Playbook 4: Dependency Upgrades
To manage risk when upgrading dependencies and libraries:   

Step 1: Isolate in Dedicated Branches
Upgrade dependencies in a dedicated chore branch, separate from any feature or refactoring work.

Step 2: Run Local Validation Suites
Run the project's linter and test suite to verify that the upgrade does not break existing code or introduce compiler warnings.

Step 3: Run Dependency and License Scans
Verify that the updated packages do not contain known vulnerabilities (CVEs) and align with the project's licensing standards.

Step 4: Perform Manual Verification on Staging
Deploy the upgrade branch to the staging environment and perform smoke tests to confirm the runtime remains stable.   

Playbook 5: Production Hotfixes
To deploy critical bug fixes to production rapidly:   

Step 1: Branch from Main Stable Release
Create a hotfix branch based on the latest stable production commit.   

Bash
git checkout -b hotfix/revert-bad-integration origin/main
Step 2: Implement Targeted Fix
Implement the minimal code required to fix the issue. Do not include unrelated refactoring or feature additions.   

Step 3: Verify the Fix Locally
Run the test suite and confirm that the change resolves the reproduction case.

Step 4: Deploy and Verify
Merge the hotfix branch into main and deploy it to production. Monitor exception tracking tools to confirm the issue is resolved and error rates drop.   

Code Integration Maturity Model
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Code Integration Maturity Model                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Level 1: Ad Hoc Integration                                                │
│  ├── Manual Merges directly to Main Branch                                  │
│  └── No CI Pipeline or Quality Gates                                        │
│                                                                             │
│  Level 2: Automated Linting and Tests                                       │
│  ├── Basic Automated Build & Test Run on PR                                 │
│  └── Merges require Pull Requests and manual approval                       │
│                                                                             │
│  Level 3: Enforced Branch Protections                                       │
│  ├── Merges blocked unless CI suite passes successfully                     │
│  └── Continuous integration checks block broken builds on trunk             │
│                                                                             │
│  Level 4: Safe Schema & API Evolution                                       │
│  ├── Database timeouts configured and migration safety checks in place       │
│  └── Automatic contract tests verify API compatibility                      │
│                                                                             │
│  Level 5: Continuous Delivery and Flow                                      │
│  ├── Deployments fully automated via CD pipelines with automatic rollbacks  │
│  └── AI agents automatically write tests and verify code compliance         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
"Definition of Ready to Merge" Framework
Before a pull request can be merged into main, it must meet several strict quality and compliance criteria.   

Verification Evidence Requirements
Automated Test Results: All automated unit, integration, and contract tests must pass cleanly.   

Quality Sign-Off: The PR must receive at least one human sign-off approving the design and implementation.

OpenAPI Specification Match: Any changes to API structures must be documented in the OpenAPI specification and pass contract validation.   

Security Validation: Vulnerability scans must confirm that no high-severity security issues are introduced.

Production Deployment Preparation: Environment variables and secrets must be updated in all target runtimes.   

Rollback Procedures: A step-by-step rollback plan must be documented in the PR description, and database migrations must include rollback scripts.   

Appendix: Structured Engineering Validation
This appendix provides a structured set of validation questions organized across 11 architectural domains to identify and mitigate integration risks.

Section I: Architecture & Structural Integrity
1.1 Logical Isolation: Does this change respect package boundaries and avoid creating circular references between services?

1.2 Clean Abstractions: Are new modules designed with a single responsibility, or should they be broken down into smaller files?

1.3 Duplication: Does this implementation reuse existing helper functions instead of writing redundant code?   

1.4 Direct Interface Mapping: If an interface is modified, have you confirmed that all implementations have been updated to match the new signature?

1.5 Decoupled Systems: Have domain services been decoupled from delivery mechanisms (e.g., keeping database logic out of views)?

Section II: Code Quality & Readability
2.1 Variable Naming Context: Do all variable, class, and method names clearly communicate their purpose?   

2.2 Code Complexity Metrics: Can nested loops or deep conditional branches be refactored to reduce complexity?   

2.3 Clean Codebase: Are all commented-out code blocks, unused imports, and obsolete dependencies removed from the diff?

2.4 Clear Comments: Do comments explain why code was written a certain way, rather than explaining what the code does?   

2.5 Exception Details: Are specific exception classes caught with appropriate context, rather than using generic try-except blocks?   

Section III: Testing & Verification Quality
3.1 High-Priority Coverage: Are critical logic blocks (such as billing or authorization) covered by unit tests?   

3.2 Edge Case Assertions: Do tests validate edge cases, such as handling null inputs, empty collections, and network failures?   

3.3 Assertion Intent: Do assertions verify exact states and side-effects rather than simple boolean states?   

3.4 Real Integration Tests: Do integration tests run against real or high-fidelity databases instead of heavily mocked components?   

3.5 Deterministic Runs: Have you confirmed that tests are deterministic and free from timing issues or flaky runs?

Section IV: Security & Vulnerability Scans
4.1 Exposed Secrets: Have you confirmed that no secrets, API keys, or certificates are committed to source control?   

4.2 Parameterized SQL: Are all database queries executed using safe parameterized inputs or secure ORM patterns?

4.3 Input Sanitization: Are external inputs sanitized and validated at the system boundaries before processing?   

4.4 Boundary Permissions: Are API endpoints protected by appropriate role-based access controls and authorization checks?   

4.5 Library Vulnerabilities: Have Snyk or Dependabot scans verified that no package versions with known CVEs are introduced?

Section V: Database Migration Safety
5.1 DDL Locking Rules: Do database changes avoid high-severity table-level locks that could block production writes?   

5.2 Migration Timeouts: Are lock timeout and statement timeout configurations set for all migration transactions?   

5.3 Throttled Backfills: Are large data migrations processed in small, throttled batches to prevent lock contention?   

5.4 Rollback Migrations: Have rollback migrations been generated and verified as functional in the local database?   

5.5 Order of Operations: Are migration steps structured to execute safely alongside running application code?   

Section VI: API Design & Backward Compatibility
6.1 Breaking Changes: Have you verified that API modifications are backward-compatible with older client versions?   

6.2 OpenAPI Synced: Are API modifications documented in the OpenAPI specification?   

6.3 Spec Compliance: Does the schema pass linter checks and match the project's style guide?   

6.4 Mobile Version Checks: Have contract tests verified that mobile client workflows are not broken?   

6.5 Graceful Deprecations: If a feature is deprecated, has a sunset plan been defined and communicated?   

Section VII: Configuration & Environment Integrity
7.1 Missing Variables: Have any new environment variables been documented in the repository template file?

7.2 Variable Configurations: Have target runtimes been configured with the required environment variables?

7.3 Vault Synchronization: Are production secrets managed securely in the hosting platform rather than in source control?   

7.4 Default Flags: Are new feature flags disabled by default to support safe rolling deployments?   

7.5 Flag Isolation: Does the code handle feature flags with graceful fallbacks if the flag is disabled?

Section VIII: Performance & Latency Bounds
8.1 N+1 Query Prevention: Have you checked that the changes do not introduce N+1 database queries under load?   

8.2 Optimized Indexes: Are database lookups supported by appropriate indexes, and do they avoid slow table scans?   

8.3 Blocking Sync Calls: Does the implementation avoid blocking synchronous operations in async runtimes?

8.4 Memory Management: Have database resources, file handles, and connections been managed properly to prevent leaks?   

8.5 Cache Usage: Are hot query pathways optimized using caches to reduce database load?

Section IX: Observability & Telemetry Integration
9.1 Structured Logging: Are critical system events logged in structured formats (e.g., JSON logs) with trace IDs?   

9.2 Error Logging Context: Are caught exceptions logged with appropriate context and stack traces to support debugging?   

9.3 Alerts Setup: Have alerts been configured to notify the team if exception rates spike in production?

9.4 Metric Registration: Are key performance metrics monitored to track the stability of the change?   

9.5 Trace Identification: Can transactions be tracked across services using unified trace headers?   

Section X: Deployment & Platform Readiness
10.1 Pipeline Success: Have all continuous integration pipeline stages passed successfully?   

10.2 Lockfile Integrity: Has the dependency lockfile been updated cleanly and verified to compile?   

10.3 Staging Verifications: Have changes been deployed and validated in the staging environment?   

10.4 Deployment Window: Has a low-traffic window been scheduled for deploying high-risk modifications?

10.5 Deployment Sequence: Are tasks scheduled to run database migrations before the application code updates?   

Section XI: User Experience & Design Consistency
11.1 Interface Guidelines: Have UI changes been verified to match the project's design and layout guidelines?

11.2 Graceful Degradation: Does the client handle network failures and API errors gracefully without crashing?   

11.3 Accessibility Compliant: Have frontend changes been checked to ensure they are accessible to all users?   

11.4 Mobile Performance: Does Flutter or React code run smoothly on mobile devices without dropping frames?

11.5 Layout Responsiveness: Have you verified that layouts scale correctly across different screen sizes and orientations?

16. Single Source of Truth for Cross-File Constants
When the same literal value, storage key, or field reference must appear in more than one file, it must be defined once and imported or referenced everywhere else. Copying it into a second location does not create two sources of the same truth; it creates two independent values that happen to start out equal and are free to drift the moment either one is edited alone.

The Duplication-to-Divergence Failure Path
┌────────────────────────────────────────────────────────┐
│         Duplication-to-Divergence Failure Path         │
├────────────────────────────────────────────────────────┤
│                                                          │
│  [ Value Copied Into a Second File Instead of Imported ]│
│                          │                               │
│                          ▼                               │
│  [ One Copy Is Edited Later; the Other Is Not ]          │
│                          │                               │
│                          ▼                               │
│  [ Behavior Silently Diverges Between the Two Callers ] │
│                          │                               │
│                          ▼                               │
│  [ Bug Surfaces Far From the Line That Actually Drifted]│
│                                                          │
└────────────────────────────────────────────────────────┘

Evidence From Production: Three Failures of the Same Shape
The following three incidents, drawn from the HBEC project's own bug and dev-log records, are the same failure shape expressed through three different mechanisms: a URL prefix constant, a storage key name, and an ORM field reference.

Duplicated Constant (API_BASE): HBEC's PROBLEM.md Bug #1 recorded three separate frontend files (revisionApi.ts, examApi.ts, useLevelPreference.ts) that each declared their own local const API_BASE = '/api' and prepended it to paths passed into apiFetch(). apiFetch() in src/lib/api.ts already prepended the same /api prefix internally, so every one of those copies silently doubled the path to /api/api/... and produced a 404. The constant was never wrong in isolation; it was wrong because it existed in four places instead of one.

Divergent Key Name (hbec_auth vs. hbc_auth_token): HBEC's PROBLEM.md Bug #2a recorded harnessApi.ts reading the auth token via localStorage.getItem('hbec_auth') as a JSON object, while api.ts actually stored the token under localStorage.setItem('hbc_auth_token', accessToken) as a plain string. Both files needed the same value — the current access token — but neither imported a shared constant for the storage key, so the two names, and the two formats, diverged without either author noticing until the harness chat API started returning 401 Unauthorized.

Repeated Invalid ORM Field (select_related("release")): HBEC's dev logs for 2026-07-21 record the same copy-pasted field reference causing the same crash in two different views, hours apart. TopicListCreateView.get_queryset() called Topic.objects.select_related("subject", "release") even though Topic has no release foreign key, which raised a FieldError and turned the topics list into a silent "0 topics" state. The immediate fix removed "release" from that one queryset. Later the same day, TopicDetailView — a second, separate view in the same apps/curriculum/views.py — crashed a DELETE request with the identical FieldError: Invalid field name(s) given in select_related: 'release', because it carried its own copy of the same invalid select_related("subject", "release") call that nobody had checked for after the first fix shipped.

Closing the Fix, Not Just the Ticket
The reason the select_related("release") mistake reappeared hours after it was first fixed is not that the fix was wrong — it is that the fix closed the reported ticket instead of closing the pattern. Fixing the one queryset that crashed answered the symptom in front of the reviewer; it did not answer the question "does this invalid field reference exist anywhere else in the codebase," and nobody asked that question until the second view crashed in production.

When a bug of this shape is found — a literal, key name, or field reference that has been copy-pasted rather than imported — the fix is not complete when the reported instance compiles and the ticket closes. Before the fix is considered closed, run a repository-wide search for the same literal or pattern (the constant's value, the key name, the field name) across every file, module, and service boundary, not only the one that was reported. A grep across the repository for select_related("release" or for hbec_auth would have found the second occurrence in the same afternoon instead of in a second incident.

Prevention Checklist
[ ] Is this literal, key name, or field reference used in more than one file?

[ ] If yes, is it defined once (a shared constant, enum, or config value) and imported everywhere else, rather than re-declared or copy-pasted?

[ ] When fixing a bug caused by a wrong literal, key, or field reference, has the same string or pattern been searched for across the entire repository — not just the reported file — before the fix is marked resolved?

[ ] Does the pull request description for this fix note whether a repo-wide search was run, and what (if anything) else it found?

