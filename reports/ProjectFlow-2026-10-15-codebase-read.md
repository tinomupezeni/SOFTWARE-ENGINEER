# ProjectFlow codebase read

**Date:** 2026-10-15
**Project:** ProjectFlow
**Type:** Audit
**Status:** Completed

## Summary
Read the ProjectFlow backend structure, Django configuration, core data models,
authentication flow, workspace permissions, project/task domain, observability
module, deployment files, and architecture notes. The backend is a Django REST
API with JWT authentication and workspace-scoped access control, with an
observability subsystem for VPS telemetry. A production configuration issue was
identified and logged separately.

## Context / Trigger
The user requested a read of the codebase to establish a working understanding of
its structure and runtime behavior.

## Scope
Included tracked Python application code, settings, URL routing, requirements,
deployment/configuration files, and the two repository architecture documents.
Generated virtual-environment files, bytecode caches, and database contents were
excluded from the architectural map.

## Method
Inspected the repository status and tracked runtime files, then read the Django
settings and root URL configuration followed by the principal models for users,
workspaces, projects/tasks, and observability. Read the authentication views and
the multi-organization and observability documentation to compare implemented
surfaces with stated direction.

## Decisions & Findings
- The system is a Django REST Framework backend using a custom UUID-based
  `users.User` model and Simple JWT bearer authentication.
- Authentication includes account requests, admin approval gating, email
  verification, refresh-token cookies, password reset, and reminder-related user
  preferences.
- Workspaces are the current isolation boundary. Membership roles include guest,
  member, and manager; projects belong to workspaces, and tasks/subtasks belong
  to projects/tasks.
- The root API exposes authentication, users, workspaces, projects, and
  observability routes under `/api/`; Django admin is under `/admin/`.
- Observability tracks VPS registrations, heartbeats, events, alerts, health
  checks, and optional outbound webhook notifications.
- The repository contains a multi-organization row-level tenancy proposal, but
  the implemented models currently use workspaces rather than an
  `Organization`/`OrganizationMember` schema.
- The worktree was already dirty, with modified settings/URLs/database/deploy
  files and many untracked observability/deployment/cache files; these were not
  altered.
- Unsafe production settings were found and logged in
  `DevOps_and_Infrastructure/ProjectFlow-2026-10-15-production-settings-not-hardened.md`.

## Changes Made
No ProjectFlow source files were changed. The separate engineering-record
repository received the issue log above in commit `9b41cd5`, which was pushed to
its `master` branch.

## Verification
Verified the repository structure and line-level settings references by direct
file inspection. No test suite or deployment command was run because the request
was for codebase familiarization rather than implementation.

## Follow-ups / Deferred
- Harden production settings and rotate the committed Django signing key.
- Decide whether and when to implement the documented multi-organization model.
- Review the existing dirty/untracked worktree before any implementation or
  deployment work.
- Run Django deployment checks and focused authentication/authorization tests
  before production changes.

## References
- `projectflow_backend/settings.py`
- `projectflow_backend/urls.py`
- `users/models.py`
- `workspaces/models.py`
- `projects/models.py`
- `observability/models.py`
- `authentication/views.py`
- `docs/multi_org_proposal.md`
- `docs/observability-rollout.md`
- Related issue:
  `DevOps_and_Infrastructure/ProjectFlow-2026-10-15-production-settings-not-hardened.md`

---

**Completed By:** Copilot
**Duration:** One session
