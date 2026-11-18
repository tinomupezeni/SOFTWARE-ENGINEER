# Community-paper reuse never matched on topics given in a different order

**Date:** 2026-11-18
**Project:** HBEC
**Environment:** Production (student backend)
**Severity:** Medium
**Status:** Resolved

## Summary
`reusable_community_paper()` (the cost-saver intercept that serves an
existing community paper instead of paying for an LLM generation) matched a
request's `topics` against a stored paper's `topics` with exact JSONB array
equality. The field is a plain list, order-sensitive on comparison, and
nothing sorted either side — so two requests asking for the same topics in a
different order, or a request matching a paper whose topics were stored in a
different order than requested, silently never matched. The intercept fell
through to a full (costly) LLM generation every time, with no error and no
log line pointing at the cause.

## Symptoms
Not reported by a user directly — found during code review of PR #155. The
observable effect in production would be a lower-than-expected community-paper
hit rate with no visible error: every miss looks identical to "no matching
paper exists yet."

## Environment Details
- **Server/Host:** Student backend (Django), `apps/practice/community.py`
- **Services Affected:** `POST` paper-generation request path
  (`apps/ai_gateway/views.py`), the cost-saver intercept
- **Related Components:** `apps/practice/models.py` (`Paper.topics`
  `JSONField`), `apps/internal/views.py` (where a harness-generated paper's
  `topics` is first written on sync)
- **Time First Observed:** 2026-11-18, during code review

## Investigation Steps

### 1. Initial Diagnosis
`reusable_community_paper()`'s docstring claimed "topics: Must match exactly
(the client sends a sorted list)" — an assumption, not an enforced contract.

### 2. Root Cause Analysis
Traced where `topics` enters the system on both sides of the comparison:
- Write side: `apps/internal/views.py`, the harness-paper sync endpoint,
  stored `data.get("topics", [])` verbatim — whatever order the harness sent.
- Read side: `apps/practice/community.py`, `Paper.objects.filter(topics=list(topics))`
  — whatever order the *client* sent in the generation request.
Neither side normalized order, and nothing else in the request pipeline
(`apps/ai_gateway/serializers.py`'s `topics` is a plain unsorted `ListField`)
did either.

### 3. Key Findings
- The docstring's claimed invariant ("the client sends a sorted list") was
  never enforced anywhere in the request pipeline.
- The comparison is exact-list equality on a JSONB array, which Postgres
  treats as order-sensitive.
- No log line distinguished "no community paper exists" from "a matching
  paper exists but didn't match because of topic order" — the failure mode
  was invisible from logs alone.

## Root Cause
Two independent writers of the same logical "topic set" (the generation
request and the paper-sync write) each assumed the other side would arrive
pre-sorted, and neither actually sorted anything.

## Prevention / Rule
**Guardrail:** any field compared by *exact* equality across two independently
produced writes must be normalized at both write sites, not assumed consistent
by convention. A docstring describing an invariant ("the client sends a sorted
list") is not a guardrail; sorting the value at the point of comparison (and
at the point of storage) is.

This closes the gap because it makes both sides derive the same canonical
form from the same input, rather than relying on an unenforced assumption
about caller behavior.

## Solution

### Immediate Fix
Sort `topics` at both the query site (`community.py`) and the write site
(`apps/internal/views.py`, where a harness paper's `topics` is first stored),
so future papers compare consistently regardless of request order.

```python
# apps/practice/community.py
topics=sorted(topics),   # was: topics=list(topics)

# apps/internal/views.py
"topics": sorted(data.get("topics", [])),   # was: data.get("topics", [])
```

### Long-term Fix
No data migration was run for already-stored community papers whose `topics`
were saved in an arbitrary order before this fix — those remain unmatched
against a differently-ordered request until they're regenerated or a
one-off migration sorts their `topics` field. Given community papers churn
(generated regularly, not static reference data), this was judged not worth
a migration; flag if the hit-rate metric (if one exists, or should be added)
doesn't recover as expected.

## Prevention
- [ ] Add a metric/log line distinguishing "no candidate exists" from "a
      candidate was filtered out by a field mismatch" in `reusable_community_paper`
- [ ] Consider a one-off migration to sort existing papers' `topics` if the
      hit-rate doesn't recover from new traffic alone
- [x] Code changes required (done)

## Related Issues
- Found during code review of PR #155 (`feat/picture-engine`), alongside a
  missing heritage-source citation on `GRANARY_BUILD` (separate entry) and an
  already-resolved bool-as-int bounds check (fixed in PR #149, inherited by
  this branch's merge from `experimental`).

## References
- `apps/practice/community.py` module docstring (describes the cost-saver
  intercept's history, including the earlier "very few questionz" bug)

---

**Resolved By:** Claude Sonnet 5 (agent session, on behalf of tinomupezeni)
**Time to Resolution:** Same session as discovery
