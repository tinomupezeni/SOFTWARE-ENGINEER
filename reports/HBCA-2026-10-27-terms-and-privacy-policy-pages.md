# Terms & Conditions and Privacy Policy Pages

**Date:** 2026-10-27
**Project:** HBCA (HBEC repo)
**Type:** Content / Feature
**Status:** Completed (staging only)

## Summary
Drafted Terms & Conditions and Privacy Policy content for HBCA Assistant and
built public, unauthenticated pages for both, closing the HBCA task
"Documents" ("Create terms and conditions / Create privacy policy docs").
Also linked both from the student and parent signup forms, since documents
nobody can find are nearly as unhelpful as no documents.

## Context / Trigger
HBCA ProjectFlow task "Documents" (TODO, MEDIUM), found while reviewing the
HBCA project's open task board. Unlike this session's other HBCA work, this
was a legal-content gap, not a code bug: a codebase search turned up zero
existing references to "terms and conditions" or "privacy policy" anywhere
in the student or admin frontends — fully greenfield.

## Scope
- In scope: Terms & Conditions and Privacy Policy page content and routes
  (`/terms`, `/privacy`) in the student-facing app, plus a signup-time
  agreement link on both the student and parent signup forms.
- Explicitly out of scope: this is a **draft**, not reviewed by a lawyer.
  Before being relied on as final/binding, it needs legal review — in
  particular the refund policy, the children's-privacy section, and the
  AI-processing/third-party-sharing section, given HBCA serves minors and
  sends content to third-party AI providers.
- Also out of scope: an actual blocking checkbox/consent gate on signup
  (currently just an informational link, matching the lower-friction
  pattern most ed-tech signup flows use) — a hard gate was not requested
  and would be a bigger product/legal decision on its own.

## Method
Confirmed via user input the three facts the codebase couldn't supply:
operating name ("HBCA / H-BEC", used as "HBCA Assistant" to match the
product's own branding seen in `SignupPage.tsx`), contact email
(`info@thuthuka.tech`), and governing law (Zimbabwe). Everything else was
grounded directly in what the product actually does and how it actually
handles data, read from the real code rather than invented:
- Payment providers (Paynow, ZB Bank) — `PAYMENTS/app/services/`.
- Phone-number collection is optional (the phone-number prompt feature from
  earlier in this session).
- Parent/student linked accounts — `apps.accounts.models` roles.
- Account deletion anonymizes identifiers but keeps learning history in
  anonymized form — the exact wording in `StudentDetailPage.tsx`'s delete
  confirmation dialog.
- Study reminders are opt-in/opt-out via Settings — `StudyPlanCard.tsx`.
- AI-generated practice/marking content, and a third-party-AI-processing
  disclosure, given the AGENTIC_HARNESS's use of external model providers.
- Curriculum scope (ZIMSEC, Cambridge, Primary/O-Level/A-Level) and
  explicit non-affiliation with the exam boards.

## Decisions & Findings
- Used the product's own established name ("HBCA Assistant", from
  `SignupPage.tsx`'s branding) rather than inventing new legal-entity
  wording, per the user's choice not to introduce a separate registered
  company name.
- Kept the signup-time Terms/Privacy link informational (not a hard
  checkbox gate) to avoid adding friction or a legal-flow decision beyond
  what was asked.
- Rendered as plain semantic JSX with Tailwind's `prose` typography plugin
  (already a project dependency) rather than routing through
  `MarkdownRenderer` — that component lazy-loads a ~1MB bundle
  (Streamdown/KaTeX/Shiki/simulations) built for AI-generated exam content,
  which is unnecessary weight for two static legal pages.

## Changes Made
- `STUDENT/Frontend/src/pages/TermsPage.tsx` (new) — Terms & Conditions.
- `STUDENT/Frontend/src/pages/PrivacyPolicyPage.tsx` (new) — Privacy Policy.
- `STUDENT/Frontend/src/App.tsx` — added `/terms` and `/privacy` public
  routes (lazy-loaded, alongside the other unauthenticated routes).
- `STUDENT/Frontend/src/features/auth/pages/SignupPage.tsx` and
  `ParentSignupPage.tsx` — added an agreement line linking both documents
  above the submit button.
- `STUDENT/Frontend/src/pages/__tests__/legalPages.test.tsx` (new).

## Verification
- New test file (4 tests: heading renders, contact-email `mailto:` link,
  cross-links between the two pages) — passing, alongside the full
  `src/pages` + `src/features/auth/pages` suites (29 tests).
- `tsc --noEmit` and `eslint` clean on every touched file.
- Actually launched the Vite dev server and drove headless Chrome
  (Playwright, via the system's `/usr/bin/google-chrome` since Playwright's
  own bundled browser wasn't installed) to both new routes and the signup
  page; screenshotted each. Confirmed `/terms` and `/privacy` render with
  correct headings and working links, and the signup page shows the new
  agreement line cleanly above the submit button. Checked console errors
  against an existing unrelated page (`/maintenance`) to confirm the
  background 404s seen were pre-existing dev-environment noise (API
  telemetry calls with no backend running), not caused by this change.

## Follow-ups / Deferred
- **Needs real legal review before being treated as final/binding** —
  flagged in both file headers. In particular: the refund policy, the
  children's-privacy and parental-consent mechanics, and whether Zimbabwe's
  Data Protection Act imposes requirements beyond what's drafted here.
- Not yet deployed to production (staging only, pending cutover alongside
  the other HBCA fixes from this session).
- No hard consent checkbox at signup — worth a product decision if the
  business wants enforceable acceptance rather than an informational link.

## References
- HBCA ProjectFlow task "Documents".
- `STUDENT/Frontend/src/features/auth/pages/SignupPage.tsx` (brand name,
  "HBCA Assistant").
- `ADMIN/adminFrontend/.../StudentDetailPage.tsx` (delete-account wording
  this policy's retention section matches).

---

**Completed By:** Tinotenda Mupezeni (with Claude Code)
**Duration:** ~1.5 hours
