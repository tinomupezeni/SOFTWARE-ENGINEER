# Curriculum Guest-Branch Subject Cache: Validation Ran After the Cache Lookup, and `code` Had No Format Check at All

**Date:** 2026-09-16
**Project:** HBEC
**Environment:** Development (found via proactive caching audit; fixed pre-incident)
**Severity:** Medium (no confirmed exploitation — a real, structural cache-key-collision risk closed before it produced a symptom)
**Status:** Resolved

## Summary
Following a broader distributed-caching architecture review of HBEC (prompted
by recurring cache-related root causes across this dev-log's own history —
see Related Issues), `SubjectListView`'s guest-branch Redis cache
(`STUDENT/hbec_backend/apps/curriculum/views.py`,
`curriculum:subjects:guest:{level}:{code}:{grade_code}`) was audited against
the review's cache-key-collision anti-pattern and found to have two residual
issues, both pre-dating and independent of the Sept 9 guest-auth-bypass fix
already logged for this view:

1. The cache **lookup** (`cache.get(cache_key)`) ran before any guest-branch
   query-param validation — a request guaranteed to 400 still paid a Redis
   round-trip, and validation structurally belonged before cache access, not
   after.
2. The `code` query parameter had **zero validation** — unlike `level`
   (checked against `Level.choices`) and `grade_code` (checked via
   `_grade_code_is_known()`) — and flowed unchecked directly into both the
   `:`-delimited cache-key string and the DB filter. `Subject.code` is a
   plain `CharField(max_length=50)` with no DB-level format constraint, so a
   `code` value containing a literal `:` could shift the apparent structure
   of the cache key (the exact "Cache Poisoning via Key Collision" shape
   named in the review).

Confirmed as *not* a live risk before the fix: invalid `level`/`grade_code`
values already correctly returned 400 before the `cache.set()` call was ever
reached, so no genuinely garbage request could get **permanently** cached as
a wrong answer — the residual exposure was narrower than "any bad guest
request poisons the cache for an hour."

## Symptoms
None observed in production — found via proactive code audit, not a user
report or incident.

## Environment Details
- **Server/Host:** N/A (found in source, applies to all environments)
- **Services Affected:** `STUDENT/hbec_backend` (`apps/curriculum/views.py`,
  `SubjectListView`)
- **Time First Observed:** 2026-09-16, during a caching-architecture audit

## Investigation Steps

### 1. Initial Diagnosis
A caching-architecture review (prompted by a shared research document on
distributed cache design) asked for a scan of HBEC's existing cache-using
code against three recurring failure shapes seen in this dev-log's own
history: (a) two independent computations of one derived value drifting,
(b) an in-memory value with no invalidation hook, (c) a cache keyed off
untrusted input with no invalidation path. `SubjectListView`'s guest branch
matched shape (c) most directly.

### 2. Root Cause Analysis
Read the guest branch in full:
```python
cache_key = (
    f"curriculum:subjects:guest:{request.query_params.get('level', '')}:"
    f"{request.query_params.get('code', '')}:"
    f"{request.query_params.get('grade_code', '')}"
)
cached = cache.get(cache_key)          # <-- runs before any validation below
if cached is not None:
    return Response(cached, status=status.HTTP_200_OK)
...
level = request.query_params.get("level")
if level:
    if level not in valid_levels:
        return Response(..., status=400)   # validated AFTER the cache read
    ...
code = request.query_params.get("code")
if code:
    queryset = queryset.filter(code=code)   # never validated at all
grade_code = request.query_params.get("grade_code")
if grade_code:
    if not _grade_code_is_known(grade_code):
        return Response(..., status=400)
    ...
```
Confirmed `Subject.code` (`apps/curriculum/models.py`) is `CharField(max_length=50)`
with no `RegexValidator` or DB constraint restricting its character set, so
nothing upstream of this view would ever reject a `code` value containing
`:` before it reached the cache-key f-string.

### 3. Key Findings
- Invalid `level` and `grade_code` already correctly return 400 *before*
  `cache.set()` — so no permanently-poisoned wrong answer could result from
  either today; the practical risk was scoped specifically to the unchecked
  `code` param plus the lookup-before-validation ordering, not a broader
  "any bad input poisons the cache" scenario.
- The authenticated-profile branch's parallel cache key
  (`curriculum:subjects:profile:{level}:{exam_board_id}:{grade}`) is built
  entirely from server-derived values and was never at risk.

## Root Cause
Guest-branch cache-key construction and the cache lookup ran ahead of
parameter validation, and one of the three interpolated params (`code`) had
no validation at all — a structural gap that let arbitrary client input
(including the cache key's own `:` delimiter) reach the key string.

## Prevention / Rule
**Guardrail:** For any cache key built by interpolating request-supplied
values, validate every interpolated value (including its character class,
not just presence) *before* constructing the key or touching the cache —
never after. Applied here by moving all three guest-param checks
(`level`, `code`, `grade_code`) ahead of cache-key construction, and adding
a character-class check for `code` (`_SUBJECT_CODE_RE = ^[A-Za-z0-9_-]{1,50}$`)
matching the same pattern `_grade_code_is_known()` already established for
`grade_code`.

This closes the gap because a value can no longer reach the cache key (or
the queryset) without first passing a positive allowlist check — there is no
longer any unvalidated path from a query param to the key string.

## Solution

### Immediate Fix
`STUDENT/hbec_backend/apps/curriculum/views.py`:
- Added `_SUBJECT_CODE_RE = re.compile(r"^[A-Za-z0-9_-]{1,50}$")`.
- Reordered `SubjectListView.get()`'s guest branch: `level`, `code`, and
  `grade_code` are now read and validated (each still returning 400 on
  failure, unchanged behavior for already-passing requests) before the
  cache key is built or `cache.get()` is called.
- Added an inline "8 questions" contract comment on the cache-key block
  documenting source of truth, why cached, population/invalidation model,
  staleness tolerance, and now-bounded blast radius if poisoned — adopted as
  a lightweight documentation standard from the caching-architecture review,
  without adopting that review's heavier proposed machinery (transactional
  outbox, multi-level caching, circuit breakers) as disproportionate to this
  cache's actual scale and risk profile.
- New test file `apps/curriculum/tests/test_guest_cache_hardening.py` (7
  tests): valid `code` still filters correctly; a `code` containing `:` is
  rejected; an over-length/invalid-charset `code` is rejected; a rejected
  `code` never appears under any guest cache key; invalid `level`/
  `grade_code` 400 without ever touching the cache; a valid guest request is
  still cached on success (non-regression).

### Long-term Fix
None needed beyond the above — the same validate-before-cache pattern should
be the default for any future cache key built from request input in this
codebase.

## Prevention
- [x] Configuration changes needed — n/a
- [ ] Monitoring/alerts to add — none needed; the fix is structural (input
      can no longer reach the key unvalidated), not something requiring
      runtime detection
- [ ] Documentation to update — none beyond the inline "8 questions" comment
      added directly at the cache-key site
- [x] Code changes required — done (see Solution)

## Related Issues
- `Backend_and_API/HBEC-2026-09-09-*` (guest-auth-bypass fix on this same
  view — the 401-vs-guest-fallback issue this hardening is independent of)

## References
- `STUDENT/hbec_backend/apps/curriculum/views.py` — `SubjectListView`,
  `_SUBJECT_CODE_RE`, `_grade_code_is_known`
- `STUDENT/hbec_backend/apps/curriculum/tests/test_guest_cache_hardening.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — found via proactive audit, fixed and
tested within the hour
