# PostgreSQL trigram search

**Date:** 2026-10-15
**Project:** Swap-O-Sell
**Type:** Search Enhancement / Performance
**Status:** Completed

## Summary
Added PostgreSQL `pg_trgm` similarity search for typo-tolerant marketplace queries while preserving the SQLite fallback used by local development. Search terms now use a thresholded similarity score across listing and seller fields, then rank results by total similarity and recency.

## Context / Trigger
The existing search supported partial substring matching but did not tolerate spelling errors. The user requested trigram search so queries such as misspelled product terms can still return nearby matches.

## Scope
Included PostgreSQL extension setup, conditional ORM similarity queries, search-term normalization and limits, relevance ordering, and regression coverage. Elasticsearch, autocomplete, stemming, language-aware tokenization, and dedicated search infrastructure remain deferred.

## Method
Used Django's PostgreSQL trigram functions only when the active database vendor is PostgreSQL. Added a migration that enables `pg_trgm` on PostgreSQL and leaves SQLite unchanged. Kept the existing `icontains` path as a deterministic local fallback and added a PostgreSQL-only typo test.

## Decisions & Findings
- Each query term must meet a similarity threshold of `0.18` against at least one searchable field.
- Search checks product name, description, category, location, swap preferences, and seller identity/location.
- Up to eight terms of at least two characters are considered to bound query cost.
- PostgreSQL results are ordered by summed per-term similarity and recency.
- SQLite remains supported without PostgreSQL-only imports or SQL.
- The PostgreSQL-specific test is skipped locally because the current Docker environment uses SQLite; it will run when the project uses PostgreSQL.

## Changes Made
- Added `django.contrib.postgres` to `INSTALLED_APPS`.
- Added `backend/modules/listings/migrations/0008_enable_trigram_search.py`.
- Added conditional `TrigramSimilarity` search and relevance ordering in `backend/modules/listings/views.py`.
- Added a PostgreSQL-only typo regression test in `backend/modules/listings/test_search.py`.
- Added issue log `SWAPOSELL-2026-10-15-trigram-search-import.md`.

## Verification
- Django system checks passed.
- Search and swap regression suite passed: 9 tests, 1 PostgreSQL-only test skipped on SQLite.
- Trigram migration is applied in the local database.
- Frontend build passed.
- Health endpoint returned `{"ok": true, "service": "swap-o-sell"}`.
- `git diff --check` passed.

## Follow-ups / Deferred
- Run the typo test against the optional PostgreSQL service or staging database.
- Add GIN/GiST trigram indexes when PostgreSQL becomes the production database and query volume warrants them.
- Tune the similarity threshold against real zero-result and successful-search telemetry.
- Add typo-tolerant autocomplete and search analytics.

## References
- `backend/modules/listings/views.py`
- `backend/modules/listings/migrations/0008_enable_trigram_search.py`
- `backend/modules/listings/test_search.py`
- `SWAPOSELL-2026-10-15-trigram-search-import.md`

---

**Completed By:** Copilot
**Duration:** Same development session
