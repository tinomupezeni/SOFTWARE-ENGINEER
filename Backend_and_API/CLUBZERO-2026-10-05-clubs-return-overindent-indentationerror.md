# `clubs.py` `return [` over-indented 4 spaces — `IndentationError` crashed backend startup

**Date:** 2026-10-05
**Project:** CLUBZERO
**Environment:** Development (all environments — import-time crash)
**Severity:** Critical
**Status:** Resolved

## Summary

`club-zero-backend/app/routers/clubs.py`, in `get_my_clubs` (`GET /clubs/me`), had its `return [` statement indented 8 spaces instead of 4. This is an `IndentationError`, so importing the module — and therefore starting the API — crashed. Found while bringing the backend up to investigate a login failure on the test phone; fixed by removing the 4 extra spaces.

## Symptoms

- After fixing the `main.py` missing-import bug (same day, separate entry), the API container still crash-looped, this time with:
  ```
  File "/app/app/routers/clubs.py", line 35
      return [
  IndentationError: unexpected indent
  ```
- User-visible effect on the test phone: login (and every other API call) failed — nothing listened on `:8001`.

## Environment Details

- **Server/Host:** Local dev machine (`docker compose`, `club-zero-backend-api-1`)
- **Services Affected:** `club-zero-backend` API — entire service, not just `/clubs/me`
- **Related Components:** `app/routers/clubs.py` lines 32–35 (`get_my_clubs`)
- **Time First Observed:** 2026-10-05, during login-failure investigation (commit `246d3c5` vintage)

## Investigation Steps

### 1. Initial Diagnosis

Read `docker logs club-zero-backend-api-1` after rebuild — traceback pointed at `clubs.py` line 35.

### 2. Root Cause Analysis

```bash
python3 -m py_compile app/routers/clubs.py  # fails (runtime check not even needed)
```

Read lines 32–35: `clubs = result.scalars().all()` at 4-space indent, then `return [` at 8-space indent with trailing whitespace on the blank line above suggesting a sloppy edit.

### 3. Key Findings

- `py_compile` catches this class instantly — unlike the `NameError` bugs from the same session, this one never needed a running app to detect. It shipped anyway: nothing runs even `py_compile` on the backend today.
- Fixing this exposed the *next* startup blocker (orphaned decorator + stray imports, separate entry) — the file had stacked defects, each hiding behind the previous one.

## Root Cause

An edit to `get_my_clubs` left the `return [` line indented one level too deep. Module-level `IndentationError` → whole API cannot start.

## Prevention / Rule

**Guardrail:** The same backend CI smoke check as the companion entries — `python -m compileall` or an app-import smoke test on every backend change. Fails before this fix, passes after.

One gate covers all three `clubs.py` entries logged today plus the `main.py` entry: none of the four defects can survive a single import of `app.main`.

## Solution

### Immediate Fix

Removed the 4 extra spaces (commit in SharedHQ working tree, with the other two `clubs.py` fixes):

```python
    clubs = result.scalars().all()

    return [
```

### Long-term Fix

- Backend CI with import-smoke check (same as companion entries).
- `ruff` (already installed at `~/.local/bin/ruff`) with at least `F821/F822/F823` + `E9` (syntax) over `app/` — `E901` flags this file without executing anything.

## Prevention

- [ ] Backend CI: import-smoke + `ruff` syntax/undefined-name checks
- [ ] Confirm image SHA on `smepulse-vm` before next deploy (production may predate all of this)

## Related Issues

- `Backend_and_API/CLUBZERO-2026-10-05-main-missing-router-imports.md` — the blocker in front of this one
- `Backend_and_API/CLUBZERO-2026-10-05-clubs-orphan-decorator-stray-imports.md` — the blocker behind this one
- `Backend_and_API/CLUBZERO-2026-10-05-clubs-missing-names-basemodel-uuid.md` — the blocker behind that one
- `Backend_and_API/ClubZero-2026-10-03-fastapi-models-import-crash.md` — same bug class, earlier file

## References

- `SharedHQ/club-zero-backend/app/routers/clubs.py` (`get_my_clubs`)

---

**Resolved By:** Muse Spark (opencode)
**Time to Resolution:** ~5m within the login-failure investigation
