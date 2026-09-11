# Admin's "Learning Guide" Content Type Has No Replication Signal, and Nothing Downstream Would Read It Even If It Did

**Date:** 2026-09-10
**Project:** HBEC
**Environment:** Development (found during a systematic replication audit, investor-demo prep)
**Severity:** High
**Status:** Investigating

## Summary
A full audit of every admin→student/harness replication signal (prompted by
the same-session discovery of the ProjectTemplate/SBPTemplate gap — see
`2026-09-10-project-guide-no-templates-broken-admin-to-student-replication.md`)
found `apps.projects.LearningGuide` — its sibling model in the same admin app,
with a full authoring UI (`ADMIN/adminFrontend/src/features/project-admin/components/LearningGuideForm.tsx`)
and CRUD API (`ADMIN/adminBackend/apps/projects/views.py` `GuideListCreateView`/`GuideDetailView`)
— is not wired to replicate at all, and separately, the harness pillar that
would plausibly consume it doesn't read anything shaped like it either. An
admin can author a full "Learning Guide" (system prompt, sections, learning
objectives, example interactions, response style) today and it will have
zero effect on any student-facing tutoring session.

## Symptoms
No error, no crash — a content-authoring feature that looks fully functional
(forms submit, list/detail/status views all work) and produces content that
is provably inert everywhere downstream.

## Environment Details
- **Server/Host:** N/A — found by static analysis, not yet checked against a
  live environment
- **Services Affected:** `ADMIN/adminBackend/apps.projects` (LearningGuide),
  `AGENTIC_HARNESS/app.learning_guide` (the pillar this content would need to
  reach)
- **Related Components:** `apps.replication.signals`
- **Time First Observed:** 2026-09-10, systematic replication audit

## Investigation Steps

### 1. Initial Diagnosis
Enumerated every `@receiver(post_save/post_delete, ...)` across the entire
admin backend (`grep -rn "@receiver(" apps/`). Confirmed the *only* file with
any signal receivers is `ADMIN/adminBackend/apps/replication/signals.py`, and
its complete model coverage is: `ExamBoard`, `Grade`, `Subject`, `Topic`,
`Content`, `ExamPaper`, `MarkingStandard`, `projects.ProjectTemplate`.
`projects.LearningGuide` — sitting in the exact same `apps/projects/models.py`
file as `ProjectTemplate`, with its own admin-authoring UI and CRUD API — has
no receiver at all. Publishing a `LearningGuide` (`status="published"`)
triggers nothing: no `StreamOutbox` row, no Celery task, no HTTP call.

### 2. Root Cause Analysis
Even assuming a signal were added, traced whether anything downstream expects
this content shape:
- The harness's project_guide pillar fetches its admin-authored content
  today (`app/project_guide/nodes.py:73-87`, `client.get_sbp_template(...)` →
  `app/shared/internal_client.py:242`, `GET /api/internal/sbp/templates/{id}/`
  on the student backend). That's the pattern a `LearningGuide` fetch would
  need to mirror.
- The harness's *learning_guide* pillar (`app/learning_guide/`) has no
  equivalent. Its `router.py` docstring describes it as "adaptive Socratic
  tutor" driven by `create_session`/`get_session`/`stream` endpoints, backed
  by `LearningGuideSession`/`LearningGuideMessage` (`app/learning_guide/models.py`)
  — session/transcript state, not a content template. Grepped
  `app/shared/internal_client.py` for every internal-API method: none fetch a
  "learning guide," "guide template," or anything from `apps.projects`. Its
  session context comes entirely from `topic_id` + the shared
  `context_assembler.py`/`learner_profile.py` pipeline (curriculum + learner
  model), never from admin's authored `system_prompt`/`sections`/
  `example_interactions`/`response_style` fields.
- Confirmed no other consumer either: `grep -rln "LearningGuide"` across the
  harness returns only the session/message models above (a name collision,
  not the same concept) and `app/shared/state.py`.

### 3. Key Findings
- `LearningGuide` (admin) has real authoring UI + CRUD API but is the only
  content model in `apps.projects` with **zero** replication wiring — not
  even a signal that dispatches to the wrong place, unlike `ProjectTemplate`.
- Even if a signal were added today pointed at the harness, there is no
  receiving logic on the harness side that would use it: `learning_guide`'s
  Socratic tutor is fully generic, keyed off curriculum topic and the
  learner model, with no concept of an admin-authored guide script at all.
- This is a step earlier than the ProjectTemplate/SBPTemplate bug: that one
  has a signal pointed at the wrong target; this one has no signal, and the
  target it would need doesn't exist either.

## Root Cause
`LearningGuide` was built as a full authoring feature (model, serializers,
admin UI) without ever deciding — or building — how a published guide reaches
the student-facing tutor. It is not a regression; the pipe was never laid.

## Solution

### Immediate Fix
None applied — read-only audit, no code changed.

### Long-term Fix
Needs a design decision before any code: does `learning_guide` (harness) stay
fully generic/curriculum-driven (in which case `apps.projects.LearningGuide`
should be removed or repurposed, since authoring content nothing reads is
worse than not offering the feature), or does the Socratic tutor need to
honor an admin-authored script per topic (in which case it needs its own
`get_learning_guide(topic_id)`-shaped internal API, a receiving model on
whichever side serves it, and a replication signal analogous to
`on_sbp_template_save` — reconciled against the SBPTemplate mistake this time,
i.e. one shared model/shape on both ends, not two.

## Prevention
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a until a decision is made
- [ ] Documentation to update — `apps.projects.LearningGuide`'s docstring
      should note it currently has no consumer, so it isn't assumed live in a
      demo
- [ ] Code changes required — scoped above, deferred pending a product
      decision on whether this content type is still wanted

## Related Issues
- Same audit that found this also confirmed (again) the
  ProjectTemplate/SBPTemplate gap
  (`2026-09-10-project-guide-no-templates-broken-admin-to-student-replication.md`)
  and the dead `replicate_agent_config_to_harness`/`replicate_model_config_to_harness`
  tasks (`2026-09-10-model-settings-plaintext-key-storage-and-disconnected-from-real-routing.md`).
  Three admin content-authoring features in the same audit, three different
  ways of never reaching what they were built for — worth a standing check
  before any future admin content type ships: does something real read it,
  end to end, not just "does a signal fire."

## References
- `ADMIN/adminBackend/apps/projects/models.py` (`LearningGuide`, no signal)
- `ADMIN/adminBackend/apps/replication/signals.py` (full receiver list — no
  `LearningGuide` entry)
- `ADMIN/adminBackend/apps/projects/views.py` (`GuideListCreateView` etc. —
  full CRUD exists)
- `ADMIN/adminFrontend/src/features/project-admin/components/LearningGuideForm.tsx`
- `AGENTIC_HARNESS/app/learning_guide/router.py`,
  `app/learning_guide/services/session_manager.py`,
  `app/learning_guide/models.py`
- `AGENTIC_HARNESS/app/shared/internal_client.py` (full method list, no guide
  fetch)

---

**Resolved By:** Claude (Sonnet 5), read-only audit — not yet fixed
**Time to Resolution:** N/A (identified only)
