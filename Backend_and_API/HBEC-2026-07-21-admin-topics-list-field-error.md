# Admin Topics List FieldError (Topic Disappearing Bug)

**Date:** 2026-07-21
**Project:** HBEC
**Environment:** Development / Production
**Severity:** Medium
**Status:** Resolved

## Summary
Admins were able to successfully create new Subject Topics from the frontend dashboard (receiving a "Successfully created" success toast), but the topics list immediately afterward would show "0 topics" and the topics would not render.

## Symptoms
- Creating a topic via the admin UI succeeds (201 Created).
- Expanding the "Topics" section in the UI shows an empty list and claims there are 0 topics.
- The `GET /api/curriculum/topics/?subject=<id>` request silently fails with a `500 Internal Server Error`.

## Environment Details
- **Services Affected:** `ADMIN` Backend (`TopicListCreateView`), `ADMIN` Frontend
- **Related Components:** Curriculum API
- **Time First Observed:** 2026-07-21

## Investigation Steps & 5 Whys

1. **Why does it say "Successfully created" but still show 0 topics?**
   Because the topic is successfully saved to the PostgreSQL database via a `POST` request, but the subsequent `GET` request the frontend makes to fetch the updated list of topics fails silently in the background, leaving the frontend stuck displaying 0.
2. **Why does the `GET` request fail?**
   The `GET` request (`/api/curriculum/topics/?subject=<id>`) crashes with a `500 Internal Server Error` inside the Django backend when it tries to execute the database query to list the topics.
3. **Why does the database query crash?**
   The `TopicListCreateView.get_queryset()` method had a broken ORM instruction: `Topic.objects.select_related("subject", "release")`. This tells Django to perform a SQL JOIN on a `release` table.
4. **Why does joining the `release` table cause a crash?**
   Because the `Topic` model **does not have a `release` field!** (Only models like `CurriculumUnit` have a `release` foreign key). Django immediately throws a `FieldError: Invalid field name(s) given in select_related: 'release'` when it tries to evaluate the list of topics.
5. **Why did the `POST` request succeed despite this broken query?**
   Because creating a topic (`POST`) uses the `TopicWriteSerializer`, which validates and saves the topic directly to the database and returns a `201 Created` response *without* ever needing to run that broken `select_related` queryset. The bug is exclusively triggered when the dashboard tries to read the list of topics back via `GET`.

## Root Cause
A copy-paste typo in the Django `TopicListCreateView.get_queryset()` method included `.select_related("release")` for the `Topic` model, which does not have a `release` foreign key.

## Solution

### Immediate Fix
Removed `"release"` from the `.select_related()` call in `ADMIN/adminBackend/apps/curriculum/views.py`:

```python
# Before
qs = Topic.objects.select_related("subject", "release").prefetch_related("objectives", "children")

# After
qs = Topic.objects.select_related("subject").prefetch_related("objectives", "children")
```

## Related Issues
- Unrelated to the previous Redis Sentinel failover `ReadOnlyError` issue (`2026-07-10-redis-sentinel-failover-readonly-error.md`), which crashed the `POST` request itself during Celery task generation.

---

**Resolved By:** Antigravity (AI Principal Engineer)
**Time to Resolution:** 10 minutes
