# Article Listing Scans Published Snapshots Without an Index

**Date:** 2026-11-19
**Project:** LEC Biotec
**Environment:** Pre-merge review of PR #63 (LEC-092)
**Severity:** High
**Status:** Investigating

## Summary

PR #63 implements every public article list as a JSONB containment query against `content_page_version.sections`, followed by an aggregate over all versions of each matching page. `PageVersion.sections` has no GIN index, `published_at` has no index, and the PR includes no migration. The News archive request will consequently grow from a bounded page read into a scan and aggregation over the historical page-version table.

## Symptoms

- Public News page latency and database load rise with the number of CMS publishes and articles.
- A page containing multiple article lists issues the expensive query once per list.

## Environment Details

- **Server/Host:** N/A — caught before merge.
- **Services Affected:** Public CMS page endpoint / PostgreSQL.
- **Related Components:** `PageVersion.sections`, `PageVersion.published_at`, article-list selector.
- **Time First Observed:** 2026-11-19 during PR review.

## Investigation Steps

### 1. Initial Diagnosis

Reviewed the generated query path and schema migration used by PR #63.

### 2. Root Cause Analysis

`articles_listed_by()` filters `published_version__sections__contains=[wanted]`, annotates `Min(versions__published_at)`, orders, and limits. The existing initial migration defines `sections` as a JSON field and `published_at` as an unindexed nullable field; PR #63 changes neither schema nor indexes.

```bash
git show origin/pr-63:apps/api/apps/content/selectors.py
git show origin/pr-63:apps/api/apps/content/migrations/0001_initial.py
git diff --name-only origin/pr-62...origin/pr-63
```

### 3. Key Findings

- PostgreSQL JSONB containment needs a suitable GIN index to avoid repeated table scans at archive scale.
- The `Min`/order path also lacks an index supporting the publication-date access pattern.
- No query-plan or scale test accompanies the claim that archive growth does not increase page-read work.

## Root Cause

The feature stores article discovery data only inside immutable JSON snapshots, then queries it as if it were indexed relational data, without introducing the corresponding access-path migration.

## Prevention / Rule

**Guardrail:** any public selector that filters a JSONB snapshot at unbounded archive cardinality must ship with an `EXPLAIN`-verified supporting index migration (or a relational projection with indexed query columns).

This binds the storage design to a verifiable access path and prevents a feature from relying on development-sized tables.

## Solution

### Immediate Fix

Block merge until the implementation uses an indexed relational article projection or adds safe, query-plan-verified indexes and limits the number of listing queries per page.

### Long-term Fix

Add a production-like `EXPLAIN (ANALYZE, BUFFERS)` fixture or benchmark and monitor public page database latency after deployment.

## Prevention

- [x] Database migration or data-model change required
- [x] Query-plan verification required
- [ ] Monitoring/alerts to add
- [ ] Documentation to update

## Related Issues

- PR #63 / LEC-092

## References

- `apps/api/apps/content/selectors.py:199-239` at PR #63
- `apps/api/apps/content/migrations/0001_initial.py:71-87` at PR #63

---

**Resolved By:** Unassigned
**Time to Resolution:** N/A — caught before merge
