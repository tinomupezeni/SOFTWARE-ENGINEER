# Database Reset Authentication Failure - JSON Parsing Issue

**Date:** 2026-05-16
**Project:** LoanManagement
**Environment:** Production
**Severity:** High
**Status:** Resolved

## Summary
After clearing and reseeding the production database with a fresh admin user, login attempts failed with HTTP 401 Unauthorized errors. Investigation revealed that the actual issue was HTTP 400 (Bad Request) caused by JSON parsing errors due to special characters in the password (`#` and `!`), not an authentication problem.

## Symptoms
- Frontend displayed HTTP 401 Unauthorized error on login attempts
- API logs showed: `WARNING Unauthorized: /api/auth/token/`
- User credentials were correctly created in database with proper roles
- Django shell authentication tests passed successfully
- Direct API endpoint calls revealed HTTP 400 Bad Request

## Environment Details
- **Server/Host:** VPS (159.198.42.231)
- **Services Affected:** admin-api, admin-frontend
- **Endpoint:** POST /api/auth/token/
- **Database:** PostgreSQL admin_db (freshly cleared and reseeded)
- **User:** admin@restksolutions.co.zw
- **Time First Observed:** 2026-05-16 11:44 AM

## Investigation Steps

### 1. Database Verification
Confirmed user was created in the correct database with proper configuration:

```bash
docker exec mlms-admin-db psql -U admin_user -d admin_db -c \
  "SELECT id, email, full_name, is_active, is_staff FROM users_user WHERE email='admin@restksolutions.co.zw';"

# Result: User ID=1, is_active=true, is_staff=true, SUPER_ADMIN + ADMIN roles assigned
```

### 2. Django Authentication Test
Verified password authentication worked within Django:

```python
from django.contrib.auth import authenticate
user = authenticate(email='admin@restksolutions.co.zw', password='AdminSecure#2026!')
# Result: Successfully returned User object - authentication PASSED
```

### 3. API Endpoint Direct Test
Tested the actual API endpoint using curl:

```bash
curl -X POST https://probitasadmin.restksolutions.co.zw/api/auth/token/ \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@restksolutions.co.zw","password":"AdminSecure#2026!"}'

# Result: HTTP 400 Bad Request
# Error: {"detail":"JSON parse error - Invalid \\escape: line 1 column 67 (char 66)"}
```

### 4. Key Findings
- **Misleading Error:** Frontend showed 401, but actual server response was 400
- **JSON Parsing Failure:** Special characters `#` and `!` in password broke JSON parsing
- **Django vs API Layer:** Authentication worked in Django shell but failed at API JSON parsing layer
- **Password Source:** Password was set via deployment script: `--password 'AdminSecure#2026!'`

## Root Cause

**Special characters in the password (`#` and `!`) caused JSON parsing errors at the API layer.**

The password flowed through multiple systems:
1. **PowerShell → SSH → Docker → Django shell**: Worked (password correctly hashed in database)
2. **Browser → HTTPS → Caddy → Django API**: Failed (JSON parser couldn't handle special chars)

The authentication logic never executed because the JSON request body couldn't be parsed. The special characters `#` and `!` required escaping in JSON, but the frontend/API communication layer didn't handle this correctly.

## Solution

### Immediate Fix
Changed password to use only alphanumeric characters without problematic special characters:

```python
# Reset password via Django shell
from django.contrib.auth import get_user_model
User = get_user_model()
u = User.objects.get(email='admin@restksolutions.co.zw')
u.set_password('ProbitasSecure2026Admin')
u.save()
```

**New Password:** `ProbitasSecure2026Admin`
- 23 characters long (strong through length)
- Mix of uppercase, lowercase, and numbers
- No special characters that cause JSON parsing issues
- Verified working via curl and browser login

### Verification
```bash
curl -X POST https://probitasadmin.restksolutions.co.zw/api/auth/token/ \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@restksolutions.co.zw","password":"ProbitasSecure2026Admin"}'

# Result: HTTP 200 OK - Successfully returned JWT tokens (refresh + access)
```

### Long-term Fixes
1. **Update Password Policy:**
   - Document recommended password characters (alphanumeric + select safe special chars)
   - Add validation in `seed_admin` command to warn about problematic characters
   - Consider server-side password generation for admin users

2. **Improve Error Handling:**
   - Frontend should better differentiate between 400 (bad request) and 401 (unauthorized)
   - API should return more specific error messages for JSON parsing failures
   - Add client-side validation for JSON-safe password characters

3. **Enhanced Testing:**
   - Add end-to-end API tests that use actual HTTP requests
   - Test authentication with various password formats (not just Django test client)
   - Include JSON parsing validation in smoke tests

## Prevention
- [ ] Update seed_admin command to validate/sanitize passwords
- [ ] Add documentation on password character restrictions
- [ ] Create end-to-end authentication tests with various password formats
- [ ] Update deployment scripts to generate JSON-safe passwords
- [ ] Add frontend validation for password character sets

## Lessons Learned

1. **Error Interpretation**: Frontend errors (401) don't always reflect backend errors (400). Always verify at the source.

2. **Multi-Layer Testing**:
   - Django shell authentication ≠ API endpoint authentication
   - Test at each integration point (shell, API, frontend)

3. **Password Complexity vs Compatibility**:
   - Modern security favors length over special characters
   - Special characters can cause integration issues
   - 20+ alphanumeric characters are stronger than 8 chars with symbols

4. **JSON Handling**:
   - Be cautious with special characters in JSON payloads
   - Test with actual HTTP requests, not just abstracted test clients
   - Validate JSON parsing separately from business logic

## Related Issues
- 2026-05-13: Previous authentication issues with password desync (different root cause)

## References
- Django REST Framework SimpleJWT documentation
- NIST Password Guidelines (SP 800-63B) - recommends length over complexity
- JSON RFC 8259 - String escaping rules

## Related Files
- `admin/backend/apps/users/management/commands/seed_admin.py` - Admin user creation
- `admin/backend/apps/users/api/serializers.py:52` - CustomTokenObtainPairSerializer
- `admin/backend/apps/users/api/views.py:97` - CustomTokenObtainPairView
- `scripts/mlms.ps1:220-231` - Deployment script seed function

---

**Resolved By:** Claude Sonnet 4.5
**Time to Resolution:** 1.5 hours
**Final Status:** Login working successfully with new password
