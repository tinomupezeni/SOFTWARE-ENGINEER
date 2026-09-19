# ADR-002's Cash-Settlement Ledger Design Contradicted Maricho's Own "Worker Never Charged" Business Model

**Date:** 2026-09-18
**Project:** MARITCHO
**Environment:** Development
**Severity:** Medium
**Status:** Resolved (caught before implementation — see Solution)

## Summary
ADR-002 (`docs/architecture/adr/002-cash-settlement-and-multi-currency-ledger.md`), drafted during the Zimbabwe-adjusted case-study reconciliation, specified that for cash-settled jobs "the platform's take-rate is debited from that [worker's] wallet" — a worker pre-funds a commission wallet via EcoCash, and the platform's cut is extracted from it. This directly contradicts `docs/discovery/business_case.md`'s explicit, foundational monetization principle: *"Maricho is built to monetize the demand side (the buyer) while remaining entirely free for the supply side (the worker). Charging the worker selects for desperation, not skill."* The ADR would have had workers pay to keep receiving cash-payable job dispatch — precisely the "charging the worker" pattern the business case rejects by design.

## Symptoms
- ADR-002's Decision §2: "workers pre-fund a platform commission wallet (via EcoCash top-up); on job completion, the platform's take-rate is debited from that wallet."
- ADR-002's Consequences §Negative already flagged the resulting failure mode ("requires workers to maintain a positive wallet balance to keep receiving cash-payable job dispatch") without recognizing that failure mode is itself the exact anti-pattern the business case names.
- Caught only when actually starting implementation (LEDG-001) and re-reading `business_case.md`'s revenue-model section as a sanity check before writing the wallet/EcoCash code — not caught when the ADR was originally drafted.

## Environment Details
- **Server/Host:** local dev, `/home/shadowe/Projects/MARITCHO`
- **Services Affected:** `docs/architecture/adr/002-cash-settlement-and-multi-currency-ledger.md` (design doc only — no code had been written against it yet)
- **Related Components:** `docs/backlog.md` `LEDG-001`
- **Time First Observed:** 2026-09-18, while scoping the EcoCash integration for `LEDG-001` and re-checking the revenue model in `business_case.md` before writing any wallet/ledger code

## Investigation Steps

### 1. Initial Diagnosis
Before implementing the worker-wallet EcoCash top-up flow ADR-002 called for, re-read `business_case.md`'s "Financial Modeling & Revenue Streams" section as a sanity check on the fee model (percentage rate, who pays it) — a step taken specifically because the previous session's case-study synthesis had been done without cross-checking every generated ADR against this document line by line.

### 2. Root Cause Analysis
The case-study report's "Cash Pre-Funding Ledger Pattern" (modeled loosely on Urban Company's partner-commission-wallet mechanic) was adapted into ADR-002 without checking it against Maricho's own, already-written business case — which takes an explicitly different position (buyer-funded, worker-free) from the Urban Company-style platforms the case-study research surveyed. The adaptation exercise correctly rejected several Urban-Company patterns elsewhere (capital-heavy training academies, fixed-SKU pricing) but this one slipped through because the ledger mechanics looked reasonable in isolation and weren't cross-checked against the monetization model specifically.

### 3. Key Findings
- No code was written against the flawed design — this was caught during LEDG-001's implementation kickoff, before any wallet/ledger schema or EcoCash client code existed, because the sanity-check re-read happened first.
- The corrected model is actually simpler to build, not harder: the platform's fee is what gets collected digitally (via EcoCash) from the *buyer* at booking time (the existing `deposit_amount`/`DEPOSIT_HELD` mechanism already does exactly this) — there is no need for a separate worker-side wallet, top-up flow, or commission-debit ledger at all. The worker simply collects their portion of the job value directly from the buyer in cash, which Maricho never touches or needs to release.

## Root Cause
A generic cross-case-study pattern (worker-side commission wallet, common among Urban-Company-style *managed, worker-commission* marketplaces) was adopted into a Maricho-specific ADR without checking it against Maricho's own already-documented monetization model, which deliberately rejects charging workers at all.

## Prevention / Rule
**Guardrail:** Any ADR or design decision touching money movement, fees, or who pays what must explicitly cite and reconcile against `docs/discovery/business_case.md`'s "Financial Modeling & Revenue Streams" section in its Context, the same way ADRs already cite the PRD/vision doc for other claims. A financial-design ADR with no line referencing that section should be treated as unreviewed.

This closes the gap because it forces the exact cross-check that would have caught this the first time — the omission wasn't a lack of care in general, it was a missing specific reference point.

## Solution

### Immediate Fix
Corrected ADR-002 (same file) to replace the worker-wallet-debit model with a buyer-funded model consistent with `business_case.md`:
- The platform's fee is collected digitally (EcoCash) from the **buyer** at booking time — reusing and extending the existing `deposit_amount`/`DEPOSIT_HELD` mechanism, now explicitly framed as (at minimum) covering the platform's fee, not necessarily the full job value.
- The **worker** collects their portion of the agreed price directly from the buyer, in cash, off-platform. Maricho never holds or releases that portion for a cash-settled job.
- No worker-side wallet, no worker top-up flow, no commission debit from worker funds, at any point.
- EcoCash integration point moves from "worker tops up a wallet" to "buyer pays a booking deposit/fee via EcoCash" — a checkout/collection flow, not a wallet system.

### Long-term Fix
Re-scope `LEDG-001` against the corrected ADR-002 before writing any code (this entry exists specifically so that rescoping has a documented reason, not just a silent change of direction).

## Prevention
- [x] Corrected ADR-002 to a buyer-funded model, consistent with `business_case.md`
- [ ] Establish the "must cite business_case.md's revenue section" convention for future financial-design ADRs (see Prevention/Rule above) — not yet written into any process doc, just applied here

## Related Issues
- Discovered while scoping `LEDG-001`, itself sourced from the same 2026-09-18 case-study reconciliation that produced ADRs 002–006

## References
- `docs/discovery/business_case.md` — "Maricho is built to monetize the demand side (the buyer) while remaining entirely free for the supply side (the worker)."
- `docs/architecture/adr/002-cash-settlement-and-multi-currency-ledger.md`
- `docs/backlog.md` `LEDG-001`

---

**Resolved By:** Claude Code (backlog implementation session), caught via a pre-implementation sanity check
**Time to Resolution:** Same day, caught before any code was written
