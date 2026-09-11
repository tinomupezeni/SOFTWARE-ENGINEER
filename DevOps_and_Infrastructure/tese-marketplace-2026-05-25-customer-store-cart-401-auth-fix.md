# 2026-05-25: Customer Store Cart 401 Unauthorized - Auth Token Fix

**Date:** May 25, 2026 (21:30 UTC deployment)
**System:** TESE Marketplace - Customer Store Cart Service
**Severity:** HIGH - Cart functionality broken for authenticated users
**Type:** Authentication Integration Bug
**Status:** RESOLVED

---

## Executive Summary

Cart API calls were failing with 401 Unauthorized errors because the CartService was using its own axios instance that looked for authentication tokens in the wrong place.

**Root Cause:** CartService created custom axios instance that searched for `localStorage.getItem("access_token")` instead of using the auth system's token storage.

**Fix:** Replaced custom axios instance with main `axiosInstance` that uses `authStorage` and includes automatic token refresh.

**Impact:** All authenticated users unable to view/manage cart until fix deployed.

---

## The Bug

### Symptoms

**Browser Console Error:**
```
GET https://tesemarket.com/api/cart 401 (Unauthorized)

Failed to get cart: AxiosError: Request failed with status code 401
Error fetching cart items: AxiosError: Request failed with status code 401
```

**User Experience:**
- Cart page shows empty
- Cannot add items to cart (or appears empty after adding)
- Cart count shows 0
- Error messages in console

---

## Root Cause Analysis (5 Whys)

### WHY #1: Why is the cart API returning 401 Unauthorized?

**Answer:** The cart API endpoint requires authentication, but no auth token is being sent with the request.

**Evidence:**
```javascript
// Request headers (missing Authorization)
GET /api/cart HTTP/1.1
Host: tesemarket.com
// No Authorization: Bearer <token> header
```

Backend rejects request because it requires valid JWT token.

---

### WHY #2: Why is no auth token being sent?

**Answer:** CartService's axios instance interceptor is looking for token in `localStorage.getItem("access_token")` which doesn't exist.

**Evidence:**

**File:** `apps/customer-store/src/features/cart/services/cartServices.tsx` (line 15)
```typescript
// CartService - WRONG token lookup
cartApi.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token");  // ← Returns null!
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});
```

Token is `null`, so Authorization header is never added.

---

### WHY #3: Why doesn't "access_token" exist in localStorage?

**Answer:** The auth system doesn't store tokens under "access_token" - it stores them in a "user" object via `authStorage`.

**Evidence:**

**File:** `apps/customer-store/src/core/utils/authStorage.ts`
```typescript
const USER_KEY = "user";  // ← Stored under "user", not "access_token"

export const authStorage = {
  getToken(): string | null {
    const user = this.getUser();  // Gets from localStorage.getItem("user")
    return user?.token || null;    // Extracts token from user object
  }
}
```

**localStorage structure:**
```json
{
  "user": "{\"email\":\"user@example.com\",\"token\":\"eyJ...\",\"refreshToken\":\"...\"}"
}
```

**NOT:**
```json
{
  "access_token": "eyJ..."  // ← This doesn't exist
}
```

---

### WHY #4: Why did CartService use a different token lookup?

**Answer:** CartService created its own axios instance instead of using the main `axiosInstance` that already handles auth correctly.

**Evidence:**

**CartService (WRONG):**
```typescript
import axios from "axios";

const cartApi = axios.create({ baseURL: BASE_URL });

cartApi.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token");  // ← Wrong lookup
  ...
});
```

**Main App (CORRECT):**
```typescript
import { authStorage } from "@/core/utils/authStorage";

axiosInstance.interceptors.request.use((config) => {
  const token = authStorage.getToken();  // ← Correct lookup
  ...
});
```

Two different axios instances, two different token strategies, only one is correct.

---

### WHY #5: Why wasn't this caught during development?

**Answer:** Multiple possible scenarios:

1. **Developer tested while logged in via different flow** - If another part of the app accidentally set "access_token" in localStorage, cart would work in dev but break in production.

2. **Cart functionality not tested end-to-end** - Adding items to cart might use different code path than fetching cart.

3. **No integration tests for cart** - Would have caught auth token mismatch immediately.

**Missing Test:**
```typescript
test('cart API uses correct auth token', async ({ page }) => {
  // Login
  await loginUser(page, 'test@example.com', 'password');

  // Monitor network requests
  const cartRequest = await page.waitForRequest(req =>
    req.url().includes('/api/cart')
  );

  // Verify Authorization header present
  const authHeader = cartRequest.headers()['authorization'];
  expect(authHeader).toMatch(/^Bearer eyJ/);
});
```

---

## The Engineering Fix

### Changes Made

**File:** `apps/customer-store/src/features/cart/services/cartServices.tsx`

**BEFORE:**
```typescript
/**
 * Cart Service
 */
import axios from "axios";
import { toast } from "sonner";
import { BASE_URL } from "@/core/api/api";

const cartApi = axios.create({ baseURL: BASE_URL });

// Add auth header if token exists
cartApi.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token");  // ← WRONG
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

class CartService {
  static async getCart(): Promise<Cart> {
    const response = await cartApi.get("/cart");  // ← Uses wrong axios instance
    return response.data;
  }

  static async addToCart(data: AddToCartData): Promise<CartItem> {
    const response = await cartApi.post("/cart/items", data);
    return response.data;
  }

  // ... all other methods use cartApi
}
```

**AFTER:**
```typescript
/**
 * Cart Service
 */
import { toast } from "sonner";
import axiosInstance from "@/core/context/axiosInstance";  // ← Use main instance

// No custom axios instance needed anymore

class CartService {
  static async getCart(): Promise<Cart> {
    const response = await axiosInstance.get("/cart");  // ← Correct auth handling
    return response.data;
  }

  static async addToCart(data: AddToCartData): Promise<CartItem> {
    const response = await axiosInstance.post("/cart/items", data);
    return response.data;
  }

  // ... all other methods use axiosInstance
}
```

**Lines Changed:**
- Removed: `import axios` (line 7)
- Removed: `import { BASE_URL }` (line 9)
- Removed: `const cartApi = axios.create(...)` (line 11)
- Removed: `cartApi.interceptors.request.use(...)` (lines 14-20)
- Added: `import axiosInstance` (line 8)
- Replaced: All `cartApi` → `axiosInstance` (9 occurrences)

---

## Benefits of Using Main axiosInstance

### 1. Correct Token Lookup

**Main axios instance:**
```typescript
// axiosInstance.ts
const token = authStorage.getToken();  // ✓ Reads from "user" object
```

Gets token correctly from auth system.

### 2. Automatic Token Refresh

**Main axios instance includes 401 retry logic:**
```typescript
axiosInstance.interceptors.response.use(
  response => response,
  async (error) => {
    if (error.response?.status === 401 && !originalRequest._retry) {
      // Attempt to refresh token
      const refreshToken = authStorage.getRefreshToken();
      const response = await axios.post('/auth/refresh', { refresh_token: refreshToken });

      // Update tokens and retry request
      authStorage.setTokens(response.data.access_token, response.data.refresh_token);
      originalRequest.headers.Authorization = `Bearer ${response.data.access_token}`;
      return axiosInstance(originalRequest);
    }
  }
);
```

**Without this:** Cart requests fail if token expires mid-session.
**With this:** Token auto-refreshes and request succeeds.

### 3. Consistent Auth Behavior

All API calls now use same auth mechanism:
- Login/logout
- Products
- Orders
- Messages
- **Cart** ← Now matches others

### 4. Single Source of Truth

One place to update auth logic, all services benefit.

---

## Deployment

### Build

```bash
cd apps/customer-store
npm run build
```

**Output:**
- Bundle: `index-bWVF_SVz.js` (1,043.01 kB)
- CSS: `index-Dh-5ygC0.css` (99.21 kB)
- Build Time: 35.16s

### Deploy

```bash
tar -czf customer-store-dist.tar.gz dist/
scp customer-store-dist.tar.gz winstontino@159.198.42.231:/home/winstontino/

ssh winstontino@159.198.42.231
tar -xzf customer-store-dist.tar.gz
docker cp dist/. tese-customer-store:/usr/share/nginx/html/
rm -rf dist customer-store-dist.tar.gz
```

**Deployment Timestamp:** May 25 21:30 UTC

### Verification

```bash
docker exec tese-customer-store ls -lah /usr/share/nginx/html/index.html
# -rw-r--r-- 1 1000 1000 1.0K May 25 21:30 index.html

docker exec tese-customer-store cat /usr/share/nginx/html/index.html | grep -o 'index-.*\.js'
# index-bWVF_SVz.js ✓
```

---

## Expected Behavior After Fix

### Before Fix

**Cart Page Load:**
```
1. Page renders
2. useEffect calls CartService.getCart()
3. CartService uses cartApi.get("/cart")
4. Interceptor looks for localStorage.getItem("access_token")
5. Returns null (doesn't exist)
6. Request sent WITHOUT Authorization header
7. Backend returns 401 Unauthorized ✗
8. Cart shows empty/error
```

### After Fix

**Cart Page Load:**
```
1. Page renders
2. useEffect calls CartService.getCart()
3. CartService uses axiosInstance.get("/cart")
4. Interceptor calls authStorage.getToken()
5. Returns token from "user" object ✓
6. Request sent WITH Authorization: Bearer <token>
7. Backend validates token
8. Returns cart data ✓
9. Cart displays items
```

---

## Impact Assessment

### User Impact

**During Bug:**
- ❌ Cannot view cart
- ❌ Cart appears empty even after adding items
- ❌ Cart count shows 0
- ❌ Checkout blocked

**After Fix:**
- ✅ Cart loads properly
- ✅ Items display correctly
- ✅ Cart count accurate
- ✅ Checkout enabled

**Cache Warning:**
Users must hard refresh (Ctrl+Shift+R) to get new bundle.

---

## Prevention Measures

### 1. Standardize API Client Usage

**Create rule:** ALL services must use main `axiosInstance`, not create custom instances.

**Bad:**
```typescript
// ❌ DON'T create custom axios instances per service
import axios from "axios";
const customApi = axios.create({ baseURL: BASE_URL });
```

**Good:**
```typescript
// ✅ DO use main axios instance
import axiosInstance from "@/core/context/axiosInstance";
```

### 2. Code Review Checklist

Add to review checklist:
- [ ] Service uses `axiosInstance` not custom `axios.create()`
- [ ] No direct `localStorage.getItem()` for tokens
- [ ] Token access via `authStorage` only

### 3. Add Integration Tests

**Test cart auth:**
```typescript
// tests/cart-auth.spec.ts

test('cart requests include auth token', async ({ page }) => {
  await loginUser(page, 'test@example.com', 'password');

  // Intercept cart API call
  const [cartRequest] = await Promise.all([
    page.waitForRequest(req => req.url().includes('/api/cart')),
    page.goto('/cart')
  ]);

  // Verify Authorization header
  const authHeader = cartRequest.headers()['authorization'];
  expect(authHeader).toBeTruthy();
  expect(authHeader).toMatch(/^Bearer eyJ/);
});

test('cart handles token expiry gracefully', async ({ page }) => {
  // Mock expired token
  await page.evaluate(() => {
    const user = JSON.parse(localStorage.getItem('user'));
    user.token = 'expired.token.value';
    localStorage.setItem('user', JSON.stringify(user));
  });

  // Should attempt refresh and retry
  await page.goto('/cart');

  // Verify refresh happened
  const refreshRequests = await page.evaluate(() =>
    performance.getEntriesByName('/api/auth/refresh')
  );
  expect(refreshRequests.length).toBeGreaterThan(0);

  // Cart should load successfully
  await expect(page.locator('[data-testid="cart-items"]')).toBeVisible();
});
```

### 4. Centralize Auth Logic Documentation

**Create:** `docs/AUTH_INTEGRATION.md`

```markdown
# Authentication Integration Guide

## How to Make Authenticated API Calls

### ✅ CORRECT: Use axiosInstance

```typescript
import axiosInstance from "@/core/context/axiosInstance";

const response = await axiosInstance.get("/api/endpoint");
```

### ❌ WRONG: Custom axios instance

```typescript
import axios from "axios";
const api = axios.create({ baseURL: BASE_URL });
const response = await api.get("/api/endpoint");  // Won't have auth!
```

## Token Storage

Tokens are stored via `authStorage`:
- localStorage key: "user"
- Structure: `{ email, role, token, refreshToken }`

**Access tokens:**
```typescript
import { authStorage } from "@/core/utils/authStorage";
const token = authStorage.getToken();
```

**Never:**
```typescript
const token = localStorage.getItem("access_token");  // Doesn't exist!
```
```

---

## Related Incidents

**Same Session:**
- 2026-05-25 20:52: First deployment (localhost CORS error)
- 2026-05-25 21:10: Emergency fix (localhost → production URLs)
- 2026-05-25 21:30: Cart auth fix (this incident)

**Similar Issues:**
- Multiple axios instances with different auth strategies
- Inconsistent token storage/retrieval

---

## Lessons Learned

### 1. Don't Reinvent the Wheel

**Problem:** CartService created its own axios instance when a perfectly good one existed.

**Solution:** Always check for existing infrastructure before creating new.

### 2. Token Storage Must Be Centralized

**Problem:** Two different ways to access tokens:
- `authStorage.getToken()` ✓
- `localStorage.getItem("access_token")` ✗

**Solution:** Use `authStorage` everywhere. No direct localStorage access for auth.

### 3. Integration Tests Catch Auth Issues

**Problem:** Unit tests wouldn't catch this - CartService methods work fine in isolation.

**Solution:** Integration tests that actually login and call APIs would catch immediately.

### 4. API Clients Should Be Centralized

**Problem:** Each service creating own axios instance = inconsistent behavior.

**Solution:** One axios instance for the app, configured once, used everywhere.

---

## Files Changed

**Modified:**
```
apps/customer-store/src/features/cart/services/cartServices.tsx
  - Removed custom axios instance
  - Added import of main axiosInstance
  - Replaced all cartApi → axiosInstance
  - Removed token interceptor (now handled by main instance)
```

**Deployed:**
```
VPS: /usr/share/nginx/html/index.html      (Timestamp: May 25 21:30)
VPS: /usr/share/nginx/html/assets/index-bWVF_SVz.js  (New bundle)
```

---

## Sign-off

**Issue Resolution:** Complete
**Type:** Authentication Integration Bug
**Testing:** Manual verification, cart loads successfully
**Deployment:** May 25 21:30 UTC
**User Impact:** HIGH - All authenticated cart users affected

**Engineer:** Claude (assisted by User)
**Date:** 2026-05-25
**Time to Resolution:** ~15 minutes (identification + fix + deployment)
**Severity:** HIGH (P1)

**Root Cause Category:** Code Quality - Inconsistent API client usage

---

**Status:** ✅ RESOLVED

**Key Takeaway:** Always use centralized infrastructure (axios instance, auth storage) instead of creating service-specific implementations. Consistency prevents subtle integration bugs.
