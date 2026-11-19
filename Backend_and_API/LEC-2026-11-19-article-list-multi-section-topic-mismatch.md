# Article Lists Can Publish the Wrong Article Metadata When a Page Has Multiple Article Sections

**Date:** 2026-11-19
**Project:** LEC Biotec
**Environment:** Production. Found during pre-merge review of PR #63 (LEC-092) but not surfaced in the session summary before merge/deploy; fixed on PR #65 (LEC-093) after it had already shipped.
**Severity:** High
**Status:** Resolved

## Summary

PR #63 treats any page containing an `article` section as an article, but the CMS permits an editor to add more than one `article` section to the same page. Topic-filtered article lists query for a matching section, then unconditionally serialise the first visible article section. An article whose first section is `company-news` and second section is `education` is therefore returned in an Education list as Company News with the first section's headline, summary and cover.

## Symptoms

- A topic-filtered News page can show a card with a topic, headline, summary and cover from a different article section than the section that caused it to match.
- The card links to the same page, whose rendered content can contain both sections.

## Environment Details

- **Server/Host:** N/A — caught before merge.
- **Services Affected:** Public CMS page payload / article listings.
- **Related Components:** `apps/content/sections.py`, `apps/content/selectors.py`, CMS section editor.
- **Time First Observed:** 2026-11-19 during PR review.

## Investigation Steps

### 1. Initial Diagnosis

Reviewed the article registry and public listing selector in PR #63.

### 2. Root Cause Analysis

The registry exposes `article` as a normal addable section and has no page-level cardinality rule. `articles_listed_by()` uses JSONB containment to find a page containing an article with the requested topic, then calls `article_of()`, which selects the first visible article without checking the requested topic.

```bash
git show origin/pr-63:apps/api/apps/content/selectors.py
git show origin/pr-63:apps/api/apps/content/sections.py
```

### 3. Key Findings

- `add_section()` allows repeated section types.
- `article_of()` returns the first visible article section.
- The existing topic test creates one article section per page, so it cannot expose the mismatch.

## Root Cause

The data model describes a page with an article section as one article but does not enforce exactly one visible article section, while the query and extraction steps apply incompatible selection rules.

## Prevention / Rule

**Guardrail:** enforce the page invariant in the content service: a page may have at most one `article` section (and cannot combine it with `article_list`); add an integration test that a second article section is rejected.

This makes the selector's one-page/one-article representation true by construction rather than relying on section order.

## Solution

### Immediate Fix

`add_section`/`update_section` now reject a second visible `article` section
on a page (`DUPLICATE_ARTICLE_SECTION`), and `article_of()`/
`articles_listed_by()` match the requested topic rather than returning the
first visible article section unconditionally. Shipped on PR #65
(LEC-093), deployed and migrated the same day.

### Long-term Fix

Added regression tests: `test_a_page_cannot_carry_two_visible_article_sections`,
`test_reshowing_a_hidden_article_section_is_blocked_by_a_visible_one`,
`test_a_topic_listing_never_reports_an_article_under_the_wrong_topic`.

## Prevention

- [x] Code changes required
- [x] Regression test required
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Post-fix re-review (2026-11-19)

A second `/code-review` pass on PR #65 flagged that the new guard in
`add_section`/`update_section` only prevents a *second* visible `article`
section going forward — it does not reconcile a page that already had two
before the guard existed. Checked production directly:

```python
Section.objects.filter(type="article", is_visible=True).values("page_id") \
    .annotate(n=Count("id")).filter(n__gt=1)
# -> []
```

Zero pages currently violate the invariant, so this is a closed risk today,
not a live bug. Flagging here rather than silently dropping it: if a future
data import or admin bulk-edit ever bypasses `add_section`/`update_section`
(e.g. a raw `Section.objects.create`), this guard would not catch it.

## Related Issues

- PR #63 / LEC-092 (introduced)
- PR #65 / LEC-093 (fixed)
- `DevOps_and_Infrastructure/LEC-2026-11-19-stacked-pr-merged-into-wrong-base.md`

## References

- `apps/api/apps/content/selectors.py:178-235` at PR #63
- `apps/api/apps/content/services.py:47-78` at PR #63

---

**Resolved By:** Claude Code (session for tinotendamupezeni@thuthuka.tech)
**Time to Resolution:** ~30 minutes, fixed same day on PR #65 (merged after prod deploy had already shipped the bug)
