# Admin-Configurable Email Branding

**Date:** 2026-09-29
**Project:** HBEC
**Type:** Feature (new capability, cross-service)
**Status:** Completed (staging; production not requested)

## Summary
Admins can now configure branding (logo, brand color, footer text, app
URL) applied to student-facing emails, added as a new `emailBranding`
settings category on the existing generic Admin Backend settings store.
Two emails were wired up to it: feedback replies (a teaser preview +
"open the app" CTA, driving engagement back into the product) and
password reset/changed emails (full actionable content, since a
locked-out student cannot "open the app" to get past a password reset).
A real logo file was deployed to staging and both paths were verified
with real end-to-end SMTP sends.

## Context / Trigger
Direct user request: "on admin side the admins on responding to emails
they want to customize and have branding on the emails being send... i am
thinking we add an email configuration on settings... check projectflow
using projectflow-mcp for this task." The user confirmed the proposed
design in three follow-ups: (1) confirmed the settings-category approach,
(2) confirmed the VPS-hosted URL + supplied an SVG logo file, (3) asked
for a plain-language explanation of the preview-vs-full-content
distinction between feedback-reply and password emails before approving
it ("yes lets go the projectflow way").

## Scope
**Included:**
- `emailBranding` settings category (`SystemSetting` key-value rows under
  the existing generic `system_settings` app — no new model needed),
  admin CRUD via the existing `SettingsCategoryView` generic pattern.
- `GET /_internal/settings/email-branding/` — signed (`SERVICE_TO_ADMIN`)
  internal endpoint Student Backend fetches branding from.
- Student Backend `core/email_branding.py` — `get_email_branding()`:
  signed fetch, 5-minute Django cache, hardcoded `DEFAULTS` fallback on
  any failure (missing config, timeout, non-200, bad JSON) — never
  raises, never blocks a send.
- Student Backend `core/branded_email.py` — `send_branded_email()` (the
  shared send primitive, renders `templates/emails/branded_base.html`),
  `preview_snippet()` (160-char HTML-escaped truncation),
  `app_cta_button()`.
- `FeedbackReplyEmailView` updated to send a preview + CTA instead of the
  full reply text.
- `send_password_reset_email_task` / `send_password_changed_email_task`
  updated to send full branded content.
- Real logo deployed to staging's media volume
  (`STUDENT/Frontend/public/favicon.svg`, supplied by the user).

**Explicitly excluded:**
- Production deployment — not requested for this feature; staging only.

## Method
Checked ProjectFlow for the task's exact spec before designing anything
(per direct instruction), then confirmed the two-tier content design
(preview+CTA vs. full-content) with the user before implementing, since
it wasn't obvious from the ticket alone why the two email types should
differ. Built the settings category first (reusing the established
generic `SystemSetting` pattern — zero new models), then the shared send
primitive, then wired both existing send paths through it.

## Decisions & Findings
- **Two different content rules by design, not oversight**: feedback
  replies get a teaser (Teams-notification style, meant to drive the
  student back into the app); password emails get full actionable content
  (a real clickable link), because a locked-out student has no "app" to
  open yet.
- **All branding consumers must import `get_email_branding` from
  `core.branded_email`, never directly from `core.email_branding`** —
  discovered while writing tests: they're the same function re-exported,
  but `unittest.mock.patch` binds to the *importing* module's name, so a
  test patching `core.branded_email.get_email_branding` would silently
  not affect a call site that imported the other module's binding
  directly. Consolidated every consumer onto one import path so one patch
  target covers all of them.
- **Found and fixed a real, unrelated, pre-existing bug** while wiring up
  the logo URL: Admin Backend's `/media/` route 404'd unconditionally
  outside `DEBUG` (doubly-redundant guard around
  `django.conf.urls.static.static()`, which already refuses to serve
  outside `DEBUG` internally) — full detail in the companion bug-log
  entry.

## Changes Made
- `ADMIN/adminBackend/apps/system_settings/` — `emailBranding` category
  in `DEFAULTS`, `InternalEmailBrandingSettingsView`.
- `STUDENT/hbec_backend/core/email_branding.py` (new),
  `core/branded_email.py` (new), `templates/emails/branded_base.html`
  (new).
- `STUDENT/hbec_backend/apps/internal/views.py` —
  `FeedbackReplyEmailView` updated to preview+CTA.
- `STUDENT/hbec_backend/apps/accounts/tasks.py` —
  `send_password_reset_email_task`, `send_password_changed_email_task`
  updated to full branded content.
- `ADMIN/adminBackend/config/urls.py` — `/media/` route fix (own bug-log
  entry, see References).
- Deployed to staging; real logo file placed in staging's media volume.

## Verification
- Django checks clean on both backends.
- Real end-to-end SMTP sends verified on staging for both the
  feedback-reply preview+CTA path and the password reset/changed
  full-content path.
- Logo URL confirmed serving `200` with correct content-type after the
  `/media/` route fix.

## Follow-ups / Deferred
- Not promoted to production — no request made for this feature to ship
  there yet.
- This report was filed retroactively, after the fact was noticed while
  logging a later feature in the same problem area (Custom Email
  Composer) — the feature itself shipped to staging same-day, only the
  write-up lagged.

## References
- `DevOps_and_Infrastructure/HBEC-2026-09-29-admin-media-404-outside-debug.md`
- `reports/HBEC-2026-09-29-custom-email-composer.md`

---

**Completed By:** Claude Sonnet 5
**Duration:** Single session
