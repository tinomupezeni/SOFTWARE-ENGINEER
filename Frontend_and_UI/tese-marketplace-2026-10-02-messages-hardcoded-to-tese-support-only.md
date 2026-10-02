# Buyer-seller chat worked server-side but was entirely hidden by a client-side "support only" filter

**Date:** 2026-10-02
**Project:** tese-marketplace (BFF architecture, store-api / customer-store)
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
The backend's `ChatService.get_or_create_conversation` already correctly
routed a product inquiry directly to its seller (`product.farmer_id`),
overriding the conversation to `conversation_type: "direct"` whenever
the product had one, falling back to `"support"` otherwise. None of that
ever reached a user: the customer-facing `/messages` page hardcoded its
existing-conversation lookup and its entire sidebar list to
`conversation_type === 'support'` only, so a correctly-created direct
seller conversation would never appear in the UI at all. Every screen
also hardcoded "TESE"/"T"/"TESE Marketplace" as the other participant's
name and avatar regardless of who the conversation was actually with,
so even a user who somehow reached a direct conversation (e.g. via a
raw API response) would see it mislabeled as a chat with "TESE."

## Symptoms
- User request: "test out https://tesemarket.com/messages, it supposed
  to now directly connect a buyer n seller" - the page returned 200 and
  looked functional, but nothing in it ever showed a seller's identity.

## Environment Details
- **Server/Host:** Production (`tesemarket.com`, `tese-customer-store` +
  `tese-store-api` containers)
- **Services Affected:** All buyer-initiated product chats
- **Related Components:**
  `apps/customer-store/src/features/messages/pages/ConversationPage.tsx`,
  `apps/customer-store/src/features/messages/components/ConversationsList.tsx`,
  `apps/customer-store/src/features/messages/components/MessagingScreen.tsx`,
  `apps/store-api/app/modules/chat/services/chat_service.py`,
  `apps/store-api/app/modules/chat/schemas/chat.py`,
  `apps/store-api/app/modules/chat/routes/chat.py`
- **Time First Observed:** 2026-10-02

## Investigation Steps

### 1. Initial Diagnosis
Read the backend chat service first rather than assuming the whole
feature needed building from scratch - found
`get_or_create_conversation` already had the correct farmer-routing
logic (`if product.farmer_id: partner_id = product.farmer_id;
target_conv_type = "direct"`), stored in the `admin_id` column.

### 2. Root Cause Analysis
Read `ConversationPage.tsx` and found, with an explicit comment
confirming the assumption: `// Customer app: Only support conversations
(product inquiries)`, hardcoding `conversationType="support"` into
`ConversationList`, and a `conversation_type === 'support'` filter in
the existing-conversation lookup used before creating a new one.
Checked `ConversationsList.tsx` and `MessagingScreen.tsx` and found
every participant-identity surface (avatar initial, sender label, "who
you're chatting with" banner, trust badges) hardcoded to "TESE"/"T"/
"TESE Marketplace" literals - the API response (`ConversationResponse`)
had no field for the other participant's actual name at all, so there
was nothing to display even if the filters were removed.

### 3. Key Findings
- This wasn't a half-built feature needing new backend logic - the
  routing was already correct and already tested-against by nothing,
  since the UI that would have exercised it filtered the result away
  before it could ever be seen.
- Fixing the filters alone would have "worked" in the sense of showing
  the conversation, but every screen would still have mislabeled a real
  seller as "TESE" - the identity gap in `ConversationResponse` had to
  be closed too for the fix to actually mean anything to a user.

## Root Cause
Two independent gaps compounded: (1) the customer-facing UI was written
before per-product seller routing existed and was never updated once it
did, leaving a hardcoded support-only filter; (2) the API response never
exposed who the other participant in a conversation actually is, so
even an unfiltered UI would have had nothing correct to render.

## Prevention / Rule
**Guardrail:** When a backend capability (here: direct seller routing)
is added to a shared service method, grep every consumer of that
service for hardcoded assumptions about the *previous* single-case
behavior (here: "every chat is with support") - a comment like
`// Customer app: Only support conversations` is itself the signal that
the consumer was never updated for the new capability.

## Solution

### Immediate Fix
Backend (`apps/store-api`):
- `chat/services/chat_service.py` - added
  `get_other_party_name(conversation, viewer_id)`, resolving the seller's
  `ProviderApplication.business_name` (falling back to `User.name`) when
  the viewer is the buyer, or the buyer's `User.name` when the viewer is
  the seller, or `"Tese Support"` for a non-direct conversation.
- `chat/schemas/chat.py` - added `other_party_name`/`is_direct` to
  `ConversationResponse`.
- `chat/routes/chat.py` - wired the new resolution into both
  `create_conversation` and `get_my_conversations`.

Frontend (`apps/customer-store`):
- `ConversationPage.tsx` - removed the `conversation_type === 'support'`
  filter from both the existing-conversation lookup and the sidebar list
  (a user has exactly one conversation per product regardless of which
  type the backend decided on); replaced every hardcoded "TESE
  Marketplace" header/badge with the real `other_party_name`.
- `ConversationsList.tsx` - made the `conversationType` filter prop
  optional (shows every type when omitted); avatar badge, "who's this
  with" line, and the "X:"/"You:" message-preview prefix now use
  `other_party_name` instead of a fixed "T"/"TESE".
- `MessagingScreen.tsx` - "you're chatting with" banner, message bubble
  avatar, and sender label now use the real `other_party_name`.
- `messageServices.tsx` - added `other_party_name`/`is_direct` to the
  `ConversationSummary` type.

```bash
python3 -m py_compile <all changed backend files>   # clean
npx tsc --noEmit                                    # clean
pnpm --filter customer-store build                  # clean production build
```

Verified end-to-end in production with two real test accounts (a farmer
seller and a separate buyer): created a conversation on the farmer's
product, confirmed the backend response showed `conversation_type:
"direct"`, `other_party_name: "Engine Consolidation Test Farm"` from the
buyer's perspective; confirmed `GET /chat/conversations` as the seller
showed the same conversation with `other_party_name: "Buyer Tester"`;
sent a real message as the buyer and confirmed the seller could read it
via the API.

### Long-term Fix
None needed - the backend routing logic already existed and was
correct; this closed the gap between it and what users could actually
see and use.

## Prevention
- [x] Code changes required (done this session)

## References
- `apps/store-api/app/modules/chat/services/chat_service.py`
- `apps/store-api/app/modules/chat/schemas/chat.py`
- `apps/store-api/app/modules/chat/routes/chat.py`
- `apps/customer-store/src/features/messages/pages/ConversationPage.tsx`
- `apps/customer-store/src/features/messages/components/ConversationsList.tsx`
- `apps/customer-store/src/features/messages/components/MessagingScreen.tsx`

---

**Resolved By:** Claude Sonnet 5 (session with tinomupezeni)
**Time to Resolution:** ~45 minutes from report to verified fix in production
