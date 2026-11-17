# Silent suburb fallback reassigns a job posting to the wrong location

**Date:** 2026-11-17
**Project:** MARITCHO
**Environment:** Development (found in code review, PR #12, branch `pr-12`)
**Severity:** High
**Status:** Confirmed — not yet fixed (found during verification of a candidate code-review finding)

## Summary
`resolveSuburbForJob` (`frontend/src/core/format/suburbs.ts:126-144`) lets an employer post a job in a
write-in suburb not in the known/seed list. When the typed text doesn't fuzzy-match any known suburb,
the function falls back to `availableSuburbs[0]` (alphabetically "Entumbane" given the seed list) as
the suburb value actually sent to the backend, while the real typed text is merely appended to the
free-text `address` field. `PostJobScreen.tsx` sends this fallback suburb as the job's `suburb` FK with
no error surfaced to the employer. The backend only validates that the suburb exists in its known
list — it has no way to know the value was substituted — and then uses `job.suburb` directly to drive
worker-proximity/distance-band ranking (`classify_distance`), so an employer in a real but unlisted
suburb (e.g. "Burnside") gets matched against workers near a different, essentially random suburb.

## Symptoms
- Not yet observed in production; found via verification of a candidate finding surfaced during
  review of PR #12.
- An employer outside the pilot suburb seed list posts a job; it is silently created with
  `suburb: "Entumbane"` (or whichever is `availableSuburbs[0]`) instead of their real area, with no
  warning, and worker matching runs against the wrong location for the life of that job.

## Environment Details
- **Server/Host:** N/A (Next.js frontend + FastAPI backend)
- **Services Affected:** Job posting (`PostJobScreen`), worker-proximity matching
- **Related Components:** `suburbs.ts` (`resolveSuburbForJob`, `predictSuburb`), `PostJobScreen.tsx`,
  `CreateJobRequestUseCase`, `classify_distance`
- **Time First Observed:** 2026-11-17, verifying a candidate finding against PR #12 (`pr-12`)

## Investigation Steps

### 1. Initial Diagnosis
A candidate finding claimed the write-in suburb combobox's fallback silently substitutes a wrong
suburb to satisfy the backend's "known suburb" validation, rather than surfacing an error or doing
proper geocoding.

### 2. Root Cause Analysis
- `resolveSuburbForJob`, lines 137-138:
  `const fallback = predictSuburb(cleanSuburb, availableSuburbs) ?? availableSuburbs[0] ?? "Hillside";`
  — when a write-in suburb scores 0 against every known suburb (no prefix/substring/subsequence match
  and edit distance exceeds the allowed threshold), `predictSuburb` returns `null`, so `fallback`
  becomes `availableSuburbs[0]`. The typed text is preserved only inside `address`
  (`${cleanAddress}, ${cleanSuburb}`), never in `suburb`.
- This path is reachable, not dead code: `LocationSheet.tsx` explicitly offers a
  "Use '<typed text>' — Write-in" option that saves arbitrary free text as `location.suburb` with no
  validation against the known list.
- `PostJobScreen.tsx:161` calls `resolveSuburbForJob(location.suburb, location.address, allSuburbs)`
  and sends `suburb: resolvedLocation.suburb` directly in the job-creation payload — the fallback
  value, not the employer's actual suburb. `submit()` has no check for whether a fallback occurred.
- Backend: `CreateJobRequestUseCase.execute` only validates `await self._suburbs.exists(suburb)` — the
  fallback suburb passes this check since it's a real known suburb — then stores it verbatim. This
  `job.suburb` then drives real distance-band computation:
  `band, km = classify_distance(job.suburb, area.suburb, coords)`.
- Test weakness: `suburbs.test.ts` asserts only `expect(DEFAULT_SUBURBS).toContain(custom.suburb)` —
  checking list membership, not that the mapping is sensible — so CI would not catch a regression that
  silently reassigns to a wrong-but-valid suburb.

### 3. Key Findings
- The frontend reimplements its own client-side fuzzy suburb resolution purely to dodge a backend
  validation error, rather than the backend doing geocoding/resolution once, server-side.
- The identical "unknown value needs FK" problem exists for `home_suburb` in the accounts router
  ("Unknown home suburb"), so this one-off client-side guess pattern is likely to recur wherever a
  free-text location is accepted next.

## Root Cause
The job-creation flow needs a suburb that exists in the backend's known-suburb table, but the UI
allows free-text write-in locations; rather than resolving/geocoding the write-in server-side or
blocking submission when no confident match exists, the frontend silently substitutes an arbitrary
known suburb to pass validation, trading a visible error for an invisible wrong answer.

## Prevention / Rule
**Guardrail:** Change `resolveSuburbForJob`'s fallback branch to surface a blocking validation error
("We don't recognize that suburb yet — pick the closest one from the list") instead of silently
substituting `availableSuburbs[0]`, and update `suburbs.test.ts` to assert the fallback is either the
confidently-matched suburb or an explicit error state — never an arbitrary unrelated suburb.

This targets the Root Cause directly: the fallback exists to avoid blocking the user, but a visible
"pick the closest one" prompt accomplishes the same non-blocking goal without lying about the job's
location to the matching engine.

## Solution

### Immediate Fix
Not yet applied — this entry documents a confirmed, currently-reachable correctness bug found during
review of PR #12; it has not been fixed on `pr-12` or `main` as of this writing.

### Long-term Fix
- Do suburb resolution/geocoding once on the backend (a shared service), and let the job's `address`
  field hold what the user actually typed without silently rewriting `suburb` to an unrelated value.
- Until then, at minimum replace the silent `availableSuburbs[0]` fallback with a surfaced error that
  blocks submission or asks the employer to confirm/pick the nearest suburb explicitly.

## Prevention
- [ ] Configuration changes needed — none
- [ ] Monitoring/alerts to add — consider alerting when `resolveSuburbForJob`'s no-match fallback path
      fires, to measure how often employers outside the seed list are affected
- [ ] Documentation to update — none yet; depends on chosen fix
- [x] Code changes required — replace the silent fallback with a surfaced error/confirmation (not yet
      implemented)

## Related Issues
- Found while reviewing MARITCHO PR #12 (branch `pr-12`), the same PR that introduced this write-in
  suburb feature.

## References
- `frontend/src/core/format/suburbs.ts:126-144` (`resolveSuburbForJob`)
- `frontend/src/core/format/suburbs.test.ts` (weak assertion on the fallback)
- `frontend/src/features/jobs/PostJobScreen.tsx:161-166`
- `frontend/src/features/jobs/LocationSheet.tsx` (write-in combobox)
- `backend/app/apps/jobs/domain/services.py` (`CreateJobRequestUseCase.execute`, `classify_distance`
  usage)
- PR: MARITCHO #12, branch `pr-12`

---

**Resolved By:** Not yet resolved — documented by tinomupezeni (via Claude Code)
**Time to Resolution:** N/A (open)
