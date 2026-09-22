# Admin's Generic Settings Store Let `trialDays` Reach -35 With No Validation Anywhere

**Date:** 2026-09-22
**Project:** HBEC
**Environment:** Discovered live on staging while verifying an unrelated fix
(`GET /api/subscription/` for a test signup returned `"trialDays": -35`)
**Severity:** Medium — currently inert only by coincidence (`trialEnabled`
was also `False`), but a live landmine: the next trial started after
someone re-enables trials would be backdated 35 days and already expired,
with nothing telling anyone why
**Status:** Resolved

## Summary
While verifying the family-plans fix
(`HBEC-2026-09-22-family-plans-not-shown-or-billed-correctly.md`) on
staging, a test parent signup's subscription payload showed
`trialDays: -35`. Traced to admin's `system_settings` app: settings are
stored as a fully generic key/value store with a `DictField()` serializer
that accepts any key, any value, no field-specific validation. The admin
frontend's Trial Period number input also had no `min` attribute. Nothing
in the chain — frontend, serializer, or model — could have refused a
negative number.

## Symptoms
- `trialDays` stored as `-35` in the `hbec_admin` staging database, with
  no error, warning, or log anywhere marking how it got there.
- Confirmed via Django shell against staging (`SystemSetting.objects.get(key="trialDays").value`) rather than guessed.

## Environment Details
- **Server/Host:** staging (`hbca-vps`, `hbec-admin-backend-staging`)
- **Services Affected:** Admin Backend (`system_settings`), Admin Frontend
  (Subscription Settings page), downstream: Payments/Student trial creation
  the moment `trialEnabled` is next turned on
- **Related Components:** `apps.system_settings.views.SettingsCategoryView`,
  `SettingsUpdateSerializer`, `SystemSettingsPage.tsx`
- **Time First Observed:** 2026-09-22, during unrelated staging verification

## Investigation Steps

### 1. Initial Diagnosis
Noticed `trialDays: -35` in a live API response while confirming the
family-plans fix. Checked whether it was currently doing any harm:
`trialEnabled` was also `False` on the same settings row, so no trial had
actually been created with it — coincidental, not by design.

### 2. Root Cause Analysis
```python
# apps/system_settings/serializers.py
class SettingsUpdateSerializer(serializers.Serializer):
    settings = serializers.DictField()
```
Deliberately unrestricted, by design — this store takes arbitrary
category/key pairs with no migration per new setting. `SettingsCategoryView.put()`
looped `serializer.validated_data["settings"].items()` straight into
`SystemSetting.objects.update_or_create()` with no bounds check. Grepped
`ADMIN/adminFrontend/src/features/system-settings/pages/SystemSettingsPage.tsx`
for all four numeric payment inputs (`trialDays`, `priceMonthly`,
`priceTermly`, `priceAnnually`) — all plain `<Input type="number">` with no
`min` attribute at all, so the browser itself imposed no floor either.

### 3. Key Findings
- Generic key/value settings stores are a class of gap: most stored
  settings are free-form strings/booleans this store deliberately never
  validates, but a wrong *number* sits silently until something reads it,
  unlike a malformed string that usually breaks immediately and visibly.
- The only thing currently preventing harm was an unrelated flag being off
  at the same time — not a guarantee.

## Root Cause
A generic, unvalidated settings serializer combined with a frontend number
input with no floor meant nothing in the write path could reject a
negative `trialDays` (or a negative flat price), and nothing in the read
path would have surfaced the mistake until a trial was actually created
against it.

## Prevention / Rule
**Guardrail:** `SettingsCategoryView.put()` now validates a fixed set of
known numeric payment keys (`trialDays`, `priceMonthly`, `priceTermly`,
`priceAnnually`) against `< 0` before writing anything, rejecting the
*entire* PUT atomically with a 400 if any one of them is negative — a
partial save would silently drop the one field that needed fixing. Backed
by `apps/system_settings/tests/test_settings_validation.py`.

This is a targeted allowlist, not general schema validation for the store
(that would defeat the point of a generic settings table) — it closes the
gap for the fields that are known to be load-bearing numbers today.

## Solution

### Immediate Fix
1. **Backend** (`ADMIN/adminBackend/apps/system_settings/views.py`):
   `_NON_NEGATIVE_NUMERIC_KEYS` set + a validation pass in
   `SettingsCategoryView.put()` before the existing save loop, returning
   `400 {"detail": f"{key} cannot be negative"}` and rejecting the whole
   update.
2. **Frontend** (`ADMIN/adminFrontend/src/features/system-settings/pages/SystemSettingsPage.tsx`):
   added `min="0"` to all four numeric payment inputs (Trial Period,
   Monthly/Termly/Annual Price).
3. **Live data**: corrected staging's stored `trialDays` from `-35` back
   to `14` (the documented default) via Django shell against
   `hbec-admin-backend-staging`.

### Long-term Fix
None beyond the above — the allowlist is intentionally small and named;
extend `_NON_NEGATIVE_NUMERIC_KEYS` if a future numeric setting needs the
same floor.

## Prevention
- [x] Code changes required — done (backend + frontend)
- [x] Documentation to update — this entry
- [x] Configuration changes needed — live staging value corrected
- [ ] Monitoring/alerts to add — n/a, closed at the write path instead

## Related Issues
Found alongside `HBEC-2026-09-22-family-plans-not-shown-or-billed-correctly.md`
while verifying that fix on staging; unrelated root cause. Also adjacent to
`HBEC-2026-09-18-trial-days-hardcoded.md` (an earlier, different bug in the
same trial-length setting — that one was about the setting being ignored
entirely; this one is about the setting accepting an invalid value once it
started being read).

## References
- `ADMIN/adminBackend/apps/system_settings/views.py` (`SettingsCategoryView`, `_NON_NEGATIVE_NUMERIC_KEYS`)
- `ADMIN/adminBackend/apps/system_settings/tests/test_settings_validation.py` (new)
- `ADMIN/adminFrontend/src/features/system-settings/pages/SystemSettingsPage.tsx`

---

**Resolved By:** Claude Sonnet 5
**Time to Resolution:** Same session — from a noticed value in a staging
API response to a verified fix across backend, frontend, and live data.
