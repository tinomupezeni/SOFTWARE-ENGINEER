# Content Requests Responsive Fix, Bulk-Email Audience Picker, Email Bounce Reporting

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Feature (three distinct pieces of user feedback, admin-facing)
**Status:** Completed and deployed to production — verified end-to-end

## Summary
Three separate pieces of feedback on earlier work this session, each
addressed and shipped:

1. **Content Requests table didn't adapt to viewport width** — a
   straightforward responsive-layout bug.
2. **Bulk-email audience picker** — today's earlier "All User Communication"
   page deliberately shipped with no picker ("there is no audience picker
   here"); the user asked for one: all students, or a specific selection.
3. **Email bounce reporting** — a real bounce notice (a full student inbox)
   showed up in the sending mailbox with nothing in HBCA catching or
   reporting it to admin.

## Context / Trigger
User pasted screenshots of the live admin pages plus a real Gmail bounce
notification and asked for all three to be fixed/built in one message.

## Scope
**Included:** all three items, each with backend + frontend changes where
applicable, fully tested.

**Explicitly scoped down, by design:**
- Bounce correlation is by recipient email address only — no per-send log
  exists anywhere in this codebase (`send_branded_email()` only renders and
  calls `send_mail()`), so "which specific email bounced" is unanswerable
  without a new sent-mail log table, which was not built here.
- IMAP credentials are a real external prerequisite this change does not
  and cannot configure — the feature ships code-complete and tested but
  inert in production until an app password/OAuth token with IMAP scope is
  provided for the sending mailbox.

## Method
Investigated before building: a parallel Explore pass confirmed (a) the
exact responsive-layout gap and the codebase's own established fix pattern
(`hidden sm:table-cell` + responsive stat grids, already used by
`StudentTable`/`UserTable`/`ExamBoardsTable`), (b) that both halves of the
audience picker — a searchable student API and a multi-select UI component
— already existed and only needed wiring together, and (c) that the email
infrastructure is a raw Gmail/Workspace SMTP relay with no bounce webhook
at all, making IMAP polling the only viable signal given the user's choice
between that and a provider migration.

Given the choices and real work volume (a new Celery Beat task, a new
model/migration, new API layers on both backends, a new admin page) this
went through `EnterPlanMode`/`ExitPlanMode` before implementation.

## Decisions & Findings
- **User's explicit choices, both asked via `AskUserQuestion`** before any
  code: audience picker = "all students + multi-select individuals, one UI
  covering both"; bounce handling = "poll the sending mailbox via IMAP,"
  not a provider switch.
- **A real parsing bug, caught only by testing against realistic MIME data,
  not by code review**: `get_payload()` on a `message/delivery-status` MIME
  part returns a list containing the sub-`Message` object directly (Python's
  email parser treats `message/*` as a container type) — not a string to
  re-parse, which raised `TypeError` on every real-shaped bounce. Writing
  the test with an actual RFC 3464 multipart structure (not a hand-rolled
  string) is what surfaced it before it ever reached a real mailbox.
- **`MultiComboBox` (shared admin UI component) was built for a static
  options list, not server-side search.** Rather than fork a bespoke
  picker, added one small, backward-compatible `onSearchChange` callback to
  the shared component — benefits any future async-search use case, not
  just this one.
- **Permission tiers matched existing precedent exactly**: bounce
  list/resolve = `IsAdminUser` (low blast radius, one row at a time, same
  tier as `SystemErrorLog`'s own resolve action); bulk-email send stays
  `IsSuperAdmin` regardless of audience mode, since a picked set can be as
  large as "everyone" and the endpoint has no way to distinguish.

## Changes Made
- **Admin Frontend**: `features/content-requests/pages/ContentRequestsPage.tsx`
  (responsive fix); `components/ui/combobox.tsx` (`onSearchChange` added to
  `MultiComboBox`); `features/communication/` (audience-picker UI in
  `CommunicationPage.tsx`, new `EmailBouncesPage.tsx`, types/api/hooks
  extended); nav entry + route for the new bounces page.
- **Admin Backend**: `apps/student_management/views.py`/`urls.py` —
  `user_ids` threaded through the bulk-email proxy views; new
  `EmailBounceListView`/`EmailBounceResolveView` proxies.
- **Student Backend**: `apps/accounts/models.py` (`User.bulk_email_recipients`
  gains `user_ids`; new `EmailBounce` model, migration `0031`);
  `apps/accounts/tasks.py` (new `poll_email_bounces` Celery task, RFC 3464 +
  prose-fallback parsing); `apps/accounts/management/commands/send_bulk_email.py`
  (`--user-ids`); `apps/internal/views.py`/`urls.py` (`user_ids` on
  `BulkEmailPreviewView`/`BulkEmailSendView`; new
  `EmailBounceListView`/`EmailBounceResolveView`); `config/settings/base.py`
  (new `IMAP_HOST`/`PORT`/`USER`/`PASSWORD` settings, new Celery Beat
  schedule entry, 15-minute interval).

## Verification
- Student Backend: 627 tests pass across `apps/accounts/`, `apps/internal/`,
  `apps/curriculum/`, `apps/replication/` (1 unrelated pre-existing
  failure, confirmed days-old and untouched by this work); new coverage: 8
  tests for `poll_email_bounces` (RFC 3464 parsing, prose fallback, dedupe,
  graceful no-op, one-bad-message-doesn't-stop-the-rest), 4 for
  `EmailBounceListView`/`ResolveView`, plus `user_ids` coverage added to the
  existing bulk-email tests.
- Admin Backend: 256 tests pass across `apps/student_management/`,
  `apps/curriculum/`, `apps/replication/`; new coverage for the bounce
  proxy views and `user_ids` forwarding.
- Admin Frontend: `tsc -b --noEmit` clean; 27 tests pass across the
  touched/new files, including a full audience-picker flow test (search →
  select → send with the right `userIds`) and the new
  `EmailBouncesPage.test.tsx`.
- **Live on staging before production, for all three**: dry-run against
  real staging data confirmed `user_ids` narrows 47 students down to an
  exact 1–2 through the full HTTP chain (not just the ORM); the migration
  applied cleanly; `poll_email_bounces` confirmed to no-op gracefully with
  IMAP unconfigured.
- **Live on production post-promotion**: migration applied; bounce list
  endpoint returns `200` through the full admin→student proxy chain;
  `/content-requests` and `/communication/bounces` both confirmed serving
  `200` on the live admin domain. `verify-service-links.sh` and
  `check_runtime_secret_drift.py` both clean.

## Follow-ups / Deferred
- **IMAP credentials are not yet provided** — `poll_email_bounces` will
  continue to no-op in production until someone generates an app
  password/OAuth token with IMAP scope for the sending mailbox and sets
  `IMAP_HOST`/`IMAP_USER`/`IMAP_PASSWORD`. This is the single thing standing
  between "built and tested" and "actually catching real bounces."
- Bounce-to-send correlation remains email-address-only by design; a true
  "which email bounced" feature needs a new sent-mail log, not attempted
  here.

## References
- `reports/HBEC-2026-10-01-subject-duplication-fix-deployed-and-data-cleanup.md`
  (immediately preceding promotion this session, same deployment pipeline)

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session
