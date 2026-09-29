# Reverted admin sidebar grouping; caught corrupted submenu entry

**Date:** 2026-09-29
**Project:** ZCHPC-ERP
**Environment:** Production (admin frontend)
**Severity:** Low
**Status:** Resolved

## Summary

The admin sidebar grouping from PR #36 didn't suit multi-office use —
reverted to the flat enterprise nav via PR #38, deployed to prod.
While verifying the revert line-by-line, found PR #36 had also
corrupted the Payroll submenu: the "Process Payroll" entry had been
rewritten into a duplicate "Payroll" item (wrong title, stray icon,
broken indentation). The revert restores the original entry.

## Symptoms

- Requester: grouped admin navbar "doesn't look right" across offices.
- Hidden: duplicate "Payroll" item inside the Payroll submenu on prod
  (live since PR #36's deploy).

## Environment Details

- **Services Affected:** `zchpc_frontend` nav only
- **Related Components:** `layout/navConfig.tsx`, `MainLayout.tsx`,
  `SidebarItem.tsx`

## Investigation Steps

Diffed working tree against pre-PR-36 (`git diff cde9eff^`) instead of
trusting the revert edits — the unexpected hunk exposed the corrupted
sub-item, which no test or build could catch (admin has no unit tests;
vite build passed with the corruption live).

## Root Cause

Twofold: (1) design decision wrong for the audience (grouped sections
vs multi-office flat nav) — reverted per requester; (2) a scripted edit
during PR #36 mangled one submenu entry, missed because the diff wasn't
reviewed hunk-by-hunk before merge.

## Prevention / Rule

**Guardrail:** every PR touching nav/config files gets a full
`git diff` read before merge — build-green is not review. (Same lesson
as the portal TS2304: admin has no tests, so the diff is the test.)

## Solution

- PR #38 (`revert/admin-sidebar-grouping` → `main`, `214c5cb`):
  exact restore + submenu fix. Kept only `aria-label` and the
  `console.log` removals (invisible).
- Rebuilt staging `frontend` (prod origin arg), verified sections
  absent + no localhost leak, retagged, recreated prod. `:3000` 200,
  8/8 healthy.

## Prevention

- [x] Revert + submenu fix deployed
- [ ] Consider a nav smoke test (assert submenu titles/paths render)

## Related Issues

- Pass 1: `reports/ZCHPC-2026-09-29-design-refresh-contrast-sidebar.md`
- Pass 2 (admin sections): `reports/ZCHPC-2026-09-29-admin-sidebar-sections.md`

## References

- PR: https://github.com/tinomupezeni/ZCHPC-ERP/pull/38

---

**Resolved By:** Muse Spark (opencode)
**Time to Resolution:** ~40 min
