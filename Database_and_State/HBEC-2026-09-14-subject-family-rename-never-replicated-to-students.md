# SubjectFamily Renames Silently Never Reached the Student Backend

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Staging only (production intentionally left untouched)
**Severity:** High (a shipped feature was silently non-functional
end-to-end, with zero error signal anywhere)
**Status:** Resolved — verified live on staging

## Summary
Asked whether the student side got updated in line with today's earlier
admin-side subject dedup/rename work. Investigating that question found
a real, currently-live bug: **renaming a `SubjectFamily` — including via
the "Edit Subject" name-editing feature shipped earlier this same
session — never replicates to the student backend.** The rename
succeeds in the admin database and looks correct in the admin UI; the
new name simply never reaches students, with no error, no log line,
nothing anywhere to indicate the edit didn't actually propagate.

Confirmed concretely: earlier today's "SHONA LANGUAGE" →
"Shona Language (ChiShona)" rename (part of the secondary-subject dedup
work, same session) was still showing the stale all-caps name on the
student backend at the time this was investigated.

## Root Cause
`Subject.name`/`description`/`name_sn`/`name_nd` are read-only
`@property` methods that proxy to `self.family.*` (not real database
columns — this is intentional, from the `SubjectFamily` split earlier
this project). Replication (`apps/replication/signals.py`) only ever
fires from `Subject`'s own `post_save` signal (`on_subject_save`) —
there was no signal handler for `SubjectFamily` at all. Since
`SubjectFamilyDetailView.update()` only ever saves the `SubjectFamily`
row itself, and never touches any child `Subject` row, nothing calls
`Subject.save()` when a family is renamed — so `on_subject_save` never
fires, and the new name is never queued for replication.

## Investigation
A background research pass traced the full pipeline
(`Subject.post_save` → `StreamOutbox` → `poll_stream_outbox` beat task
→ Redis stream → student's `consume_content_stream` beat task →
`_handle_subject`) and confirmed each stage works correctly **for
Subject-level changes** — `Subject` creates and code/family-FK updates
all replicated correctly today. It also confirmed, directly against
staging data: `StreamOutbox.objects.filter(content_type__icontains="family")`
returns zero rows, ever — no `SubjectFamily` event has ever been
replicated in this system's history. And the one `Subject` row that
*was* saved around the same time as today's family rename (a family FK
repoint, saved ~35 seconds *before* the rename) carried the *old*
family name in its payload, since the payload is built from
`instance.family.name` at the moment `Subject.save()` runs — a snapshot,
not a live pointer.

## Solution
New `on_subject_family_save` (`post_save` on `SubjectFamily`,
`apps/replication/signals.py`): touch-saves every offering
(`instance.offerings.all()`) whenever a family is saved, skipped for a
brand-new family (which has no offerings yet). Each touched `Subject`'s
own `post_save` then fires exactly as it would from a direct edit —
`instance.family` is freshly queried per subject (not cached), so it
already reflects the family's just-committed new values by the time
`on_subject_save` runs and builds its payload.

4 new tests (`test_subject_family_signals.py`): renaming a family with
two offerings queues one fresh `subject` outbox event per offering, each
carrying the new name; a family with no offerings yet queues nothing;
creating a new family doesn't error trying to touch offerings that
can't exist yet; renaming one family never touches an unrelated
family's own offerings. Full `apps/replication` + `apps/curriculum`
suite (153 tests) passes; `ruff` clean.

## Repair of the already-broken state
Re-saved the "Shona Language (ChiShona)" family on staging after
deploying the fix (`family.save()`, no field changes — just to
re-trigger the now-working signal) — queued 6 fresh outbox events, one
per offering. Verified on the student backend after the next replication
cycle: **all 6 subjects now correctly show "Shona Language (ChiShona)"**,
including the one row a prior investigation had found completely
missing from the student database (its last real save predated today —
the touch-save fix incidentally recreated/corrected it too, since the
student consumer's upsert-by-id logic creates the row if it's absent).

## Deployment
Staging only, per the running instruction for this work session —
production untouched (confirmed via image inspection: still running the
prior commit's build). Full staging host health sweep clean after
deploy and after the repair re-save.

## References
- `ADMIN/adminBackend/apps/replication/signals.py` —
  `on_subject_family_save`, `on_subject_save` (the existing mechanism
  this reuses)
- `ADMIN/adminBackend/apps/curriculum/models.py` — `Subject.name` and
  siblings (the read-only properties that made this gap possible),
  `Subject.family`, `SubjectFamily`
- `ADMIN/adminBackend/apps/curriculum/views.py` —
  `SubjectFamilyDetailView.update()`
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py` —
  `_handle_subject` (the consumer side, confirmed already correct)
- Related: `HBEC-2026-09-14-secondary-subject-duplicate-families-merged.md`
  (the rename whose failure to replicate surfaced this bug),
  `HBEC-2026-09-14-subject-edit-dialog-points-to-nonexistent-family-edit.md`
  (the feature this bug silently broke, same session)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — found while verifying whether
earlier work had reached the student side, root-caused, fixed, tested,
deployed to staging only, and used to repair the already-broken state
it had caused earlier the same session
