# TESC complete staging artifact promotion

**Date:** 2026-10-17
**Project:** TESC
**Type:** Release / Deployment Remediation
**Status:** Completed

## Summary
Corrected the earlier incomplete production promotion by transferring the
exact currently running staging application images without rebuilding them.
The public frontend, institution frontend, backend, and worker now run the
staging artifacts, and production frontend asset manifests match staging.

## Context / Trigger
The user clarified that all currently running, tested staging Docker
application images—not newly rebuilt code or only selected services—must
replace the corresponding production application images. The earlier
promotion had left the old public frontend in production.

## Scope
Included exact staging application image transfer, production rollback
tagging, a fresh database backup, backend/worker/frontend recreation, migration
compatibility repair, nginx refresh, and public parity checks. PostgreSQL,
Redis, and nginx base infrastructure images were intentionally not replaced:
they are stateful/infrastructure services rather than application release
artifacts.

## Method
Inventoried running container image IDs on both VMs, selected the staging
backend, institution frontend, and public frontend images, streamed those
images with `docker save | gzip | ssh | docker load`, retagged them to the
existing production Compose names, recreated application services, ran
migration checks, and compared staging/production served asset manifests and
feature markers.

## Decisions & Findings
- Staging application images were newer than the production images.
- The earlier deployment had promoted backend and institution frontend but
  left the public frontend on the old production image.
- Exact staging asset manifests now match production:
  - Public JS: `index-B8l6B_9v.js`
  - Public CSS: `index-DrEN9FML.css`
  - Institution JS: `index-CS-wOuZg.js`
  - Institution CSS: `index-C_lEeOz2.css`
- The promoted frontend bundle contains the requested Analysis, Reports
  Studio, Admissions Dashboard, Dropout Analysis, and Special Enrollments
  features.
- A migration-history mismatch was discovered and repaired before declaring
  the backend healthy.

## Changes Made
- Created fresh backup:
  `/home/user/backups/tesc_predeploy_20261017T071358Z.dump`.
- Tagged previous production application images with rollback suffix
  `rollback-20261017T071358Z`.
- Transferred exact staging images:
  - `tinotenda762/tesc-backend:latest`
  - `tinotenda762/tesc-inst:latest`
  - `tinotenda762/tesc-main:latest`
- Retagged them to the live production Compose tags and recreated backend,
  worker, public frontend, and institution frontend.
- Reconciled the equivalent academic migration record.
- Restarted nginx to refresh upstream container addresses.

## Verification
- Production and staging public asset manifests match.
- Production and staging institution asset manifests match.
- Feature markers for Analysis, Reports Studio, Admissions Dashboard, Dropout
  Analysis, and Special Enrollments are present in both public bundles.
- Main and institution frontends return HTTP 200.
- Bare API routes return Django HTTP 404 rather than proxy HTTP 502.
- Backend, worker, both frontends, nginx, database, and Redis run with
  restart count zero.
- `migrate --check` passes.
- `makemigrations --check --dry-run` still reports an existing ISEOP model
  drift (`iseop.0004_alter_iseopstudent_gender`); this is recorded as
  deferred rather than falsely marked clean.

## Follow-ups / Deferred
- Resolve the existing ISEOP model/migration drift and add it to the release
  gate.
- Replace reused production image tags with immutable release tags.
- Add migration-graph compatibility checks before future promotions.
- Rotate previously exposed SMTP credentials and address the Celery
  root-user warning.

## References
- Production academic migration history drift issue
- `project_docs/09-deployment-and-operations.md`
- `project_docs/04-infrastructure-and-cicd.md`
- Production backup
  `/home/user/backups/tesc_predeploy_20261017T071358Z.dump`

---

**Completed By:** Copilot
**Duration:** Same deployment session
