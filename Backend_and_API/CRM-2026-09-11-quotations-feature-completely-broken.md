# Quotations Feature Was Completely Non-Functional: Couldn't Create, Couldn't Even List

**Date:** 2026-09-11
**Project:** CRM Professional
**Environment:** Backend (discovered while writing the first backend test suite)
**Severity:** Critical (entire module down)
**Status:** Resolved

## Summary
The `quotations` app had zero test coverage before today. Writing the first tests for it surfaced that the feature was broken in two independent, compounding ways — a quotation couldn't be **read** without crashing, and couldn't be **created** without crashing either.

## Symptoms

### 1. Reading/listing any quotation raised `NameError`
`QuotationSerializer.get_revisions()` (`apps/quotations/serializers.py`) uses `models.Q(...)`, but the file never imports `django.db.models` — only `rest_framework.serializers` and the local `.models`. Since `get_revisions` runs on every serialization (`revisions` is a plain field on the serializer), **every GET to `/api/v1/quotations/` — list or detail — would 500**.

### 2. Creating any quotation raised `IntegrityError`
`QuotationViewSet.perform_create()` (`apps/quotations/views.py`) overrides `TenantQuerySetMixin.perform_create()` without calling `super()` or otherwise setting `organization`. Its own comment says *"The mixin sets organization"* — it doesn't; the override replaces it entirely. Result: `serializer.save(created_by=self.request.user)` never passed `organization`, so **every `POST /api/v1/quotations/` failed** with a not-null constraint violation on `quotations_quotation.organization_id`.

### 3. Creating a quotation *with line items* had a second, independent IntegrityError
Even after fixing #2, `QuotationSerializer.create()` creates nested `QuotationItem`/`ItemFormula` rows without passing `organization` (both are `TenantBaseModel` subclasses requiring it). Same bug was independently present in `QuotationService.add_item_with_formula()` and `QuotationService.create_revision()` (the item- and formula-cloning loop) — three separate call sites all missing `organization=`.

## Root Cause
`quotations` is a newer, less-exercised module (no tests existed, and it's plausible no real customer has used it yet since `"quotations"` was made a core/always-enabled module rather than opt-in). Each of the three bugs is a straightforward oversight — a missing import, a `perform_create` override that dropped required behavior from its parent, and a `TenantBaseModel` field left unset in three `*.objects.create()` calls — but together they meant the module could not do anything at all: not list, not create, not create-with-items.

## Prevention / Rule
**Guardrail:** Give `TenantBaseModel` a manager-level `create()` (or a `full_clean()`-enforced `organization` field with no default) so any subclass row created without an explicit `organization=` fails immediately and loudly, rather than relying on every call site remembering to pass it by convention.

Four separate call sites independently forgot the same required field — a model-level enforcement point turns "forgot it" into a fast, obvious failure in the first unit test that exercises the path, instead of a silent `IntegrityError` shipped to production traffic.

## Solution
- Added `from django.db import models` to `apps/quotations/serializers.py`.
- Fixed `QuotationViewSet.perform_create` to actually pass `organization=self.request.user.organization` (and removed the incorrect comment).
- Added `organization=` to all three `QuotationItem`/`ItemFormula` creation call sites: `QuotationSerializer.create()`, `QuotationService.add_item_with_formula()`, `QuotationService.create_revision()`.
- Built out the full test suite that was missing entirely: `apps/quotations/tests/{factories,test_services,test_views}.py` (16 tests), including regression tests naming each bug directly so they can't silently return.

## Prevention
- [x] Full test suite added — this module had literally none before today.
- [ ] Audit other less-exercised modules (this repo has several apps with thin or no coverage — `expenses` was also at zero before today) for the same class of "nobody's actually called this code path yet" bug.
- [ ] When overriding a mixin method like `perform_create`, either call `super()` or, if not possible, code-review specifically for what behavior the override is expected to preserve — the misleading comment here ("The mixin sets organization") is exactly the kind of drift that happens when an override silently stops doing what a comment still claims it does.

---

**Resolved By:** Claude Code
**Time to Resolution:** ~30 minutes (found and fixed while writing tests)
