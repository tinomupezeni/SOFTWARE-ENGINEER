# Composed Django route paths silently dropped their trailing slash

**Date:** 2026-10-30
**Project:** Archi
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary

Archi's new Django URL-composition logic (`joinRoutePath` in `src/pythonRoutes.ts`, built for Phase 5's route tracing) stripped the trailing slash from every composed route. Since Django/DRF routing is slash-sensitive and the HBEC pilot workspace's endpoints are all trailing-slash, every extracted route would have been reported with a path that would 404 if a user copy-pasted it to actually call the endpoint — a correctness bug in a tool whose entire value proposition is "trust the extracted fact."

## Symptoms

- `joinRoutePath('api/auth/', 'login/')` returned `'api/auth/login'` instead of `'api/auth/login/'`.
- Caught immediately by a new HBEC integration assertion (`test/extension.test.ts`) expecting the real route `/api/auth/login/` (verified against HBEC's actual `apps/accounts/urls.py:44` and `config/urls.py:33`) and failing because the extracted node's label was `/api/auth/login` (no trailing slash).

## Environment Details

- **Server/Host:** N/A — local static analysis, VS Code extension-host test run.
- **Services Affected:** Archi's new Flows view (route resolution) for any Django service.
- **Related Components:** `src/pythonRoutes.ts` (`joinRoutePath`), `src/componentWorkspace.ts` (route composition).
- **Time First Observed:** During the first HBEC extension-host run against the new route extractor, before any release.

## Investigation Steps

### 1. Initial Diagnosis

The HBEC integration test asserted `loginRoute.label === '/api/auth/login/'` (matching the real, audited HBEC route) and failed with the node not found — the route node existed but under a different label.

### 2. Root Cause Analysis

```bash
node -e "console.log(require('./dist/src/pythonRoutes').joinRoutePath('api/auth/', 'login/'))"
# -> 'api/auth/login'
```

Traced to `joinRoutePath`'s implementation: it stripped leading/trailing slashes from *every* segment before joining, including the last one, with no step to restore a trailing slash even when the final leaf segment legitimately had one.

### 3. Key Findings

- Django's `path()` prefixes are composed by string concatenation at runtime; a prefix ending in `/` and a leaf ending in `/` are meant to produce a path ending in `/`.
- HBEC's actual endpoints (audited directly from `apps/accounts/urls.py`) are all written with a trailing slash (`"login/"`, `"signup/"`, etc.), following Django convention.
- A naive "strip all slashes then join with `/`" approach is the kind of normalization that silently discards this semantically significant trailing slash.

## Root Cause

`joinRoutePath` treated the trailing slash as insignificant whitespace-like noise to normalize away, rather than as part of the route's identity that Django's routing actually depends on.

## Prevention / Rule

**Guardrail:** Any route/path-composition function must have a unit test asserting the exact, literal composed string against a real example copied from the target codebase (not a hand-simplified one) — not just that composition "worked" structurally (right segments, right order). String-identity assertions catch silent normalization bugs that structural assertions (counts, resolved flags) do not.

This closes the gap because the bug was invisible to any test checking "was a route node created with roughly the right pieces" — it required asserting the literal output string against ground truth to surface.

## Solution

### Immediate Fix

Changed `joinRoutePath` to check whether the *last* input segment (before any stripping) ended in `/`, and reapply that trailing slash to the final joined string:

```ts
export function joinRoutePath(...parts: (string | undefined)[]): string {
  const filtered = parts.filter((part): part is string => !!part);
  const trailingSlash = filtered.length > 0 && /\/$/.test(filtered[filtered.length - 1]);
  const segments = filtered.map(part => part.replace(/^\/+|\/+$/g, '')).filter(Boolean);
  const joined = segments.join('/');
  return trailingSlash && joined ? joined + '/' : joined;
}
```

### Long-term Fix

None needed beyond the guardrail above; the function is small and now covered by a literal-string regression test (`test/pythonRoutes.test.ts`).

## Prevention

- [x] Code changes required (done, see above)
- [x] Documentation to update — `PHASE5_REVIEW.md` records this as a found-and-fixed bug
- [ ] Configuration changes needed — N/A
- [ ] Monitoring/alerts to add — N/A (static analysis tool, no runtime to monitor)

## Related Issues

- Found during and cross-referenced in `reports/ARCHI-2026-10-30-phase5-component-flow-tracing.md` (Phase 5 completion report).

## References

- `src/pythonRoutes.ts` — `joinRoutePath`.
- `test/pythonRoutes.test.ts` — regression tests.
- HBEC: `STUDENT/hbec_backend/config/urls.py:33`, `STUDENT/hbec_backend/apps/accounts/urls.py:44` — the ground-truth route this bug was caught against.

---

**Resolved By:** Tinotendamupezeni (tinotendamupezeni@thuthuka.tech), with Claude Code
**Time to Resolution:** Same session, caught before any release.
