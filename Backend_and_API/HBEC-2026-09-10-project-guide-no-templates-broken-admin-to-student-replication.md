# Project Guide "No project templates are available yet" — admin→student replication never existed for this content type

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Production
**Severity:** Critical
**Status:** Workaround Applied (root cause not yet fixed)

## Summary
The student-facing Project Guide's "Start a new project" picker showed "No
project templates are available yet." on production, discovered during
investor-demo prep. Investigation found this isn't a bug in the empty-state
message — the `SBPTemplate` table it reads from was genuinely empty, because
no working pipeline has ever existed to populate it. Applied a direct
data workaround to unblock the demo; the underlying pipeline gap is unfixed.

## Symptoms
- `GET /api/projects/templates/` on the student backend returned an empty
  list; frontend correctly rendered its empty state.
- No error in logs — this is not a crash, it's a content gap that happens
  to look identical to one at the UI layer (see below).

## Environment Details
- **Server/Host:** hbca-vps, `/opt/hbec` (production)
- **Services Affected:** `hbec-student-backend` (`apps.sbp`), `hbec-admin-backend` (`apps.projects`)
- **Related Components:** `apps.replication` on both admin and student sides
- **Time First Observed:** 2026-09-10, investor-demo prep

## Investigation Steps

### 1. Initial Diagnosis
Checked the actual DB tables on both sides:
```
apps.projects.ProjectTemplate (admin):  0 rows
apps.sbp.SBPTemplate (student):         0 rows
```
Not a replication-lag issue — nothing has ever been created on either side.

### 2. Root Cause Analysis
Traced the intended authoring→serving path:
- Admin's authoring model is `apps.projects.ProjectTemplate` — has a real
  Django admin registration and CRUD API (`apps/projects/urls.py`), so
  admins genuinely can author templates today.
- Student's serving model is a **different, unreconciled** model:
  `apps.sbp.SBPTemplate` + `TemplateStep` — `SBPTemplateViewSet` is a
  `ReadOnlyModelViewSet`; there is no create endpoint, no Django admin
  registration, no seed/management command, and no fixture for it anywhere.
  The only `SBPTemplate.objects.create(...)` calls in the whole repo are in
  test files.
- The replication signal that fires on publishing a `ProjectTemplate`
  (`ADMIN/adminBackend/apps/replication/signals.py:612`,
  `on_sbp_template_save`) only dispatches to the **`"harness"`** target
  (`replicate_sbp_template_to_harness`). `ReplicationService.dispatch`'s
  `url_map` has no `"student"` path for this content type at all — so even a
  published `ProjectTemplate` would never reach the student backend.
- Bonus: `ReplicationService.build_harness_sbp_payload()`
  (`ADMIN/adminBackend/apps/replication/services.py:269`) imports
  `from apps.projects.models import SBPTemplate` — that class doesn't exist
  in admin's `apps.projects` (only `ProjectTemplate` does). This function
  has zero callers today, so it's inert, but it would `ImportError` the
  moment anything called it, confirming the SBP naming was never reconciled
  between the two services.
- Corroboration from the other direction: student's replication receiver
  (`STUDENT/hbec_backend/apps/replication/services.py`, `_dispatch_event`
  handler dict) has no `sbp_template`/`project_template` entry at all — even
  if admin somehow posted such an event to the student's replicate endpoint,
  it would fall through to "no handler for event type" and be silently
  ACKed and dropped (matching the stream consumer's documented
  always-ACK-no-retry behavior).
- A separate legacy tool, `apps.curriculum.management.commands
  .seed_zimsec_curriculum`'s `_seed_sbp_templates()`, does write directly to
  `apps.sbp.SBPTemplate` on the student side — but it's keyed to fictional
  subject codes (`"AGRICULTURE_OLEVEL"`, `"COMBINED_SCI_OLEVEL"`, etc.) that
  don't match production's real replicated `Subject` codes (numeric ZIMSEC
  codes, e.g. `"4001"` for Agriculture). Running it as-is on production
  would silently create zero templates (every subject lookup would fail and
  skip with a warning).

### 3. Key Findings
- Two disconnected models for the same concept (`ProjectTemplate` in admin
  vs `SBPTemplate` in student) that were never reconciled.
- The one replication signal that exists points at the wrong target
  (`"harness"`, not `"student"`) and calls a function with a real
  `ImportError` bug that's never been exercised because nothing calls it.
- No admin UI, seed command, or fixture ever populated the student-side
  table in any environment.

## Root Cause
Project Guide's template catalog was never fully wired end-to-end: the
admin-side authoring model, the student-side serving model, and the
replication path between them are three separate pieces that don't connect.
This is a genuinely unfinished feature, not a regression.

## Prevention / Rule
**Guardrail:** A CI check that asserts every dispatch target listed in
`ReplicationService.dispatch`'s `url_map` (e.g. `"harness"`, `"student"`)
has a live, importable handler on the receiving side for that event type —
and, separately, a rule that any function with zero callers in the
codebase (like `build_harness_sbp_payload`) is either exercised by a test
or flagged by a dead-code lint, not left silently inert until something
finally calls it.

This closes both concrete halves of this bug: the missing `"student"`
dispatch target would fail the check immediately, and the broken
`SBPTemplate` import in `build_harness_sbp_payload` would have raised in
CI the day it was written instead of the day someone finally called it.

## Solution

### Immediate Fix (workaround, applied to unblock the demo)
Wrote a one-off script creating 5 real `SBPTemplate` rows directly on
production's student backend, each with the real ZIMSEC 6-stage / 50-mark
SBP structure (same rubric content as `SBP_TEMPLATE_STEPS` in
`seed_zimsec_curriculum.py`, reused verbatim), attached to the real,
already-live production `SyllabusRelease` (`STREAM_SYNC`) and real,
currently-replicated `Subject` codes (`4001` Agriculture, `4003` Combined
Science, `4004` Mathematics, `4006` Heritage Studies, `4049` Commerce) —
unlike the legacy seed command's fictional codes. Verified via the real
public endpoint: `GET https://student.hbca.tech/api/projects/templates/`
now returns `count: 5` with full step/rubric data.

This is a direct-DB workaround, not a fix of the pipeline — nothing an
admin does in the admin UI today will ever reach this table.

### Long-term Fix (not yet done)
Needs one of:
1. Add a `"student"` dispatch target + a real `EventType` and handler for
   `sbp_template.created/updated/deleted` on both sides (admin
   `ReplicationService.dispatch` and student's `_dispatch_event` handler
   dict), reconciling the `ProjectTemplate` (admin) → `SBPTemplate`
   (student) field mapping (`milestones`/`rubric`/`deliverables` on admin's
   side vs `TemplateStep` rows on student's side needs a real transform,
   not a 1:1 copy).
2. Fix or remove the inert, buggy `build_harness_sbp_payload()` either way.
3. Decide whether the harness dispatch target is still wanted at all, given
   the "Start a new project" list only ever queries the student backend,
   never the harness.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — worth alerting on `ProjectTemplate` publish
      events that produce no matching student-side row within some window
- [ ] Documentation to update — `apps.sbp` needs a docstring/README noting
      it currently has no write path from admin
- [x] Code changes required — scoped above, not yet implemented (needs
      design decision on the field-mapping transform, flagged for next
      session rather than rushed under demo time pressure)

## Related Issues
- Same "signal fires, nothing consumes it" shape as the previously-found
  dead `replicate_model_config_to_harness` /
  `replicate_agent_config_to_harness` tasks from earlier this session (see
  the Model Settings work) — a recurring pattern in this codebase worth
  broader attention: check for other `on_*_save` replication signals whose
  dispatch target has no matching consumer.

## References
- `ADMIN/adminBackend/apps/projects/models.py` (`ProjectTemplate`)
- `ADMIN/adminBackend/apps/replication/signals.py:612` (`on_sbp_template_save`)
- `ADMIN/adminBackend/apps/replication/services.py:269`
  (`build_harness_sbp_payload`, broken import)
- `STUDENT/hbec_backend/apps/sbp/models.py` (`SBPTemplate`, `TemplateStep`)
- `STUDENT/hbec_backend/apps/sbp/views.py` (`SBPTemplateViewSet`, read-only)
- `STUDENT/hbec_backend/apps/replication/services.py` (`_dispatch_event`,
  no `sbp_template` handler)
- `STUDENT/hbec_backend/apps/curriculum/management/commands/seed_zimsec_curriculum.py`
  (`SBP_TEMPLATE_STEPS`, `_seed_sbp_templates`)
- `STUDENT/Frontend/src/features/project-guide/pages/ProjectGuidePage.tsx`

---

**Resolved By:** Claude (session with tinomupezeni) — workaround only
**Time to Resolution:** ~45 minutes (investigation + workaround); root
cause fix deferred
