# `/api/internal/curriculum/` Silently 404'd on Every Real Harness Call

**Date:** 2026-09-14
**Project:** HBEC
**Environment:** Production
**Severity:** Low (best-effort enrichment, never surfaced to a student)
**Status:** Resolved for the majority case; a smaller residual gap
(genuinely fuzzy topic labels) documented and left open

## Summary
Found incidentally while investigating an unrelated marking 404: the
harness's log was full of `syllabus_retrieval_failed` warnings hitting
`http://student-backend:8000/api/internal/curriculum/?topic_id=...&subject=...`
with a 404, for every subject/topic combination logged, not
intermittently. The harness's only caller of this endpoint
(`app/revision/nodes.py`'s `retrieve_curriculum`) sends a subject *name*
("History", "Agriculture") in the `subject` param and a printed-paper-
style label ("Paper 1: History of Zimbabwe", "1: Sociological Research
Methods") in `topic_id` — it never has a subject code or a real `Topic`
id available at that call site. The endpoint's subject filter only
matched `subject__code`, so a name always produced zero rows before the
topic even got compared.

## Symptoms
- No user-facing symptom. `retrieve_curriculum` catches the exception
  and logs a warning (`nodes.py:102`); revision notes generation
  continues using the separate Qdrant semantic-search path
  (`curriculum_content`), just missing `syllabus_points` citations.
- Log noise: a `syllabus_retrieval_failed` warning on essentially every
  revision-notes request that names a topic, indefinitely.

## Environment Details
- **Server/Host:** `STUDENT/hbec_backend`, `apps/internal/views.py` —
  `CurriculumContextView`
- **Services Affected:** revision-notes generation's syllabus-point
  enrichment (`AGENTIC_HARNESS/app/revision/nodes.py`)
- **Time First Observed:** noticed 2026-09-14 while grepping harness
  logs for an unrelated marking-404 investigation; root cause is as old
  as this endpoint's title/code fallback (the comment claiming "Harness
  sends topic titles (not UUIDs) — try UUID first, then title/code" was
  already there, but never actually worked for real harness traffic)

## Investigation Steps

### 1. Initial Diagnosis
Traced the failing URL back to `app/revision/nodes.py:91-94`:
```python
data = await client.get_curriculum_context(
    topic_id=topic,       # a display-name string, not an id
    subject=subject or None,
)
```
`topic` and `subject` both trace back to free-text fields on
`GenerateNotesRequest` (`app/revision/schemas.py`) — there is no
topic-id/UUID anywhere in this request path, and no subject-code either.

### 2. Root Cause Analysis
`CurriculumContextView.get()` (`apps/internal/views.py`, before this
fix):
```python
qs = Topic.objects.select_related("subject")
if subject_code:
    qs = qs.filter(subject__code=subject_code)   # "History" != any code
...
topic = qs.filter(Q(title__iexact=topic_id) | Q(code=topic_id)).first()
```
Confirmed live on staging: `Subject.objects.filter(name__icontains="History")`
has `code="6006 -5"` — nothing close to the string `"History"` the
harness actually sends as `subject`. The subject filter alone reduced
every real call to zero rows, before the topic label was even compared.

### 3. Key Findings
- Some topics' stored titles already *include* the printed-paper prefix
  the harness sends (`Topic.title == "Paper 1: History of Zimbabwe"`
  verbatim on staging) — so an exact-match `title__iexact` would have
  worked for those, had the subject filter not already zeroed the
  queryset first. The subject-name mismatch was the dominant cause, not
  the topic-label formatting.
- Not every topic label is this clean: `"SOIL SCIENCE"` (from the
  harness) has no exact match against any stored title (closest are
  `"SOIL AND WATER MANAGEMENT"` and `"3. Soil Science and Land Use"` on
  two different Agriculture subjects) — a genuinely fuzzy mismatch, not
  fixable by prefix-stripping alone.
- Multiple `Subject` rows can share the same `name` across grade/paper
  variants (six rows named "Agriculture..." on staging, differing by
  code/level) — matching by name alone is ambiguous when several
  variants exist; `.first()` picks one arbitrarily.

## Root Cause
The subject filter matched only `Topic.subject.code`, but the endpoint's
only real caller has never had a subject code to send — only a subject
name. Additionally, the topic-label fallback only did an exact
case-insensitive match, which fails once the harness's label carries
printed-paper numbering that the stored title doesn't (or vice versa).

## Prevention / Rule
**Guardrail:** an internal API's query-param naming (`subject=`,
`topic_id=`) should be validated against what its actual caller sends,
not assumed from the param name — a code review or contract test that
asserts "harness sends X, backend matches on X" for every one of these
harness↔backend internal endpoints would have caught this before it ever
shipped, since `subject_code` was never once actually a code.

This closes the gap because the failure mode here was two systems
agreeing on a URL shape but silently disagreeing on what the values
inside it meant.

## Solution

### Immediate Fix
`apps/internal/views.py`, `CurriculumContextView.get()`:
- Subject filter now matches `subject__code__iexact` OR
  `subject__name__iexact`, so a name-only caller (the only real one)
  works.
- Added a second topic fallback: strip a leading `"Paper N:"` / `"N:"`
  prefix (regex) from `topic_id` and retry the title/code match before
  giving up.

6 new tests in `apps/internal/tests/test_curriculum_context.py` cover:
subject matched by name, by code, topic labels with a "Paper N:" prefix
and a bare "N:" prefix, a genuinely unknown topic still 404ing, and a
real UUID still resolving directly. Full `apps/internal` + `apps/curriculum`
suites (95 tests) pass.

Verified live on staging against real synced curriculum data: the exact
previously-failing production request
(`topic_id=Paper 1: History of Zimbabwe&subject=History`) now returns
200 with the correct topic. `topic_id=SOIL SCIENCE&subject=Agriculture`
still 404s — documented below as the residual gap.

Deployed to staging only so far (student-backend, student-worker,
student-beat, tag `sha-3e21974`); production promotion pending — this is
a low-severity, best-effort-only fix with no user-facing symptom, so it
does not need the same urgency as the marking-404 work above, but should
still go out in the next normal promotion window.

### Long-term Fix
Genuinely fuzzy topic labels (no exact match even after prefix-stripping,
e.g. "SOIL SCIENCE" vs. "SOIL AND WATER MANAGEMENT") and ambiguous
same-name subjects across grade variants would need real fuzzy matching
(the harness already depends on RapidFuzz for exactly this kind of
matching elsewhere — `app/exam_practice/marking/` — the same approach
could be reused here) plus a `level`/grade disambiguator on the subject
match. Not attempted: this endpoint is best-effort enrichment with no
visible failure mode today, so a heavier fuzzy-matching pass isn't
justified until this is shown to matter for note quality.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — a metric on this endpoint's 404 rate
      would have surfaced this on day one instead of it going unnoticed
- [ ] Documentation to update — none yet
- [x] Code changes required — done, for the majority case; fuzzy-match
      gap left open

## Related Issues
- Found while investigating the AI-paper marking 404s
  (`HBEC-2026-09-14-ai-paper-marking-404-missing-harness-paper-id.md`) —
  unrelated bug, same log-grepping session.

## References
- `STUDENT/hbec_backend/apps/internal/views.py` — `CurriculumContextView`
- `AGENTIC_HARNESS/app/revision/nodes.py` — `retrieve_curriculum`,
  `identify_topic`
- `AGENTIC_HARNESS/app/shared/internal_client.py` — `get_curriculum_context`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session as discovery (verified live on
staging; production promotion pending, low urgency)
