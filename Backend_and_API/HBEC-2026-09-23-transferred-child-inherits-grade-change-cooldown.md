# Transferred Child Inherits Grade-Change Cooldown, Blocking First-Time Setup

**Date:** 2026-09-23 (found and fixed, same session)
**Project:** HBEC
**Environment:** Reported live by the user completing setup for a
transferred child ("Tanaka") right after the previous two bugs in this same
feature were fixed and deployed
**Severity:** High — blocks completion of a transferred child's setup for
up to 30 days, with no workaround available to the parent
**Status:** Resolved (code fix prevents recurrence; already-affected
profiles still carry the inherited cooldown until it naturally expires or
is manually cleared — see Follow-ups)

## Summary
Completing setup for Tanaka (a child created by the "transfer" conversion
option) failed on the grade-selection step with:
> "Grade can only be changed once every 30 days. Please try again in 2 day(s)."

`RoleConversionService.convert_student_to_parent_and_transfer`
(`STUDENT/hbec_backend/apps/accounts/role_conversion_service.py`) does not
create a new `StudentProfile` for the child — it repoints the *original*
account's profile row (`profile.user = child_user`). Every field carries
over verbatim, including `grade_last_changed_at`: the timestamp the
*original* account got when it last changed its own grade, before ever
converting. `StudentProfile.can_change_grade()` only waives the once-per-
30-days lock when the profile has no grade set at all (a true first pick).
Since the inherited profile already has both a grade and a recent
`grade_last_changed_at`, the child's actual first-ever grade selection —
made through the parent's "Complete Setup" wizard — was read as a
rate-limited *re-change* of the pre-conversion account.

## Symptoms
- Parent clicks "Complete Setup" for a transferred child, sets a password,
  proceeds to the grade step, picks a grade different from whatever the
  child inherited → 429 with the 30-day cooldown message, no way to
  proceed.
- Silent variant, not yet reported but confirmed by code trace: if the
  parent happens to pick the *same* grade the profile already carried,
  `can_change_grade()` short-circuits (`new_grade == self.grade`) and lets
  it through with no cooldown check at all — so the bug is only visible
  when the picked grade differs from the inherited one, which is the
  normal case for an actually-different child.

## Investigation Steps

### 1. Initial Diagnosis
User reported the exact 429 message from the personalization wizard right
after confirming the "Complete Setup" flow (from the previous bug fix in
this same session) worked. Traced the cooldown message string
(`"Grade can only be changed once every 30 days"`) to
`StudentProfile.can_change_grade()`, `apps/accounts/models.py:441-485`.

### 2. Root Cause Analysis
```python
# can_change_grade()
if not self.grade:
    return True, ""  # first-ever pick is free
if self.grade_last_changed_at is not None:
    elapsed = tz.now() - self.grade_last_changed_at
    if elapsed < timedelta(days=30):
        return False, f"Grade can only be changed once every 30 days. ..."
```
```python
# convert_student_to_parent_and_transfer, before this fix
profile = user.student_profile
profile.user = child_user
profile.save(update_fields=['user'])  # everything else carries over as-is
```
`ChildPersonalizationView` (`apps/accounts/parent_views.py:239`) calls the
same shared `apply_personalization()` (`apps/accounts/personalization_service.py`)
that `StudentPersonalizationView` uses for a normal student — there is no
separate code path, so the same 30-day check applies identically whether
this is a returning student changing their grade or a brand-new child
being set up for the very first time.

### 3. Key Findings
- `grade_last_changed_at`, `level_last_reset_at` and `level_change_count`
  are rate-limit *bookkeeping* — they exist to stop one account gaming the
  limit by repeatedly flipping grade, not to represent anything about a
  learner's actual educational history. `grade`/`subjects`/mastery data
  are the real history the "transfer" option promises to preserve; the
  bookkeeping fields are not part of that promise and actively work
  against a *different* account (new `User` row, new login) that has never
  changed anything yet.
- The personalization wizard (`PersonalizationPage.tsx`) has no concept of
  "this child's profile already has transferred data" — it always runs
  the full Exam Board → Grade → Subjects → Learning Style sequence (plus a
  prepended password step in child mode) regardless of what the profile
  already contains, so it never had a chance to special-case this.
- Third independent bug found in the "Convert to Parent Account" feature
  this session, after the `FamilyMembership` field-name 500 and the
  admin-conversion wrong-HMAC-scheme 403 — all three were latent since the
  feature's original commits (`acc0e117`, `fb7b0e9c`) and surfaced only
  because this session actually exercised the feature end-to-end for the
  first time, live, rather than relying on unit tests of individual
  service methods.

## Root Cause
The transfer conversion repoints a `StudentProfile` row wholesale instead
of distinguishing "data worth preserving" (grade, subjects, mastery) from
"per-account anti-gaming bookkeeping" (the rate-limit clock fields) — the
latter should never have survived onto a distinct new account.

## Prevention / Rule
**Guardrail:** any future code that reassigns a `StudentProfile` to a
different `User` (there is currently exactly one: this transfer path) must
explicitly reset every rate-limit/cooldown bookkeeping field on that
model, not just the FK. A model-level docstring or grouped `RATE_LIMIT_FIELDS`
tuple on `StudentProfile` naming these fields explicitly would make this
enumerable rather than something a future author has to rediscover by
reading `can_change_grade`/`can_change_level` line by line, the way this
fix had to.

## Solution

### Immediate Fix
`role_conversion_service.py`'s transfer path now resets the three
bookkeeping fields in the same save as the FK reassignment:
```python
profile.user = child_user
profile.grade_last_changed_at = None
profile.level_last_reset_at = None
profile.level_change_count = 0
profile.save(update_fields=[
    'user', 'grade_last_changed_at', 'level_last_reset_at', 'level_change_count',
])
```
`grade`/`subjects`/`level`/mastery data are left untouched — only the
clock resets, so the child's transferred academic profile survives intact
while their account starts its own fresh 30-day window.

### Long-term Fix
None needed beyond the guardrail above — this is a complete fix for the
mechanism. See Follow-ups for the data-side gap it does not cover.

## Verification
- New test `test_transfer_resets_the_inherited_grade_change_cooldown`
  (`apps/accounts/tests/test_role_conversion_logging.py`): sets a grade and
  a 2-day-old `grade_last_changed_at` on the pre-conversion profile,
  confirms the transferred child's profile has the grade preserved but the
  cooldown fields cleared, and confirms `can_change_grade()` on a
  *different* grade returns `(True, "")` immediately afterward.
- Full `apps/accounts/` suite: 244/244 passing. Full suite: 814 passed (5
  pre-existing unrelated `test_dropped_messages.py` failures, unchanged).
- `ruff check` clean.

## Follow-ups
- **This fix only prevents the bug for future transfers.** A child already
  transferred before this fix (Tanaka, reported live) still carries the
  inherited `grade_last_changed_at` on their profile row and remains
  blocked until that window naturally expires, or until a one-off manual
  clear of the field is run for the affected profile(s). Not yet done —
  pending confirmation of environment (staging vs. production) before
  touching live data.
- Separately flagged by the user, not yet actioned: the parent dashboard
  card already shows an inline warning
  ("{child} can't sign in until setup is complete",
  `ParentDashboardPage.tsx` around the `needsSetup` branch) — worth
  confirming with the user whether this needs to be more prominent, since
  they initially didn't notice the existing "Complete Setup" button was
  mandatory rather than optional.

## Related Issues
Third bug found in the "Convert to Parent Account" feature this session:
- `HBEC-2026-09-23-convert-to-parent-broken-by-wrong-familymembership-fields.md`
- `HBEC-2026-09-23-admin-convert-to-parent-403-wrong-hmac-scheme.md`

## References
- `STUDENT/hbec_backend/apps/accounts/role_conversion_service.py`
- `STUDENT/hbec_backend/apps/accounts/models.py` (`can_change_grade`,
  `can_change_level`, `StudentProfile`)
- `STUDENT/hbec_backend/apps/accounts/personalization_service.py`
  (`apply_personalization`)
- `STUDENT/hbec_backend/apps/accounts/parent_views.py`
  (`ChildPersonalizationView`)
- `STUDENT/hbec_backend/apps/accounts/tests/test_role_conversion_logging.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Found and fixed same session, 2026-09-23.
