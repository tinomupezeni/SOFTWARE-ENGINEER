# A shared, content-addressed picture was served with a `private` Cache-Control

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (found in `/code-review` of PR #158, before merge)
**Severity:** Low
**Status:** Resolved

## Summary
`GET /api/v1/pictures/{picture_id}/image` sent
`Cache-Control: private, max-age=31536000, immutable`, but the route's own
docstring says these pictures are "shared, never personal... any learner may
read one". `private` tells every CDN and shared proxy not to cache the
response at all, so the one-draw-shared-by-everyone design (a picture made
once, served to every later learner) got no benefit from edge caching -
every learner's first request for a popular picture went all the way to the
harness origin.

## Symptoms
- No live incident; found by code review comparing the header to the route's
  own stated design and to this project's other byte endpoints.
- Would show as unnecessary origin load on a popular topic's cover picture,
  never as incorrect behaviour (browsers still cache it correctly for the one
  device that fetched it).

## Environment Details
- **Server/Host:** n/a (header correctness, not yet deployed)
- **Services Affected:** AGENTIC_HARNESS picture serving
- **Related Components:** `app/api/routes/pictures.py`
- **Time First Observed:** 2026-11-18, code review

## Investigation Steps

### 1. Initial Diagnosis
Compared this route's header against the project's two genuinely-personal
byte endpoints (revision infographics, `learner_files`), which correctly use
`private` since those really are per-learner.

### 2. Root Cause Analysis
Looks like the `private` directive was copied from one of those per-learner
endpoints rather than chosen for this route's actual (shared) semantics.

### 3. Key Findings
- No test pinned the header's value either way, so nothing caught the
  mismatch before review.

## Root Cause
Wrong Cache-Control visibility directive for a shared, content-addressed
resource - likely copy-pasted from a per-learner endpoint's convention.

## Prevention / Rule
**Guardrail:** changed to `public, max-age=31536000, immutable`, matching the
route's own stated design. When adding a new byte-serving endpoint, the
choice between `public` and `private` should be decided from one question
answered in this file's own CLAUDE.md-style rule-writing: "is this resource
the same for every requester, or only for the one who asked?" - and that
answer should be stated in the route's docstring (as this one already was)
so a reviewer can check the header against it directly.

## Solution

### Immediate Fix
Changed `Cache-Control` from `private` to `public` on the image route.

### Long-term Fix
None needed; this is the complete fix.

## Prevention
- [x] Code changes required
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Found alongside 5 other picture-engine bugs in the same `/code-review` of
  PR #158 - see the sibling entries dated the same day.

## References
- `AGENTIC_HARNESS/app/api/routes/pictures.py`

---

**Resolved By:** Claude Sonnet 5 (code review + fix)
**Time to Resolution:** Same session
