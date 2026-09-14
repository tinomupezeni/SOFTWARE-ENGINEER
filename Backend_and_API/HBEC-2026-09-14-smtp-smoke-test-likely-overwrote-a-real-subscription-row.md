# `send_renewal_reminders` Has No Safe Default — An SMTP Delivery Check Can Silently Email and Mutate Real Subscriptions

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Production or Staging (exact target not confirmed — see Root Cause)
**Severity:** High
**Status:** Investigating (root cause plausible, not confirmed; underlying design flaw confirmed and still present)

## Summary
Asked to reconstruct an earlier compacted-summary note that "a real Gmail
account's Subscription row was overwritten during an SMTP smoke test."
Searched the whole repo (both backends, `scripts/`, `tests/uatt/`, git
history, uncommitted changes) for a dedicated SMTP-smoke-test artifact and
found none — no script or command in the tree is named or shaped like an
isolated, dummy-data SMTP connectivity check. The closest and most plausible
real mechanism is `STUDENT/hbec_backend/apps/accounts/management/commands/send_renewal_reminders.py`
(added 2026-09-12, commit `f017679f`): it is the only code path that both (a)
sends real mail through the hardcoded SMTP backend
(`STUDENT/hbec_backend/config/settings/base.py:250`,
`EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"`, no
environment override outside `local`/`test` settings) and (b) writes to a
real `Subscription` row (`last_renewal_reminder_for`) as a side effect of
running it. Anyone verifying "does SMTP actually deliver" by invoking this
command directly, without appending `--dry-run`, would have it iterate over
every real `ACTIVE`/`TRIAL` subscription expiring within 3 days, email each
one for real, and stamp `last_renewal_reminder_for` on each of those rows —
indistinguishable, from the DB's point of view, from "a Subscription row got
overwritten." No log, git diff, or file mtime in the repo pins this to a
specific run or a specific account, so the exact Gmail address and moment
could not be confirmed this session.

## Symptoms
- No crash or error — this is a silent, correctly-functioning code path
  whose only problem is that it has no isolated/no-op mode by default.
- Reported symptom (from a prior session's compacted summary, not
  independently reproduced here): a real Gmail-linked user's `Subscription`
  row had a field changed unexpectedly around the time someone was
  confirming that outbound email delivery worked.

## Environment Details
- **Server/Host:** Not confirmed — could be local dev (pointed at a shared
  or copied production-like DB), staging, or production; `EMAIL_BACKEND` is
  SMTP by default everywhere except `local.py`/`test.py`.
- **Services Affected:** Student Backend (`accounts.Subscription`,
  `accounts.User`), outbound SMTP relay.
- **Related Components:** `send_renewal_reminders` management command,
  `check_subscriptions` (sibling command, read-mostly, not implicated),
  `apps/accounts/tasks.py` (`send_password_reset_email_task`,
  `send_password_changed_email_task` — also send real SMTP mail but touch no
  `Subscription` field, so ruled out as the specific overwrite path).
- **Time First Observed:** Referenced in a compacted summary from an earlier
  part of this working session; exact timestamp unknown.

## Investigation Steps

### 1. Initial Diagnosis
Searched for anything literally named/shaped like an SMTP smoke test:
```bash
grep -ril -E "smtp.*smoke|smoke.*test|smtp_test|test_smtp|sendtestemail" --include="*.py" .
grep -rn -E "smtplib|send_mail\(|EmailMessage\(|django\.core\.mail|EMAIL_BACKEND" --include="*.py" .
```
Found only unrelated smoke tests (`smoke_test.py` in both backends, root
`scripts/smoke-test.sh`) that hit HTTP health endpoints, not email. No
script anywhere sends a real SMTP test message in isolation.

### 2. Root Cause Analysis
Enumerated every `Subscription` model (`STUDENT/hbec_backend/apps/accounts/models.py:604`
— Django; `PAYMENTS/app/models.py:48` — separate SQLAlchemy microservice,
not touched by any email code) and every write path to the Django one:
- `create_trial_subscription()` (`serializers.py`) — only called from the
  `except User.DoesNotExist` branch of signup/Google-auth, so it can't fire
  against an existing account; ruled out.
- `check_subscriptions` — only flips `status` to `EXPIRED` on rows whose
  period has genuinely already lapsed; ruled out as an "overwrite".
- `send_renewal_reminders` — queries real `ACTIVE`/`TRIAL` subscriptions,
  and for any expiring within 3 days, sends a real email and unconditionally
  does `subscription.save(update_fields=["last_renewal_reminder_for"])`.
  **Its `--dry-run` flag is opt-in; the default invocation sends live mail
  and writes the DB.** This is the only path matching both halves of the
  reported symptom (real SMTP send + real Subscription mutation).

Checked git history and current working tree for corroborating evidence:
```bash
git log --all --oneline -i --grep="smtp"
git log --all --oneline -i --grep="subscription"
git status --short   # no uncommitted changes to any accounts/*.py file
```
`f7612aa6` ("actually send the password-reset email instead of logging it")
confirms a real-delivery check was done on staging *and* production around
2026-08-21, but that path never touches `Subscription`. `send_renewal_reminders`
itself was added later (`f017679f`, files dated 2026-09-12), fits the
"newest subscription-adjacent code, most likely to have just been manually
verified" profile, but no log or commit records an actual invocation, so
this remains circumstantial.

### 3. Key Findings
- No dedicated/isolated SMTP smoke-test artifact exists in the repository —
  if one was run, it was ad hoc (shell/`manage.py shell`) and left no trace.
- `send_renewal_reminders` is the only command that can both email a real
  address and mutate a real `Subscription` row in one invocation, and it has
  no environment guard and no safe-by-default mode.
- `mupezeni2001@gmail.com` (the developer's own account, per git commit
  authorship and its appearance as an alert recipient in
  `monitoring/alertmanager.yml:46`) is the only real Gmail address hardcoded
  anywhere in the repo — the most likely candidate for a "known-good"
  manual test recipient, though not proven to be the specific account
  affected.

## Root Cause
Unconfirmed which exact run caused the reported overwrite, but the
mechanism that would cause it is real and present today: `send_renewal_reminders`
has no environment allowlist and no read-only default, so confirming "does
SMTP deliver" by running it directly (instead of via `--dry-run` or against
an isolated fixture) sends live mail to, and writes a field on, every real
subscription that happens to be expiring within the 3-day window at that
moment — including the operator's own account if it qualifies.

## Prevention / Rule
**Guardrail:** Give `send_renewal_reminders` (and any future one-shot
command that both emails and writes real rows) a fail-closed default: require
either `--dry-run` explicitly or a non-default `--confirm-live-send` flag
before it does anything with side effects, and have it refuse to run at all
against a target whose `DJANGO_SETTINGS_MODULE`/`EMAIL_BACKEND` indicates
production unless a matching `--i-mean-production` flag is also passed —
the same shape of guard already proposed for the load-test tool in
`HBEC-2026-09-10-load-test-tool-ran-against-production-142-accounts.md`.
This turns "I forgot the flag" from a live production side effect into a
no-op.

## Solution

### Immediate Fix
None applied — this was a read-only forensic investigation per explicit
instruction; no HBEC code, config, or data was modified.

### Long-term Fix
- Add the fail-closed default described above to `send_renewal_reminders`.
- Audit whether any real subscription currently has a `last_renewal_reminder_for`
  value that doesn't correspond to an email the user actually should have
  received (i.e., set by a test run rather than the daily Celery beat
  schedule), and clear it if so — needs DB access this session didn't have
  license to use.
- If the affected Gmail account can be identified with certainty (ask
  whoever ran the original smoke test which address they used), verify its
  `Subscription.plan_type`/`status`/`trial_ends_at`/`current_period_end`
  against what it should be and correct only if actually wrong.

## Prevention
- [ ] Add `--confirm-live-send` / production allowlist guard to
      `send_renewal_reminders`
- [ ] Grep for other management commands that send real mail with no
      dry-run default (`check_subscriptions` already has one; confirm no
      others were added since)
- [ ] Ask the operator which Gmail address was used as the manual SMTP test
      recipient, then verify (don't guess-correct) that one Subscription row
      in production
- [ ] Consider an audit log or event emission on every `Subscription.save()`
      outside the normal payment-webhook path, so a future manual test run
      is traceable instead of indistinguishable from the real thing

## Related Issues
- `HBEC-2026-09-10-load-test-tool-ran-against-production-142-accounts.md` —
  same underlying pattern (a testing/verification action with no
  environment guard reaching real production data), different mechanism

## References
- `STUDENT/hbec_backend/apps/accounts/management/commands/send_renewal_reminders.py`
- `STUDENT/hbec_backend/apps/accounts/management/commands/check_subscriptions.py`
- `STUDENT/hbec_backend/apps/accounts/models.py:604` (`Subscription`)
- `STUDENT/hbec_backend/config/settings/base.py:250` (`EMAIL_BACKEND`)
- `PAYMENTS/app/models.py:48` (separate `Subscription`, ruled out — no email
  code reaches it)
- commit `f7612aa6` (admin SMTP backend fix + prior real-delivery
  verification), commit `f017679f` (introduced `send_renewal_reminders`)

---

**Resolved By:** Claude (Sonnet 5), forensic investigation only — no fix
applied this session, root cause of the specific reported overwrite not
confirmed
**Time to Resolution:** Not resolved; guardrail proposed, not yet implemented
