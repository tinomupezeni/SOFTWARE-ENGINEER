# Production Bugs Investigation - 2026-07-01

## 1. Token Refresh Crash (500 Internal Server Error)

**Issue:** 
Users in production who returned to the app with expired JWT sessions were unable to refresh their tokens or get gracefully redirected to the login page. Instead, the backend was crashing entirely when the refresh request was made.

**Why it occurred:**
In `backend/instauth/views/auth_views.py`, the `CustomTokenRefreshView` was attempting to catch `TokenError` and `InvalidToken` exceptions to handle expired tokens safely and clear cookies. However, the required exception classes were not imported from `rest_framework_simplejwt.exceptions`. This caused Python to raise a `NameError: name 'TokenError' is not defined`, resulting in an unhandled 500 server crash rather than returning a 401 Unauthorized response to the frontend.

**Resolution:**
Added the missing import statement to the top of `backend/instauth/views/auth_views.py`:
```python
from rest_framework_simplejwt.exceptions import TokenError, InvalidToken
```

## 2. Program Creation Failure (400 Bad Request)

**Issue:**
Users from different institutions were occasionally receiving a `400 Bad Request` validation error when trying to create new academic programs, specifically when leaving the "Department" field as "None".

**Why it occurred:**
The `Program` model in `backend/faculties/models.py` defines a uniqueness constraint at the database level:
```python
unique_together = ('department', 'code')
```
Because the system is multi-tenant, multiple institutions share the same database table for programs. If Institution A created a program with the code "BSCS" and no department (`department=null`), and subsequently Institution B attempted to create a program with the code "BSCS" and no department, Django's `UniqueTogetherValidator` would block Institution B. The system effectively treated the combination of `(null, "BSCS")` as globally restricted, meaning no two institutions could create programs with the same code unless they assigned them to specific departments.

**Required Resolution:**
Update the database constraint to scope the uniqueness by institution. The model's `unique_together` constraint must be modified to include the `institution` foreign key:
```python
unique_together = ('institution', 'department', 'code')
```
This change will require generating and applying a new database migration (`makemigrations` and `migrate`).
