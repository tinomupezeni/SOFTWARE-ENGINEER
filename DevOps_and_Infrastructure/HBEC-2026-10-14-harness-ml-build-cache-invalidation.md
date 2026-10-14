# Harness ML Image Rebuilt Expensive Layers on Every Commit

**Date:** 2026-10-14  
**Project:** HBEC  
**Environment:** Production build host (`hbca-vps`)  
**Severity:** Medium  
**Status:** Resolved in source

## Summary

The `hbec-harness-ml` image repeatedly rebuilt its dependency and embedding
model layers during blue-green deployments. Docker BuildKit cache was present
on the VPS, but the Dockerfile placed the commit-specific image label before
the expensive layers, so every new `GIT_SHA` invalidated the cache through the
model download.

## Symptoms

- Each manual deployment spent several minutes rebuilding `hbec-harness-ml`.
- The Hugging Face embedding model was downloaded again for each commit-tagged
  image.
- The VPS retained substantial BuildKit cache, but the expensive model layer
  was not reused.

## Root Cause

`ARG GIT_SHA` was consumed by a `LABEL` before the runtime dependency copy,
application copy, and `snapshot_download` layer. A changed build argument
invalidates that instruction and all following layers. `embedding_server.py`
was also copied before the model download, so application-only changes could
invalidate the model layer.

## Prevention / Rule

**Guardrail:** Keep commit-specific labels and application source copies after
all stable dependency and model-download layers in ML Dockerfiles.

This preserves the cache key for the expensive layers while still stamping the
final image with the exact deployed revision.

## Solution

`AGENTIC_HARNESS/Dockerfile.ml` now:

- downloads dependencies and the embedding model before copying application
  source;
- places `GIT_SHA`/`BUILD_DATE` labels at the end of the image build;
- preserves the final image revision label used by deployment verification.

The current blue deployment (`d34f84e`) passed all gates before this source
optimization was added; the optimization applies to the next image build.

## Verification

- Docker BuildKit cache inspected on `hbca-vps`; substantial reusable cache was
  present.
- The cache invalidation mechanism was confirmed from Dockerfile instruction
  order.
- The source diff was checked for whitespace errors.

---

**Resolved By:** Copilot
