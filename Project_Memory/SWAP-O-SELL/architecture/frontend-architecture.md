# SWAP-O-SELL — Frontend Architecture

**Last updated:** 2026-11-26

## Two separate frontends, two separate stacks
- **Storefront** (`swappify-social-hub/`): React 18 + Vite + TypeScript +
  shadcn/Tailwind + Radix primitives. Bootstrapped from Lovable.dev
  originally (explains leftover scaffold assets, e.g. the default favicon
  that the admin app used to inherit — see
  [[admin-inherits-lovable-favicon]]). Key pages/components referenced in
  dev-log history: `pages/ProductDetail.tsx`, `pages/Messages.tsx`,
  `components/SwapOfferModal.tsx`, `components/OrderPanel.tsx`,
  `components/ProductCard.tsx`, `components/CommentsModal.tsx`,
  `components/messaging/MessageModal.tsx`, `server/Server.tsx` (typed API
  client), `server/AuthContext.tsx`.
- **Admin** (`admin/`): separate React + Vite + TypeScript app, no
  Tailwind/shadcn (uses `lucide-react` directly). Package name
  `swap-o-sell-admin`. Production build served statically via Nginx with a
  `/admin/` base path — this base path has caused a real SPA-asset-routing
  bug, see [[admin-spa-blank-page]].

## API client pattern
Both frontends read `VITE_API_URL` at build time to target the backend.
This is a Vite build-time env var baked into the static bundle — it is
**not** something that can be changed by just restarting a container; a
real rebuild with the var actually wired through Docker build args is
required, and that wiring broke silently for a long time (every prior
production build was hardcoded to `127.0.0.1:8000` regardless of the var —
see [[vite-api-url-never-baked-in]]). The storefront's typed API client
lives in `src/server/Server.tsx`; it maps backend string UUIDs through to
product/user/comment/order payload fields.

## Non-obvious identity handling
Public product/user IDs are UUID strings end-to-end in the frontend (route
params, API payloads, component props) even though the backend's internal
storage is integer-keyed. `ProductDetail.tsx` no longer has any static/demo
product fallback — a missing or failed API response is an explicit
loading/not-found UI state, not a silently-wrong static page.
