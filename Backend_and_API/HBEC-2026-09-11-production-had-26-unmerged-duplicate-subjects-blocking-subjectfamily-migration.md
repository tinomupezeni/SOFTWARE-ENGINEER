# Production Had 26 Unmerged Duplicate Subject Rows, Blocking the SubjectFamily Migration

**Date:** 2026-09-11
**Project:** HBEC
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
Promoting today's staging work to production (admin-backend, admin-frontend,
student-backend, student-frontend, harness → new `promoted-20260911` tag)
triggered `admin-backend`'s automatic `migrate --noinput`, which crash-looped
on migration `0011_subject_family_required`:

```
RuntimeError: 2 Subject row(s) still have no family (unresolved (name, grade)
collisions from migration 0010). Resolve via merge_duplicate_subjects.py
before this migration can proceed.
```

This is the exact scenario the `SubjectFamily` split's own migration plan
anticipated (0010's backfill leaves any row it can't disambiguate with
`family_id=NULL`, and 0011 refuses to proceed while any remain) — and there
was already a purpose-built, reviewed management command
(`merge_duplicate_subjects`) written in advance specifically for this. It had
apparently never been run against production's actual data.

Running its dry-run revealed the two rows that broke the migration were only
the tip of it: **26 pairs** of stray-suffix duplicate `Subject` rows existed
on production (e.g. `6009` / `6009-5` "Literature in English", `702-5` /
`702-6` "Mathematics" with 8-9 real topics each) — the same double-entry
pattern the command's docstring documents (a curator pasting a syllabus code
with a stray validity-period suffix, with no duplicate-by-name check
anywhere in the stack to catch it).

## Investigation Steps
1. Rolled `admin-backend`/`admin-worker`/`admin-beat` back to the previous
   `promoted-20260910` tag immediately to restore service (crash-looping,
   0 seconds uptime) — confirmed migrations 0007-0010 had already committed
   individually before 0011 failed and rolled back cleanly (each Django
   migration is its own transaction), so the rollback to old code was safe:
   old code doesn't reference the new `subject_families` table or `family_id`
   column at all.
2. Queried the two blocking rows directly — both genuine duplicates (same
   exam board, same grade, same name, different `code`), exactly the shape
   `merge_duplicate_subjects.py` was written to handle.
3. Ran `merge_duplicate_subjects` (dry-run, no `--apply`) — found 26 pairs,
   not 2. Confirmed with the user before applying, since this was materially
   broader in scope than what the deploy itself required, and specifically
   confirmed the student-side deletion handler
   (`stream_consumer.py::_handle_subject_delete`) fails safe — it catches an
   exception and refuses to delete (logs and returns) if the student-side
   row still has child rows, rather than cascading data loss, before running
   `--apply`.
4. Applied: 26 duplicates merged, 53 topics re-pointed to survivors, 26
   `subject.deleted` events queued to the replication outbox.
5. One row remained unresolved after the merge — the original `6009`
   survivor itself, which 0010's backfill had also skipped (the collision
   was between it and its now-deleted duplicate, so resolving the pair
   doesn't retroactively give the survivor a family). Resolved directly via
   SQL, pointing it at the `SubjectFamily` row already created for
   "Literature in English" under the same exam board (from a different
   grade's already-successfully-backfilled offering).
6. Redeployed `admin-backend`/`admin-worker`/`admin-beat` — migration 0011
   applied cleanly, `showmigrations curriculum` confirmed `[X]` through
   0011, admin-backend's `Subject` model confirmed correct (`family` field
   present, `name` no longer a field).

## Root Cause
`merge_duplicate_subjects.py` was written (evidently during the same
`SubjectFamily` restructuring work) as a prerequisite cleanup step for
migration 0011, but was only ever run against staging's data before the
0011 migration was promoted there — production, with its own independently
accumulated duplicate-entry history, was never given the same treatment
before today's promotion attempted to bring it the same migration chain.

## Prevention / Rule
**Guardrail:** Fold the dry-run check directly into the migration's own
`RunPython` step for every environment, not just as a standalone script run
once on whichever environment happens to be promoted first — the migration
already refuses to proceed on unresolved rows (as it correctly did here);
extend that same refusal to require confirmation that the dry-run has been
executed and applied *in this specific environment*, not merely that the
migration file has been merged.

Production's 26 duplicates were its own independently-accumulated mess,
invisible until the migration itself ran there — a per-environment
precondition check (not a one-time staging pass) is the only thing that
generalizes to every future environment this migration chain reaches.

## Solution

### Immediate Fix
- `merge_duplicate_subjects --apply` run against production: 26 pairs
  merged, 53 topics re-pointed, 0 content/data loss (student-side delete
  handler's fail-safe design means even a duplicate with live student-side
  content would refuse the cascade rather than losing it — not exercised
  here since admin-side re-pointing already cleared every duplicate's
  children before deletion).
- One remaining unresolved `family_id` (the `6009` survivor) fixed directly
  via SQL, pointing at the pre-existing `SubjectFamily` for the same name.
- Migration 0011 now applied cleanly on production; `admin-backend`/
  `admin-worker`/`admin-beat` all confirmed on the new code and healthy.

### Long-term Fix
None needed specifically — this was a one-time backlog, not an ongoing
generator of new duplicates (the double-entry root cause the command's
docstring describes — free-text `code` field, no duplicate-by-name check —
is a separate, still-open gap worth its own fix if it keeps happening, but
out of scope for this promotion).

## Prevention
- [ ] Monitoring/alerts to add — none identified
- [ ] Documentation to update — note that any environment being promoted
      through the `SubjectFamily` migration chain for the first time needs
      `merge_duplicate_subjects` run (dry-run first) before migration 0011,
      not just staging
- [ ] Code changes required — none; the duplicate-prevention gap in the
      subject-creation path (free-text code, no name uniqueness check) is a
      separate follow-up, not addressed here

## Related Issues
- Same `SubjectFamily` restructuring as this session's earlier entries
  (`2026-09-11-admin-backend-staging-ran-stale-code-against-migrated-subject-schema.md`
  was the staging-side version of a related class of promotion gap).
- `merge_duplicate_subjects.py`'s own docstring references
  `clean_subject_codes.py` as an earlier, narrower precedent for this same
  shape of merge.

## References
- `ADMIN/adminBackend/apps/curriculum/management/commands/merge_duplicate_subjects.py`
- `ADMIN/adminBackend/apps/curriculum/migrations/0010_backfill_subject_family.py`,
  `0011_subject_family_required.py`
- `STUDENT/hbec_backend/apps/replication/stream_consumer.py::_handle_subject_delete`
  (the fail-safe delete handler verified before applying)

---

**Resolved By:** Claude (Sonnet 5)
**Time to Resolution:** Same session as discovery, during a production
promotion
