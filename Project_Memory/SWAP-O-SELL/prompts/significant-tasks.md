# SWAP-O-SELL — Significant Task Prompts

**Last updated:** 2026-11-26

## Public UUID + dynamic product detail migration — 2026-10-15
**Prompt:** (paraphrased from report) Replace sequential, enumerable
product/user URLs and the static demo product-detail page with a
UUID-identified, fully API-backed product detail experience, without
breaking existing integer-keyed relational data (comments, orders, likes,
saves, analytics).
**Why it's worth keeping:** The "expand-and-adopt" framing (add UUID
column + backfill, then switch public surface over, without touching
internal PKs) is the reusable template for any future public-identifier
change in this codebase — don't default to "just migrate the PK."
**Result:** `decisions/api-design.md` "Public UUID identifiers", `architecture/database-architecture.md`
"Migration conventions", `SWAPOSELL-2026-10-15-public-uuid-product-detail.md`.

## Swap-offer MVP scoping — 2026-10-15
**Prompt:** (paraphrased) Build the first real swap-plus-cash offer flow
(propose/accept/decline/withdraw) on top of the existing listing/order/
messaging system, deliberately deferring settlement mechanics.
**Why it's worth keeping:** The explicit scope boundary ("accepted offers
do not mark inventory sold yet") prevents a future session from assuming
swap-offer acceptance is a terminal state — it isn't, and settlement is
undesigned. Any future settlement work should treat this as the starting
contract, not reopen the "should this be a separate model" question.
**Result:** `decisions/api-design.md` "Swap offers as a separate model",
`SWAPOSELL-2026-10-15-swap-offer-mvp.md`.
