# ZIMSEC Mathematics past papers were unpublished — unusable without math OCR

**Date:** 2026-09-21
**Project:** HBEC
**Environment:** Staging
**Severity:** Medium
**Status:** Resolved (worked around by unpublishing; root fix is enabling math OCR)

## Summary
After earlier fixes made Mathematics past papers visible again (see the
`replay_dropped_messages` entry from the same day), a student reported the
question content itself was broken. Every question consisted of the literal
string `"[mathematical expression — refer to the printed paper]"` repeated
once per formula — the documented, intentional fallback in
`AGENTIC_HARNESS/math_ocr_server.py` for content `pdf_layout` cannot decode,
which the harness's own docs already flag: *"that fallback must never be
replaced by the extracted characters... a whole notice, never the mangled
text."* Math OCR is off by default on this deployment (`tesseract` backend
declares `reads_mathematics: false`; the capable `unlimited` backend is
parked pending more RAM). ZIMSEC Mathematics papers are essentially all
formulas, so effectively 100% of their question content hit this fallback.

## Symptoms
Every question in every seeded ZIMSEC Mathematics (subject `4004`, Form 4)
past paper displayed only the OCR-unavailable placeholder text, with no
real question content — unusable for practice despite being marked
"published."

## Environment Details
- **Server/Host:** hbca-vps (209.209.42.142), staging
- **Services Affected:** Admin exam paper corpus (`apps.exam_papers.ExamPaper`), student mirror (`apps.practice.Paper`)

## Root Cause
Not a bug — the fallback behaved exactly as designed. The gap is upstream:
the ZIMSEC corpus (see `research/semantic/zimsec_corpus_baseline.md`,
already measuring "Mathematics, the biggest subject, is the worst at 22%
readable") was seeded into a deployment with no working math-capable OCR
backend, so its math-heavy papers were guaranteed to be unusable the moment
they published.

## Prevention / Rule
**Guardrail:** the seed pipeline (`seeds/tools/validate_seeds.py` or the
admin seed command) should flag or skip papers whose content is
disproportionately OCR-fallback text at seed time, rather than let them
publish and rely on manual discovery. A simple threshold (e.g. reject a
paper whose question content is >X% the exact fallback string) would have
caught this before a student did.

## Solution

### Immediate Fix
Unpublished (status → `rejected`) all `past_paper`-sourced ExamPaper rows
under Mathematics (subject `4004`, board `ZIM-HBCA`) on both admin (85 rows
— the full historical set, not just today's 22, so a future replay/resync
can't silently reintroduce the same unusable content) and student (22 rows,
the ones currently visible). The 50 AI-generated (`student_generated`)
Mathematics papers were left untouched — they contain real text, not OCR
fallback, since they were never extracted from a scanned PDF.

### Long-term Fix
Either enable a math-capable OCR backend (the `unlimited` backend is fully
built and tested, parked only on a RAM constraint per its own docs) before
republishing this content, or add the seed-time guardrail above so
unusable-without-OCR content never reaches "published" in the first place.

## Prevention
- [x] Unpublish the unusable content (staging)
- [ ] Add seed-time OCR-fallback-ratio check
- [ ] Decide: enable math OCR, or permanently exclude math-heavy ZIMSEC papers from this corpus until it is
- [ ] Same unpublish likely needed on production once/if this corpus is promoted there

## Related Issues
- `Backend_and_API/HBEC-2026-09-21-replay-dropped-messages-never-replayed-anything.md` — the fix that made this content visible in the first place, surfacing this separate, pre-existing content-quality gap

## References
- `AGENTIC_HARNESS/math_ocr_server.py` (the documented fallback behavior)
- `research/semantic/zimsec_corpus_baseline.md` (the 22% Mathematics readability measurement)

---

**Resolved By:** Claude Sonnet 5 (with tinomupezeni)
**Time to Resolution:** ~10 minutes
