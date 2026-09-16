# "I Deleted My Account and Created a New One, But My Old Conversations Are Still There" — Because Self-Service Deletion Never Existed, and Google Sign-In Silently Re-Matches by Email/google_id With No is_active Check

**Date:** 2026-09-16
**Project:** HBEC
**Environment:** Production
**Severity:** Critical (account-identity and data-lifecycle guarantee that plainly didn't exist; also a latent auth gap — a deactivated account could still be signed back into via Google)
**Status:** Resolved

## Summary
A real user (`mutsa.mutepfa@students.uz.ac.zw`) reported that after "deleting" their
account and "creating a new one" with the same email, their previous Friday/Learning
Guide conversation history was still present. Investigation found there is **no
self-service account-deletion feature anywhere in HBEC** — not in the student
backend, not in either frontend, not in either mobile app. Direct production
database inspection confirmed the account was never actually removed or
recreated: one `User` row, `date_joined` and `StudentProfile.created_at` both
2026-09-09, continuous activity straight through to the most recent login, no
gap. Harness's own database showed real Learning Guide sessions and
cross-pillar memory records tied to that same unchanged UUID across the same
span — a normal, continuous history, not a cross-account leak.

The most likely mechanism: the user used **Sign up with Google** (the first,
most prominent option on the signup page) believing it would start fresh.
`GoogleAuthView` looks up an existing account by `google_id` first, then by
`email` — either match silently logs the caller into the **existing** row,
with no `is_active` check at all (unlike the email/password login path, which
does check it). Whatever the user believed "deleting" did, there was nothing
for it to call, and Google Sign-In just found their one, only-ever account
again.

## Symptoms
- Student reports: deleted account → signed up again with the same
  email → old AI conversation history from before the "delete" is present in
  the "new" account.
- No error, no visible failure anywhere in the flow — from the user's
  perspective, signup appeared to succeed normally both times.

## Environment Details
- **Server/Host:** Production (`hbca-vps`, `/opt/hbec`)
- **Services Affected:** `STUDENT/hbec_backend` (account lifecycle),
  `AGENTIC_HARNESS` (conversation/memory history, confirmed NOT the cause —
  see Investigation), `ADMIN/adminBackend` (the one real deletion path that
  does exist, admin-only, and — separately confirmed — never left an audit
  trail or cascaded to other services)
- **Time First Observed:** 2026-09-16, reported by the user directly

## Investigation Steps

### 1. Initial Diagnosis
Checked production directly for the reported email:
```python
User.objects.filter(email='mutsa.mutepfa@students.uz.ac.zw')
# -> exactly one row: id=01a084b2-b79f-7a9e-a4f8-da466dc02b6a, is_active=True,
#    date_joined=2026-09-09 05:45:00, last_login=2026-09-14 13:14:45
```
`StudentProfile.created_at` for that same row: `2026-09-09 05:45:00.71` — created
in the same request as `date_joined`, never touched since. No discontinuity
consistent with a delete-then-recreate cycle.

### 2. Root Cause Analysis
Searched the entire codebase for any account-deletion UI or endpoint reachable
by a student: none exists. `STUDENT/hbec_backend/apps/accounts/urls.py` lists
every self-service endpoint (signup, login, google, logout, personalization,
appearance, companion, privacy, avatar, tour, change-password,
forgot/reset-password) — no delete/deactivate route. Neither frontend's
Settings feature has a delete-account UI. `User` had no soft-delete field at
all (`is_deleted`/`deleted_at`) before this fix.

Two real deletion paths exist, but both are **admin-only**:
- Admin Frontend → `ADMIN/adminBackend/apps/student_management/views.py`
  `StudentDeleteView` (`IsSuperAdmin`) → HMAC call → Student Backend's
  `apps/internal/views.py` `StudentUserDetailView.delete` — previously a
  genuine `user.delete()` hard delete.
- Django admin console's default bulk `delete_selected` action — same effect,
  bypasses the API entirely.

Confirmed via the production row's continued existence, correct `id`, and
original `date_joined` that **neither path was ever successfully invoked
against this exact account** — a successful hard delete cannot leave that
trail. (Separately: if the account's own admin used the admin-side delete on
themselves, believing it was self-service, the outcome — an untouched
row — is the same either way; there is no durable log to distinguish "wrong
target" from "never completed," since the only record would have been
container stdout, already rotated away by an unrelated deploy restart before
this was investigated.)

Read `GoogleAuthView` (`STUDENT/hbec_backend/apps/accounts/views.py:459-469`,
pre-fix):
```python
try:
    user = User.objects.get(google_id=google_id)          # Case 1
except User.DoesNotExist:
    try:
        user = User.objects.get(email=email)               # Case 2 — links & logs in
        user.google_id = google_id
        ...
    except User.DoesNotExist:
        ...                                                  # Case 3 — genuinely new
```
Neither Case 1 nor Case 2 checked `is_active` — unlike
`StudentLoginSerializer` (`serializers.py:399`, `"Account is disabled"` for
email/password login), which already did. This confirmed a real user of
this exact account, `auth_provider=google`, `google_id` set — created via
Google from day one — would land straight back in Case 1 on any repeat
"Sign up with Google," unconditionally.

### 3. Key Findings
- Harness's `friday_sessions`/`friday_messages`/`learning_guide_sessions`/
  `agent_memory_records` are keyed only by `student_id` (a plain UUID column,
  no FK, no email/name field anywhere in those schemas) — confirmed there is
  no PII in Harness's own tables, and no cross-service "leak" mechanism was
  needed to explain the symptom: the UUID simply never changed.
- `NOTIFICATIONS`' `Notification`/`ContentGapReport` tables are the same
  shape — `user_id` only, no PII columns.
- The admin-only hard-delete path, even when actually used, never notified
  Harness/Notifications/Payments to clean up their own copies of a deleted
  user's data, and left no audit record of who deleted whom or when.

## Root Cause
Two independent gaps compounded into the reported symptom: (1) self-service
account deletion does not exist as a feature, so nothing the user did could
have removed their account; (2) `GoogleAuthView`'s existing-account lookups
never checked `is_active`, so even a deactivated account would still be
silently re-entered by Google Sign-In with no visible difference to the
caller. Separately, the admin-only deletion path that *does* exist was a
true hard delete with no audit trail and no downstream cleanup — a genuine
data-integrity gap in its own right, just not the one that produced this
specific report.

## Prevention / Rule
**Guardrail:** Account deletion must (a) actually be reachable and (b)
leave a permanent, unambiguous signal that a real login can never again
match — not `is_active=False` alone (which a differently-motivated
deactivation could also set), and not merely "the row is gone" (which
destroys the exact history a distributed system needs to answer "did this
actually happen"). The fix implemented here is `User.anonymize_and_deactivate()`
— a single method every deletion path must go through, which scrubs every
identifying field (email, name, phone, google_id, password) and sets a
dedicated `deleted_at` timestamp, while deliberately leaving every
FK'd/keyed-by-UUID data source (telemetry, practice sessions, subscription,
Harness conversation/memory history) untouched as anonymous signal. Because
`email` and `google_id` are rewritten to values derived from the row's own
id, no future login attempt — by any path — can ever match this row again,
which is what closes the `GoogleAuthView` gap structurally rather than only
at the one call site it was also patched at.

This closes the gap because the actual failure was never "cascade cleanup is
incomplete" — it was that there was nothing to answer "is this account
really gone" at all. A field that's cleared everywhere it's checked, plus
authentication paths that already refuse a plainly-disabled account, removes
the ambiguity a `date_joined` timestamp had to be used to reconstruct after
the fact.

## Solution

### Immediate Fix
1. **`User.anonymize_and_deactivate()`** (`STUDENT/hbec_backend/apps/accounts/models.py`)
   — new method, new `deleted_at` field (migration `0027_user_deleted_at.py`).
   Scrubs email/username/first_name/last_name/phone_number/google_id,
   `set_unusable_password()`, `is_active=False`, `deleted_at`/
   `sessions_revoked_at` set to now. Idempotent.
2. **`StudentUserDetailView.delete`** (`apps/internal/views.py`) now calls
   `user.anonymize_and_deactivate()` instead of `user.delete()`. The student
   list and stats views (`StudentUserListView`, `StudentUserStatsView`)
   exclude `deleted_at__isnull=False` accounts, so a deleted student
   disappears from every admin-facing count/list exactly as before, without
   the row actually being gone.
3. **`GoogleAuthView`** (`apps/accounts/views.py`) now checks `is_active` on
   both the `google_id` match and the `email` match, returning `"Account is
   disabled"` — mirroring the email/password login path, and covering the
   case of a merely-deactivated (not deleted) account too.
4. **Admin-side audit trail** (`ADMIN/adminBackend/apps/student_management/views.py`
   `StudentDeleteView`) — snapshots the student's email/name via a GET
   before deleting (best-effort; a failed snapshot doesn't block the
   delete), then writes an immutable `AuditEvent`
   (`ADMIN/adminBackend/apps/governance/models.py`, already enforces
   append-only via overridden `save()`/`delete()`) recording the acting
   admin, the target student id, an optional free-text reason from the
   request body, and the before-snapshot. This is now the durable record
   that container logs never were.
5. Admin Frontend's delete-confirmation dialogs (`StudentManagementPage.tsx`,
   `StudentDetailPage.tsx`) gained a reason field wired to the new audit
   trail, and their copy was corrected — the old text ("this will
   permanently remove their practice data and projects") was no longer
   true once deletion stopped hard-deleting anything.

### Long-term Fix
None needed beyond the above — this closes both the reachability gap and the
auth re-match gap structurally, not just at the one path that produced this
report.

## Prevention
- [x] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — consider alerting on `AuditEvent` rows with
      `action="student_deleted"` and no `reason`, as a light nudge toward
      always recording why
- [ ] Documentation to update — note in account-lifecycle docs that
      `anonymize_and_deactivate()` is the only sanctioned way to remove a
      student account; a direct `user.delete()` anywhere is a regression
- [x] Code changes required — done (see Solution)

## Related Issues
- None yet filed.

## References
- `STUDENT/hbec_backend/apps/accounts/models.py` — `User.anonymize_and_deactivate`
- `STUDENT/hbec_backend/apps/accounts/migrations/0027_user_deleted_at.py`
- `STUDENT/hbec_backend/apps/accounts/views.py` — `GoogleAuthView`
- `STUDENT/hbec_backend/apps/internal/views.py` — `StudentUserDetailView.delete`,
  `StudentUserListView.get`, `StudentUserStatsView.get`
- `ADMIN/adminBackend/apps/student_management/views.py` — `StudentDeleteView`
- `ADMIN/adminBackend/apps/governance/models.py` — `AuditEvent`
- `AGENTIC_HARNESS/app/friday/models.py` — confirmed no PII, UUID-only keying

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — root-caused via direct production
database inspection plus code investigation, fixed and tested within a few
hours of the report
