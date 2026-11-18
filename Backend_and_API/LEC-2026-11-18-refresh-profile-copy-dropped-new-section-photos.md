# `refresh_profile_copy` Dropped Photos on Newly Added Sections

**Date:** 2026-11-18
**Project:** LEC Biotec
**Environment:** Production (would have surfaced on first `--apply` run)
**Severity:** Medium
**Status:** Resolved

## Summary
PR #61 (LEC-090, "align site copy and tagline with company profile") added a
brand-new `media_split` section to the About page via
`apps/api/apps/content/management/commands/refresh_profile_copy.py`. The
command's `profile_sections()` built every page's section list by calling the
`seed_content` builders (`_home`, `_about`, etc.) with an **empty** `images`
dict, so any section the command *creates* for the first time on a real CMS
got `media_id` baked in as `None` — the new team photo would have been
silently dropped the moment someone ran `--apply` against production.

## Symptoms
- None observed yet in production — caught during code review of PR #61
  before merge, using the `code-review` skill at medium effort.
- Would have manifested as: the About page's new "team" `media_split`
  section publishing with no photo, on the very first `--apply` of this
  command against the live CMS.

## Environment Details
- **Server/Host:** N/A — caught pre-merge, in review.
- **Services Affected:** `apps.content` management command
  `refresh_profile_copy`.
- **Related Components:** `apps/content/management/commands/seed_content.py`
  (`_media_id`, `_upload_images`, `IMAGE_ALT`), `apps/media/models.py`.
- **Time First Observed:** 2026-11-18, during PR review (not production).

## Investigation Steps

### 1. Initial Diagnosis
A `code-review` skill pass over PR #61's diff flagged that
`profile_sections()` calls `seed._home({})`, `seed._about({})`, etc. with a
hardcoded empty dict instead of a real `images` map.

### 2. Root Cause Analysis
Existing sections are protected because `PRESERVED_FIELDS` (includes
`media_id`) makes `merge_copy()` skip overwriting an existing section's photo
with the proposed (empty) one. But a section with no existing counterpart on
the page goes through `services.add_section(... content=content ...)`
directly — there is nothing to merge against, so whatever `media_id` is in
`content` (here, always `None` from `_media_id({}, name)`) is what gets
saved.

```bash
git diff origin/main...pr-61-review -- apps/api/apps/content/management/commands/seed_content.py
# confirmed the About page's media_split section (img10.jpeg) is new in this PR,
# not an update to an existing section
```

### 3. Key Findings
- `_media_id(images, name)` returns `None` whenever `name` isn't a key in
  `images`; an empty dict means every image resolves to `None`.
- `refresh_profile_copy` assumes the CMS (and its media library) are already
  seeded — it refuses to run on an unseeded page — so the real assets exist
  in the library and only need to be looked up, not re-uploaded.
- `_upload_images` (used by `seed_content`'s own `handle()`) titles every
  asset `path.stem` (e.g. `"img10"` for `img10.jpeg`); that convention is
  stable enough to look assets up by title.

## Root Cause
`refresh_profile_copy.profile_sections()` never attempted to resolve the
company's existing library photos into the `images` dict the seed builders
expect; it passed an empty dict unconditionally, which is silently correct
for *updates* (protected by `PRESERVED_FIELDS`) but silently wrong for any
*newly created* section.

## Prevention / Rule
**Guardrail:** any management command that reuses a `seed_content` section
builder (`_home`, `_about`, `_products`, `_sectors`, `_stem`) outside of
`seed_content.handle()` itself must build a real `images: dict[str,
MediaAsset]` by looking assets up in the library (e.g. by the `title=path.stem`
convention), never pass `{}` — a test should assert that a newly-added
section gets a real `media_id`, not just that existing sections keep theirs.

This closes the gap because the bug only surfaces for sections with no
existing counterpart to protect them via `PRESERVED_FIELDS`, which a test
that only edits/checks *existing* sections (as the pre-existing test suite
did) will never exercise.

## Solution

### Immediate Fix
Added `_existing_images()` to `refresh_profile_copy.py`, which queries
`MediaAsset` by `title` for every filename in `seed_content.IMAGE_ALT` and
returns the same `dict[str, MediaAsset]` shape the seed builders expect;
`profile_sections()` now passes that instead of `{}`.

```python
def _existing_images() -> dict[str, MediaAsset]:
    stems = {name.removesuffix(".jpeg"): name for name in IMAGE_ALT}
    assets = MediaAsset.objects.filter(kind=MediaKind.IMAGE, title__in=stems)
    return {stems[asset.title]: asset for asset in assets if asset.title in stems}
```

### Long-term Fix
Added a regression test,
`test_apply_resolves_the_library_photo_for_a_newly_added_section`, that
deletes the About page's `media_split` section, uploads a library asset
titled `img10`, runs `refresh_profile_copy --apply`, and asserts the
recreated section's `media_id` resolves to that asset rather than `None`.

## Prevention
- [x] Code changes required (`_existing_images()` + wiring)
- [x] Regression test added
- [ ] Consider a shared helper between `seed_content._upload_images` and this
      lookup if a third command needs the same resolution later
- [ ] Documentation to update — none needed beyond the test/docstring

## Related Issues
- PR #61 / LEC-090 — the change this bug was found in.

## References
- `apps/api/apps/content/management/commands/refresh_profile_copy.py`
- `apps/api/apps/content/management/commands/seed_content.py`
- `apps/api/apps/content/tests/test_refresh_profile_copy.py`

---

**Resolved By:** Claude (code review + fix, approved by tinomupezeni)
**Time to Resolution:** Same session, before merge to `main`
