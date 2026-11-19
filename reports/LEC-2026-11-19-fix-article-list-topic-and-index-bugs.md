# Fix two High-severity LEC-091/092 review findings, deployed as LEC-093

**Date:** 2026-11-19
**Project:** LEC Biotec
**Type:** Bug fix (follow-up to a shipped release)
**Status:** Completed

## Summary
Fixed and shipped two High-severity bugs that the `/code-review` of
PR #63 (LEC-092) had found but that never reached the merge decision —
a topic-filtered article list could show a card under a different
section's headline/topic/cover when a page had two visible `article`
sections, and the article-listing JSONB query had no supporting index.
Both were already live in production by the time they were found. Fixed
on a new PR (#65, LEC-093), deployed and migrated the same day.

## Context / Trigger
During the LEC-091/092 ship (see
`reports/LEC-2026-11-19-ship-lec-091-092-deploy-and-qa-handoff.md`), the
task-notification summary from the background `/code-review` run did not
mention these two findings, even though the agent had independently
written them to the dev-log as "Investigating." They surfaced only when
staging the dev-log commit after deploy and noticing two untracked files
the review agent had created but I had not acted on.

## Scope
Included: the two specific High-severity findings (topic mismatch,
missing index). Excluded: the long-term follow-ups each finding's log
entry still lists as open (an `EXPLAIN`-verified benchmark at
production-scale cardinality, ongoing latency monitoring) — left as
deferred, not silently dropped.

## Method
- Read both findings' Root Cause / Prevention sections directly rather
  than re-deriving the bug from scratch.
- Reproduced the actual code path (`article_of`, `articles_listed_by`,
  `add_section`/`update_section`) before writing a fix, confirming the
  selector picks "first visible article section" with no topic check.
- Fixed at the layer the finding's own guardrail named: enforced the
  page invariant in the content *service* (reject a second visible
  article section) rather than only patching the selector, so the
  one-page/one-article assumption is true by construction.
- Added the GIN + plain index via a normal Django migration, following
  the existing precedent in `apps/catalogue/migrations/0002_search.py`.
- Ran the full `api:verify` gate locally before opening the PR; all 999
  tests green, 96.19% coverage.

## Decisions & Findings
- Enforced the "one visible article section per page" guardrail in
  *both* `add_section` (adding a second one) and `update_section`
  (re-showing a previously hidden second one) — the finding's own
  investigation steps showed cardinality could be violated either way.
- Did not implement the finding's "cannot combine `article` with
  `article_list` on the same page" suggestion — out of scope for this
  pass and not clearly required by current product behavior; left as a
  question for the product owner rather than assumed.
- Did not add an `EXPLAIN`-verified benchmark at production scale (the
  index finding's long-term fix) — the index itself closes the
  immediate risk; benchmarking is a separate piece of work.

## Changes Made
- `apps/api/apps/content/selectors.py`: `article_of()` takes an optional
  `topic` and only matches a section with that topic;
  `articles_listed_by()` passes the list's topic through.
- `apps/api/apps/content/services.py`: `add_section` and `update_section`
  raise `ValidationFailed` (`DUPLICATE_ARTICLE_SECTION`) rather than
  allow a second visible `article` section on one page.
- `apps/api/apps/content/models.py` +
  `apps/api/apps/content/migrations/0005_article_listing_indexes.py`:
  `GinIndex` on `PageVersion.sections`, plain `Index` on
  `PageVersion.published_at`.
- `apps/api/apps/content/tests/test_news.py`: three new regression tests
  (duplicate-section rejection on add, on re-show, and topic-correct
  listing output).
- PR #65, merged to `main`, deployed to production, migration applied.

## Verification
- `npm run api:verify`: 999/999 tests passed, 96.19% coverage, lint/format/
  layering gates all green, locally before opening the PR.
- CI on PR #65: API, Verify, E2E, CI-success all green.
- Post-deploy: `manage.py showmigrations content` on the production
  container confirmed `0005_article_listing_indexes` applied.

## Follow-ups / Deferred
- `EXPLAIN (ANALYZE, BUFFERS)` benchmark at production-sized article
  volume, and latency monitoring on the public News/article endpoints —
  still open per the index finding's "long-term fix."
- Whether `article` and `article_list` should be mutually exclusive on
  one page is a product question, not resolved here.
- Process gap: ensure a background `/code-review` run's full finding set
  is read from its output file (not only the task-notification summary)
  before treating a review as "clean" — this is what let both findings
  slip past the original merge decision.

## References
- `Backend_and_API/LEC-2026-11-19-article-list-multi-section-topic-mismatch.md`
- `Database_and_State/LEC-2026-11-19-article-list-unindexed-jsonb-query.md`
- `DevOps_and_Infrastructure/LEC-2026-11-19-stacked-pr-merged-into-wrong-base.md`
- `reports/LEC-2026-11-19-ship-lec-091-092-deploy-and-qa-handoff.md`
- PR #65 (LEC-093)

---

**Completed By:** Claude Code (session for tinotendamupezeni@thuthuka.tech)
**Duration:** ~40 minutes
