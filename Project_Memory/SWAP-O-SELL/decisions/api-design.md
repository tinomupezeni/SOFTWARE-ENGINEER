# SWAP-O-SELL — API Design Decisions

**Last updated:** 2026-11-26

## Public UUID identifiers over integer primary keys — 2026-10-15
**Chose:** Add unique, indexed `public_id` UUID columns to `User` and
`Product`, expose those as the client/API identity, and keep existing
integer primary keys as the internal/FK identity unchanged.
**Alternatives considered:** Replacing integer PKs outright with UUIDs
(rejected — destructive, would require touching every FK: comments,
orders, likes, saves, analytics); keeping sequential integer IDs in URLs
(rejected — leaked sequential identifiers and enabled enumeration of
users/products).
**Why:** Needed non-enumerable public identifiers (`/product/<uuid>`)
without a disruptive, risky rewrite of relational integrity across the
whole schema.
**Still valid?** Yes. Template for any future public-identifier work —
see `architecture/database-architecture.md` "Migration conventions".

## Swap offers as a separate model, not a repurposed Order — 2026-10-15
**Chose:** A dedicated `SwapOffer` model (listing + optional listing +
optional cash top-up, with its own status/accept/decline/withdraw
lifecycle), reusing the existing direct-messaging system for conversation
context rather than inventing a new comms channel.
**Alternatives considered:** Forcing the two-sided exchange into the
existing single-product `Order` model (rejected — `Order` models a single
product changing hands for a price, not two products with asymmetric
ownership and consent).
**Why:** The existing `Order`/messaging/listing boundaries were sound,
and a swap is structurally a different transaction type than a sale.
**Still valid?** Yes, but the phase intentionally stops at offer
acceptance — settlement (inspection, payment verification, pickup OTP,
product locking, disputes) is explicit future work, not yet designed.

## Messaging/product identity must be UUID-consistent end-to-end — 2026-10-15
**Chose:** Conversation serializers must resolve generic-relation product
references to the product's public UUID, and the same UUID identity must
be used both to create and to match an existing conversation.
**Alternatives considered:** Leaving conversation lookups on internal
integer IDs and only UUID-izing the "edges" (listings/users) — rejected,
this is what originally caused repeated HTTP 400s / duplicate conversation
creation when the frontend's seller-message flow mixed UUID and integer
identity across the same request/response cycle.
**Why:** Partial UUID adoption left an identity mismatch between
conversation creation and conversation matching.
**Still valid?** Yes — see [[messaging-uuid-contract]] cross-reference in
`Integrations_and_Auth/` bug logs.

## Admin-vs-client user separation is authorization-based, not display-based — 2026-10-15
**Chose:** The admin Users API groups accounts into `clients` vs `staff`
using Django's `is_staff` flag as the sole boundary.
**Alternatives considered:** Using the user-facing `role` display field
(rejected — conflates display/marketing role with actual authorization
state, and would misclassify operational/seeded accounts like `admin` as
marketplace clients).
**Why:** Keeps superusers/staff out of customer-facing operational counts
while preserving their visibility to admins.
**Still valid?** Yes.
