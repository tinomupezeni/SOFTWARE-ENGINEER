# Resolved/Pending Workflows, Bulk User Communication, and a Dedicated Notifications Page

**Date:** 2026-10-01
**Project:** HBEC
**Type:** Feature (cross-service, three distinct sub-features from two ProjectFlow tickets)
**Status:** Completed — verified end-to-end on staging with real data

## Summary
Two HBCA ProjectFlow tickets ("Add resolved/pending function for content
requests" and "All user communication") turned into three shipped pieces
after a round of clarification surfaced that the straightforward reading of
each ticket was incomplete or pointed at the wrong page entirely:

1. **Feedback resolved/pending** — a status filter and resolved/pending
   metric tiles on the admin Feedback page (confirmed by the user to be the
   same ask as a separate, already-open "Status Filter and Metric card"
   ticket).
2. **Content Requests resolved/pending** — the *actual* target of the
   "content requests" ticket, discovered mid-build: a wholly separate admin
   page (`/content-requests`, content-gap-reports) already existed with that
   exact name and had no resolve concept at all. Built there instead, in
   addition to the Feedback work already shipped.
3. **Bulk "message all users" + a dedicated Notifications page** — the
   user's own clarification on "all user communication" expanded it to
   include making the Dashboard and notifications reachable without a
   subscription, which investigation showed was already true; the one real
   gap was a full-history notifications destination (only a bell popover
   existed).

## Context / Trigger
User picked two tickets from a "pull my HBEC tasks" request:
"lets forcus on these 2" (Feedback-adjacent resolved/pending, and "All user
communication"). Two pivots happened mid-session, both driven by things
found that contradicted the initial framing rather than assumed:
- Clarifying "All user communication" surfaced that the user actually meant
  reaching students with **no subscription filter at all**, and separately
  wanted the Dashboard/notifications reachable without a subscription —
  prompting a full investigation (3 parallel research agents) before any
  code was written.
- Mid-build, discovering a literally-named, fully-built "Content Requests"
  admin page (unrelated to Feedback) made the original "same as Status
  Filter and Metric card" confirmation look like it was answered without
  full information — re-confirmed with the user, who redirected the work
  there.

## Scope
**Included:** all three pieces above, each with their own backend changes,
tests, and (where applicable) frontend UI — see Changes Made.

**Explicitly excluded / found-but-not-built:**
- Parent accounts from the bulk-email recipient set (students only, by
  design — flagged as a choice to revisit, not built either way without
  being asked).
- A persistent second "notifications" icon in the student header — the
  bell already does that job; a "View all" link in its popover was judged
  sufficient rather than adding a near-duplicate icon.
- Any actual subscription-gating code changes — investigation (not
  assumption) confirmed `/` and `/dashboard` were never gated by
  `SubscriptionGate`, and the NOTIFICATIONS service has no subscription
  check anywhere. Nothing needed building there.
- A real full-scale bulk-email send on staging (47 real accounts) —
  verified via the preview endpoint and the management command's
  `--dry-run` instead, to avoid emailing every staging student as a side
  effect of testing.

## Method
Investigated before building, twice: once with 3 parallel Explore agents
(subscription gating, the notifications system's actual read/unread state,
the feedback admin UI + bulk-email infra patterns) before writing the
original plan, and a second time mid-build when the Content Requests page
surfaced — stopped, re-confirmed with the user rather than guessing which
of two real, similarly-named things the ticket meant.

Every new piece mirrors an existing established pattern rather than
inventing one: the bulk-email Celery task mirrors `send_renewal_reminders`'
per-recipient try/except shape; `User.bulk_email_recipients()` is one
classmethod shared by the preview-count endpoint and the actual send so
they can't drift; the Content Requests resolution model follows this
service's own existing `ContentGapReport` conventions exactly (same file,
same column style); the Notifications page reuses `useNotifications()`
completely unchanged — no new backend work for that piece at all.

Verified against real data at every layer, not container-health-only:
direct ORM queries cross-checked against the real HTTP endpoints on
staging, a real `resolve` call against real content-gap data (16 real
reports, one genuinely flipped from pending to resolved and the badge
count correctly dropped), and the bulk-email preview/dry-run confirming
the exact real recipient count (47) without sending anything.

## Decisions & Findings
- **A missing JSON key is not `False` in Postgres — a real bug caught by
  the new tests, not assumed correct.** `payload__is_resolved=False` (and
  `.exclude(payload__is_resolved=True)`) both silently return nothing for
  rows where the key is absent, because SQL's three-valued NULL logic makes
  `NOT(NULL = TRUE)` unknown, not true. Fixed with `isnull=True` checks,
  which are real `IS NULL` comparisons. Same root cause hit twice
  independently — once in Django ORM (Feedback), once avoided from the
  start in SQLAlchemy (Content Requests, written after the Feedback bug was
  already found and fixed) by using a dedicated `_subject_id_matches`
  helper instead of reusing the column-to-column join helper against a
  literal value.
- **Content-gap resolution auto-reopens by design.** A group reads as
  resolved only while `resolved_at >= last_requested_at` for that group — a
  student reporting the same gap again after an admin "fixed" it is new
  information, not something a stale flag should hide. Applied consistently
  to both the summary's `is_resolved` field and the nav badge's
  outstanding-count.
- **`IsSuperAdmin` for the bulk-email send, `IsAdminUser` for everything
  else this session has touched** — the one deliberate permission-tier
  deviation, justified by blast radius: this is the only action that can
  reach the entire user base in one call, matching this file's own general
  policy ("read operations require IsAdminUser, write operations require
  IsSuperAdmin") rather than the narrower exception the single-student
  composer earned.
- **Dashboard/notifications-without-subscription was already shipped,
  just undiscovered.** Confirmed directly by reading the route config and
  grepping the NOTIFICATIONS service for any subscription check (found
  none) rather than taking the user's framing at face value — saved from
  building a redundant fix for something that already worked.

## Changes Made
- **Student Backend**: `apps/internal/views.py` (`FeedbackListView`/
  `FeedbackStatsView` status filtering, `BulkEmailPreviewView`,
  `BulkEmailSendView`), `apps/accounts/models.py`
  (`User.bulk_email_recipients`), `apps/accounts/tasks.py`
  (`send_bulk_email_task`), `apps/accounts/management/commands/
  send_bulk_email.py` (new), `core/branded_email.py` (`message_to_html`
  extracted for reuse).
- **Admin Backend**: `apps/feedback/views.py` (status param passthrough),
  `apps/student_management/views.py` (`BulkEmailPreviewView`/
  `BulkEmailSendView` proxies).
- **NOTIFICATIONS** (FastAPI): `app/notifications/models.py`
  (`ContentGapResolution`), `schemas.py`, `router_content_gap.py`
  (`resolve_content_gap`, status-filtered/resolution-aware `get_summary`,
  resolution-aware `get_outstanding_count`), migration `0006`.
- **Admin Frontend**: `features/feedback/` (status filter + 2 stat tiles),
  new `features/communication/` (compose + confirm + send page, `/communication`
  route + nav entry), `features/content-requests/` (status filter, stat
  tiles, per-row resolve action + badge).
- **Student Frontend**: new `features/notifications/pages/NotificationsPage.tsx`
  (`/notifications` route, ungated), "View all" link added to
  `NotificationBell`.
- Commits: `63793375`, `006d2ce3`, `ed0ce277`, `d67c58ea`, `adb84274`,
  `f43f4711` — six commits, one per natural boundary (backend, each
  frontend piece separately) rather than one giant commit, since most of
  the pieces touch entirely disjoint files.

## Verification
- Student Backend: new tests for feedback status filtering (7, including
  the NULL-logic regression) and bulk email (6 command + 4 view = 10);
  full `apps/internal/` + `apps/accounts/` suites re-run clean. `ruff` and
  `manage.py check` clean.
- Admin Backend: 8 new proxy tests (preview + send, including the
  `IsSuperAdmin` permission check); `ruff` and `manage.py check` clean.
- NOTIFICATIONS: 8 new tests (resolve, auto-reopen, status filter,
  outstanding-count exclusion); full service suite (94 tests) re-run
  clean; `ruff` clean.
- Admin Frontend: 21 new/updated component tests across feedback,
  content-requests, and communication; `tsc -b --noEmit` and `eslint`
  clean.
- Student Frontend: 6 new tests (NotificationsPage + the bell's new "View
  all" link); full notifications suite (40 tests) re-run clean; `tsc -b
  --noEmit` and `eslint` clean.
- Staging (real data, not container-health-only): all 9 affected
  containers rebuilt, recreated, healthy, no errors in logs. Real signed
  requests confirmed feedback resolved=5/pending=2 matching a direct DB
  query exactly; a real `resolve` call against one of 16 real content-gap
  reports flipped it from pending to resolved and the outstanding-count
  badge correctly dropped to 0; bulk-email preview and `--dry-run` both
  independently confirmed 47 real recipients; the new `/notifications`
  route and its JS chunk both confirmed present and serving (`200`) on the
  live staging domain, same for `/communication`, `/feedback`, and
  `/content-requests` on the admin domain.
- GitHub Actions showed no run at all for this push (a different failure
  shape than the billing-block annotation seen on 09-28/09-29/09-30) —
  deployed manually per `docs/STAGING_TO_PRODUCTION_RUNBOOK.md` without
  further diagnosis, since the manual path already exists and is proven.

## Follow-ups / Deferred
- Not promoted to production — staging only, per this session's scope.
- No actual full-scale bulk email was sent to staging's 47 real accounts
  during verification (deliberate) — if a true full-send rehearsal is
  wanted before trusting this at production scale, that's a separate,
  explicit step.
- Whether parent accounts should also receive "all user communication" is
  an open product question, not resolved here — currently students only.
- GitHub Actions returning *no run at all* (rather than a billing-blocked
  stub) for this push is a new and different symptom from the last three
  sessions' billing block — worth the account owner's attention alongside
  the already-flagged billing issue, though not investigated further here
  since the manual path is proven and unblocking.

## References
- `HBEC-2026-09-30-adopted-paper-consistency-check.md` and
  `HBEC-2026-09-29-custom-email-composer.md` — the `send_branded_email`/
  `message_to_html` infra and `send_renewal_reminders` pattern this session
  built directly on top of.

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session
