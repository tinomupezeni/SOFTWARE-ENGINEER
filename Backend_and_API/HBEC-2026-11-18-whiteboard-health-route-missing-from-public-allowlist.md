# Whiteboard health route missing from the route-authentication test's PUBLIC allowlist

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Development (caught by CI-equivalent test suite, never reached production)
**Severity:** Low
**Status:** Resolved

## Summary
`tests/api/test_every_route_authenticates.py::test_every_route_authenticates_or_is_listed_public`
failed on the `experimental` branch after PR #157 (the Whiteboard pillar)
landed: the new `GET /api/v1/whiteboard/health` pillar probe route carries no
auth dependency (by design, like every other pillar's `/health` route) but
was never added to the test's `PUBLIC` allowlist, so the test flagged it as
an unproven, unauthenticated route.

## Symptoms
- `pytest tests/` on `experimental` reported 1 failed, 7442 passed, 79 skipped.
- The failure named `/api/v1/whiteboard/health` as an unauthenticated route
  not listed in `PUBLIC`.

## Root Cause
Every pillar in the harness registers an unauthenticated `GET
/api/v1/<pillar>/health` liveness probe, and this test's `PUBLIC` dict is a
hand-maintained allowlist of every route that is deliberately unauthenticated,
each with a one-line reason. PR #157 added the Whiteboard pillar's router
(including its own `/health` route, following the same pattern as every
other pillar) but didn't update this test file, since the route list and the
test file are not mechanically linked — adding a route doesn't force an
update to the allowlist.

## Prevention / Rule
**Guardrail:** none beyond the test itself, which already does its job
correctly (it's a fail-closed allowlist — a new unauthenticated route must be
explicitly proven safe or the test fails). The real guardrail is procedural:
when adding a new pillar, its `/health` route must be added to `PUBLIC` in
the same PR, since the pattern is identical for every pillar already listed.

This closes the gap because the test already catches every other case of an
unauthenticated route with no entry; the only thing missing was remembering
to add the one-line allowlist entry for a brand new pillar.

## Solution

### Immediate Fix
Added `("GET", "/api/v1/whiteboard/health"): "pillar probe"` to `PUBLIC` in
`tests/api/test_every_route_authenticates.py`, matching every other pillar's
entry exactly.

```bash
cd AGENTIC_HARNESS && .venv/bin/python -m pytest tests/api/test_every_route_authenticates.py -p no:schemathesis -q
# 3 passed
```

### Long-term Fix
None needed — this is a one-line allowlist entry, not a design gap.

## Prevention
- [x] Code changes required (done)
- [ ] Configuration changes needed
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues
- Surfaced while finishing a 9-PR code-review-and-fix pass (#149–#158) on
  HBEC; this was a leftover from PR #157 (the Whiteboard pillar), caught by
  the full backend test suite run while verifying the final merge of all 9
  PRs into `experimental`.

## References
- `AGENTIC_HARNESS/tests/api/test_every_route_authenticates.py`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Minutes
