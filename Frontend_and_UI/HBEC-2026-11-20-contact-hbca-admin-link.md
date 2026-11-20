# Bug: School Dashboard Login "Contact HBCA Admin" Link Pointed to Dummy Anchor

- **Date:** 2026-11-20
- **Project:** HBEC / HBCA Schools
- **Area:** Frontend & UI
- **Severity:** Low

---

## 1. Problem
On the School Dashboard login page (`school.hbca.tech`, `SCHOOLS/school_dashboard/src/routes/login.tsx`), the "Need access? Contact HBCA Admin" link had an unconfigured dummy target `href="#"`. When prospective or uninvited school personnel clicked the link, the page simply jumped to the top without directing them to any support channel.

## 2. Root Cause
The link was a placeholder during early scaffolding and was never wired to the administrative contact channel.

## 3. Fix
Updated `SCHOOLS/school_dashboard/src/routes/login.tsx` to link to:
`mailto:support@hbca.tech?subject=HBCA%20School%20Dashboard%20Access%20Request`
allowing school users to immediately dispatch an access request email to the administration team.

## 4. Verification
- Checked file diff and verified syntax.
- Committed to `master` (`94385da97`) and synced to `origin/experimental`.
- Marked task `94f483c8-18c1-4e59-8e95-369bfb57ce0a` as `DONE` on ProjectFlow.
