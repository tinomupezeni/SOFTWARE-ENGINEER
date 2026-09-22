# Logging In As a Child Silently Swapped Auth Under an Already-Open Parent Wizard Tab, Producing 403s

**Date:** 2026-09-22
**Project:** HBEC
**Environment:** Staging (`hbca-vps`) — found investigating the same staging
session as `HBEC-2026-09-22-personalization-401-showed-generic-error-instead-of-login-redirect.md`
**Severity:** Medium (no data loss — the parent-only action was correctly
refused; the failure mode was a stuck page, not a security gap)
**Status:** Resolved

## Summary
Companion to the 401 investigation in the entry above, found in the same
staging access-log session but with a different, distinct cause: repeated
`403 Forbidden` on `GET /api/parent/children/{id}/` and
`POST /api/parent/children/{id}/personalization/`, for a *second* child
(`01a0c901-703d-...`) belonging to the same parent whose personalization save
for their *first* child (`01a0c901-7035-...`) had just succeeded minutes
earlier.

A 403 here can only mean one thing: `IsParent.has_permission()` — a
class-level check, run before any object is even looked up — failed. An
ownership mismatch (the wrong parent's child) would 404 instead, from
`get_object_or_404(request.user.parent_profile.children, id=child_id)`.
So the account authenticated at that moment was not a parent at all.

`StudentLoginSerializer` documents exactly this possibility: `/api/auth/login/`
is **one shared endpoint for student, parent, and child login**, chosen by an
optional `childName` field. The access log shows a successful login
(`POST /api/auth/login/ 200`) landing right between the working call and the
first 403 — consistent with the tester logging in as one of the two children
just created (verifying the password `ChildPersonalizationView` had just set)
while a browser tab was still open on the parent wizard for the *other*
child. Tokens live in shared per-origin `localStorage`; the second login
overwrote them for every open tab, including the one still showing "complete
Tembha's setup."

## Symptoms
```
POST /api/auth/login/ 200 OK                                          (parent)
POST /api/parent/children/{childA}/personalization/ 200 OK            (works)
...
POST /api/auth/login/ 200 OK                                          (child, inferred)
GET  /api/parent/children/{childB}/ 403 Forbidden
POST /api/parent/children/{childB}/personalization/ 403 Forbidden     (x3 over ~2 min)
...
POST /api/auth/login/ 200 OK                                          (parent again)
POST /api/parent/children/{childB}/personalization/ 200 OK            (works, first try)
```

## Investigation Steps

### 1. Initial Diagnosis
Confirmed both children were created in the *same* signup transaction
(`date_joined` a few hundred microseconds apart) — ruling out "child B was
added later, under a different/wrong parent" as the explanation, since both
unambiguously belong to `blakemyrazeroseven@gmail.com`.

### 2. Root Cause Analysis
```python
# apps/accounts/permissions.py
class IsParent(BasePermission):
    def has_permission(self, request, view) -> bool:
        return bool(request.user and request.user.is_authenticated
                    and request.user.is_parent and hasattr(request.user, "parent_profile"))
```
Confirmed on both failing views (`ChildDetailView`, `ChildPersonalizationView`)
via `permission_classes = [IsParent]` — a class-level gate, checked before
`_get_child()`'s per-object lookup ever runs. A 403 is therefore about *who
is logged in*, not *which child they asked for*.

```python
# apps/accounts/serializers.py, StudentLoginSerializer
"""
Serializer for student, parent, and child login (one shared endpoint).
...plus optional { childName } — when present, identifier/email is treated
as the PARENT's email and password as the CHILD's own password.
"""
```
`STUDENT/Frontend`'s `/personalization?childId=...` route (the parent wizard)
is registered in `App.tsx` with **no route guard at all** — not
`ProtectedRoute`, not `ParentRoute` — deliberately, so the student's own
post-signup flow can reach it before the session finishes hydrating (see the
companion 401 entry). That same absence of a guard means a tab already
sitting on this page has nothing telling it the shared session underneath it
just became a different, non-parent account.

## Root Cause
`/personalization` in child mode never re-validates, after mount, that the
session is still (a) live and (b) a parent's — both `ParentRoute`'s own two
checks, which this route deliberately isn't wrapped in. A same-origin login
as a different account (here, a child) silently invalidates an already-open
tab's assumption that it's still acting as the parent, and the resulting 403
had no handling beyond whatever generic inline error the page already showed.

## Prevention / Rule
**Guardrail:** the same effect added for the 401 case now also checks
`accountType !== 'parent'` once `status` resolves, mirroring `ParentRoute`'s
own two-part check (`status !== 'authenticated'` → `/login`; authenticated
but wrong role → `/dashboard`, not `/login`, since that account **is**
validly signed in, just not as a parent). One effect now covers both ways
this route's missing guard could strand a user.

## Solution

### Immediate Fix
`STUDENT/Frontend/src/features/auth/pages/PersonalizationPage.tsx` — the
same child-mode effect added for the 401 fix now branches on `accountType`
too: no session → `/login`; a session that isn't a parent's → `/dashboard`.
No backend change — `IsParent` and the 403 it produces were already correct;
the gap was entirely in the frontend having no way to notice its own
identity had changed underneath it.

### Verification
- `npm run typecheck`: clean.
- No new automated test added for this specific branch (would need a
  component-level test harness for `PersonalizationPage`, which doesn't
  exist yet — see the companion entry's note on the same gap for the 401
  fix). Manual reasoning verified against `ParentRoute`'s own, already-tested
  two-check pattern, which this mirrors exactly.

## Prevention
- [x] Code changes required — done
- [x] Documentation to update — this entry
- [ ] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — n/a

## Related Issues
- `HBEC-2026-09-22-personalization-401-showed-generic-error-instead-of-login-redirect.md`
  — same page, same investigation, the session-loss (401) half of this pair.

## References
- `STUDENT/hbec_backend/apps/accounts/permissions.py` (`IsParent`)
- `STUDENT/hbec_backend/apps/accounts/parent_views.py`
  (`ChildDetailView`, `ChildPersonalizationView`)
- `STUDENT/hbec_backend/apps/accounts/serializers.py`
  (`StudentLoginSerializer`, child-login branch)
- `STUDENT/Frontend/src/features/auth/pages/PersonalizationPage.tsx`
- `STUDENT/Frontend/src/features/auth/components/ParentRoute.tsx` (the
  pattern this fix mirrors)

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session, immediately following the 401
investigation on the same page.
