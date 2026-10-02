# A route used two separate DB sessions for what @transactional() thought was one

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api)
**Environment:** Production
**Severity:** Medium
**Status:** Resolved

## Summary
`catalog.py`'s `create_product` route depended on both `get_db` (bound to
`store_engine`) and `get_auth_db` (bound to a separate `auth_engine`)
simultaneously - two distinct SQLAlchemy sessions/connections, each its
own transaction, even though in every real environment they point at the
exact same physical database. `@transactional()` only ever manages
whichever session is passed as its `db` kwarg, so any future write made
through `auth_db` in a route like this would never be committed or
rolled back by the decorator - a latent bug waiting for someone to add
exactly that kind of write.

## Symptoms
- Not an active failure today - `auth_db` in `create_product` is
  currently read-only (looks up `ProviderApplication`/`User` for the
  seller's display name), so the gap hadn't yet caused a visible bug.
  Found while investigating whether `app/database.py`'s 5 separate
  engines were just redundant or an actual risk.

## Environment Details
- **Server/Host:** Production (`tese-store-api` container)
- **Services Affected:** `create_product` (and any future route that
  mixes `get_db`/`get_auth_db`/`get_brain_db`/`get_chat_db`)
- **Related Components:** `app/database.py`,
  `apps/store-api/app/modules/catalog/routes/catalog.py`
- **Time First Observed:** 2026-10-02

## Investigation Steps

### 1. Initial Diagnosis
A prior audit flagged `app/database.py`'s 5 separate SQLAlchemy engines
as redundant (all but `sourcing_engine` point at the same DB in every
real environment) but didn't establish whether anything actually
depended on them being separate, or combined them in the same request.

### 2. Root Cause Analysis
```bash
grep -rln "get_auth_db\|get_brain_db\|get_chat_db" app/ --include="*.py"
```
found only two files use any alternate session at all, and
`get_brain_db`/`get_chat_db` have zero callers anywhere. `catalog.py`'s
`create_product` does:
```python
def create_product(
    data: ProductCreate,
    db: Session = Depends(get_db),
    auth_db: Session = Depends(get_auth_db),
    ...
):
    ...
    app_record = auth_db.query(ProviderApplication)...
```
`@transactional()` defaults to managing the session under the `db`
kwarg specifically - `auth_db` was invisible to it entirely.

### 3. Key Findings
- This wasn't just wasted connections (though it was that too - every
  request to this route opened a second, unnecessary DB connection) -
  it was a structural trap: the moment anyone added a write through
  `auth_db` in a route like this, that write would flush but never
  commit, the exact same bug independently found and fixed in
  `payment.py` (see the companion entry), except here it would be
  invisible until someone actually wrote through the wrong session.

## Root Cause
`get_auth_db`/`get_brain_db`/`get_chat_db` were separate callables bound
to separate engines, left over from before auth/brain/chat were
consolidated into this app - FastAPI's per-request dependency cache
dedupes by callable identity, so even though all these engines target
the same database today, using different callables meant each resolved
to its own independent session.

## Prevention / Rule
**Guardrail:** Within one FastAPI app backed by a single database, every
DB-session dependency used by more than one route must be the literal
same callable (not merely equivalent engines) - verified here by making
`get_auth_db = get_db` (same object, not a wrapper), so FastAPI's
dependency cache guarantees one session per request regardless of how
many places `Depends()` it.

## Solution

### Immediate Fix
`app/database.py`: removed `auth_engine`/`brain_engine`/`chat_engine`
and their `SessionLocal`s entirely; `get_auth_db`, `get_brain_db`,
`get_chat_db` are now literally `get_db` (`get_auth_db = get_db`), not
wrapper functions - so FastAPI's dependency cache resolves
`Depends(get_db)` and `Depends(get_auth_db)` in the same request to one
shared `Session` object.

```bash
python3 -m py_compile app/database.py   # clean
```
Verified in production: granted a test account the `farmer` role, then
called `create_product` (which reads `ProviderApplication.business_name`
via `auth_db` and writes the `Product` via `db`) - the created product's
`seller_name` correctly reflected the business name read through what is
now the same session as the write, and the write committed correctly via
`@transactional()`.

### Long-term Fix
None needed - `sourcing_engine` remains genuinely separate (a different
physical database, `tese_sourcing`) and was left untouched.

## Prevention
- [x] Code changes required (done this session)

## Related Issues
- `Backend_and_API/tese-marketplace-2026-10-02-payment-writes-never-committed.md`
  (the same class of bug - an uncommitted session - found independently
  in a different file)
- `reports/tese-marketplace-2026-10-02-database-hardening-transactions-engines-fks.md`

## References
- `apps/store-api/app/database.py`
- `apps/store-api/app/modules/catalog/routes/catalog.py`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~15 minutes from discovery to verified fix in production
