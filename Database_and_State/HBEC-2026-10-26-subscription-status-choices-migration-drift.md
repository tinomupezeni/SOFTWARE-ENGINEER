# Subscription.status `choices=` list had drifted from its last migration

**Date:** 2026-10-26
**Project:** HBEC
**Environment:** Development (caught locally before any deploy)
**Severity:** Low
**Status:** Resolved

## Summary
Running `makemigrations accounts` for an unrelated feature (adding two new
phone-prompt fields) surfaced an `AlterField` on `Subscription.status` that
had nothing to do with the feature being built: the `choices=` list in
`apps/accounts/models.py` (which includes `"comped"`) no longer matched what
the last migration touching that field recorded. Caught and split into its
own migration before merging, rather than silently bundled into the
unrelated feature's migration file.

## Symptoms
- `python manage.py makemigrations accounts` for a feature that only added
  two new `DateTimeField`s also proposed an unrelated `AlterField` on
  `Subscription.status`.
- No runtime symptom — Postgres has no `CHECK` constraint derived from
  Django's `choices=`, so no query or write was ever affected. Purely a
  migration-state/model mismatch that `makemigrations --check` would flag.

## Environment Details
- **Server/Host:** Local development only.
- **Services Affected:** Student Backend (`STUDENT/hbec_backend`), `accounts` app.
- **Related Components:** `apps/accounts/models.py` `Subscription.status`.
- **Time First Observed:** 2026-10-26, while adding the phone-number-prompt feature.

## Investigation Steps

### 1. Initial Diagnosis
`makemigrations accounts` output included a third operation beyond the two
fields actually being added:
```
Migrations for 'accounts':
  apps/accounts/migrations/0034_..._and_more.py
    + Add field phone_prompt_dismissed_until to parentprofile
    + Add field phone_prompt_dismissed_until to studentprofile
    ~ Alter field status on subscription
```

### 2. Root Cause Analysis
Compared `Subscription.status`'s current `choices=` in `models.py` against
the `field=` value baked into the most recent prior migration that touched
it. The model's choices list (including `"comped"`) had been edited at some
point without a matching migration ever being generated — ordinary drift,
not a destructive change (Django's `choices` is validation metadata only,
not a DB-level constraint).

### 3. Key Findings
- `makemigrations --check --dry-run` after my own changes landed confirms
  "No changes detected" once this `AlterField` is included — so this was
  the entire outstanding drift, nothing further hiding behind it.
- `scripts/deploy/check-migrations.py` (the CI gate for destructive changes)
  passes this migration cleanly, as expected — `AlterField` on `choices=`
  touches none of its flagged destructive operations.

## Root Cause
A prior change to `Subscription.status`'s `choices=` list in `models.py`
was never followed by `makemigrations` — a model/migration-state mismatch
that stays invisible until something else triggers a `makemigrations` run
against the `accounts` app and surfaces the accumulated diff.

## Prevention / Rule
**Guardrail:** Run `python manage.py makemigrations <app> --check --dry-run`
in CI for every app touched by a PR (not just at merge time for the app
actually being migrated) — a model edit with no accompanying migration
should fail the build immediately, not wait to be discovered by the next
unrelated migration.

This specific gap is closed because `--check` exits non-zero the moment a
model's current state and its migration history diverge, regardless of
which model or how long the drift has been sitting unnoticed - it does not
need to be noticed by curiosity-driven effect of another nearby change.

## Solution

### Immediate Fix
Generated the autodetected migration, then split the unrelated
`AlterField` out of the feature migration into its own file
(`0035_subscription_status_choices_state_fix.py`) so each migration's diff
matches its own description — never bundled a schema change the PR wasn't
about into the PR's own migration file.

### Long-term Fix
Add the CI check named above (`makemigrations --check --dry-run` per
touched app) so the next unrelated drift is caught at the PR that
introduced the model edit, not the next PR that happens to touch migrations
for the same app.

## Prevention
- [x] Configuration changes needed — none; this is a process/CI gap, not a
      runtime config issue.
- [ ] Monitoring/alerts to add — N/A, no runtime symptom.
- [ ] Documentation to update — N/A.
- [x] Code changes required — `scripts/deploy` or `ci.yml` should add the
      `makemigrations --check` step described above (not yet added; this
      entry documents the gap, the CI change itself is a separate PR).

## Related Issues
- None — first time this exact drift was observed.

## References
- `STUDENT/hbec_backend/apps/accounts/migrations/0034_parentprofile_phone_prompt_dismissed_until_and_more.py`
- `STUDENT/hbec_backend/apps/accounts/migrations/0035_subscription_status_choices_state_fix.py`
- `scripts/deploy/check-migrations.py` (confirms this class of `AlterField` is never flagged destructive, correctly)

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** Immediate — caught and split before any commit
