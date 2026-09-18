# Editable Content Registry Silently Diverged From What the Storefront Actually Renders

**Date:** 2026-09-18
**Project:** chemglee-concept-site
**Environment:** Production
**Severity:** High (staff-facing admin controls that appeared to work but silently did nothing — the same failure shape as an already-logged HBEC incident)
**Status:** Resolved (merged to `main` via PR #4, commit `7bedee0`)

## Summary
Every editable storefront string is meant to exist twice on purpose: a
`Field()` registered in `site_copy.py` (what the admin edits) and an inline
`t(key, default)` fallback in the storefront component (so the site still
renders correctly with the API down). Nothing actually held the two sides
together except a sentence in the README, and across roughly 340 such
pairs that discipline had already failed ten times over:
- **Five footer contact details were editable in the admin while the
  footer printed literals.** Staff could change the company phone number or
  email in Shop Manager, see "1 edited" confirm the save, and the storefront
  would show the old value forever — the exact "admin control that lies
  about its effect" shape already logged for HBEC's model-settings feature
  (`chemglee-concept-site-2026-09-17-notification-settings-plaintext-credential-storage.md`
  is a different flavor of the same underlying lesson: an admin surface that
  looks functional isn't proof it's wired to anything real).
- **The two most prominent homepage buttons had no `Field()` at all**, so
  they could never be edited regardless of what staff tried.
- **A headline and the footer's opening hours were registered but rendered
  nowhere** — the opposite failure: an editable field with no effect
  because nothing ever reads it.
- **The public content API leaked ~20KB of default copy on a fresh
  install.** Seeding each row's stored value with its shipped default (so
  the admin editor can show "current copy") meant the *public* endpoint —
  meant to return only staff overrides — quietly returned all ~340 keys
  instead of `{}`, duplicating strings the storefront already carries
  inline.
- **`registry.sync()` ran ~684 queries on every `migrate`** (i.e. every
  container start): a `get_or_create` plus a `save()` per field, rewriting
  identical values most of the time.
- **`post_migrate` swallowed sync failures for both the content registry
  and the policy pages equally** — correct for content copy (failure is
  invisible and harmless) but wrong for policy pages, whose failure means
  shipping a shop that takes card payments with five dead footer links to
  its own terms/privacy/returns pages.

## Root Cause
The registry and the storefront's inline fallbacks were two independent
sources of truth with no automated check that they actually agreed — drift
between "what staff can edit" and "what the page renders" accumulated
silently over ~340 keys until this audit diffed them directly.

## Solution
- A new test reads the storefront source and diffs it against the registry
  in both directions (registered-but-unrendered, and rendered-but-unregistered),
  catching a key given two different fallback defaults as well. It found 4
  of the 10 known-broken pairs itself, after manual review had already
  found the other 6.
- The public content endpoint is now filtered in SQL to rows staff have
  actually changed — `{}` on a fresh install, one key per real edit.
- `registry.sync()` now does one `in_bulk` read, then `bulk_create`/
  `bulk_update` only for rows that genuinely differ — one query in the
  steady state.
- Policy-page sync failures are no longer swallowed by `post_migrate`;
  content-copy sync failures still are (deliberately — that failure mode is
  harmless, the policy-page one isn't).

## Prevention
- [x] Code changes required — done (the registry/storefront cross-check
      test now runs as part of the suite, so future drift fails CI instead
      of shipping silently)
- [ ] Consider extending the same "does the admin control actually do
      anything" cross-check pattern to other admin-editable surfaces in
      this codebase (e.g. `NotificationSettings`, `PaynowConfig`) as a
      general-purpose guardrail, not just content copy.

## References
- Commit `7bedee0` ("Make the content system check itself, and stop paying
  for it twice"), merged to `main` in this session's PR #4 merge (`8bcc3dd`).
- `backend/apps/content/registry.py`, `policies.py`, `site_copy.py`,
  `views.py`, `backend/apps/content/tests/test_registry_matches_storefront.py`

---

**Resolved By:** winstonjthinker + Claude Opus 5 (1M context), PR #4
**Time to Resolution:** N/A (site audit)
