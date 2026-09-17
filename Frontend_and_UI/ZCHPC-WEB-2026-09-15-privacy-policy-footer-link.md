# Privacy Policy Footer Link Downloads PDF Instead of Navigating to Page

**Date:** 2026-09-15
**Project:** ZCHPC-WEB
**Environment:** Development
**Severity:** Low
**Status:** Resolved

## Summary
The "Privacy Policy" link in the footer navigated the user to a generic privacy policy web page instead of downloading the intended "Privacy Policy Review.pdf" document. This caused inconsistent behavior compared to the "About Us" page, where the policy document was available for direct download.

## Symptoms
- Clicking "Privacy Policy" in the footer navigated to the `/privacypolicy` route, showing a webpage.
- The requested behavior was to download the PDF document directly.

## Environment Details
- **Server/Host:** Local
- **Services Affected:** Web Frontend (Footer)
- **Related Components:** `resources/views/includes/footer.blade.php`
- **Time First Observed:** 2026-09-15

## Investigation Steps

### 1. Initial Diagnosis
Searched the codebase for the footer template and located `resources/views/includes/footer.blade.php`.
Identified the "Privacy Policy" link: `<a href="{{ route('privacypolicy') }}">Privacy Policy</a>`.

### 2. Root Cause Analysis
Checked how documents were downloaded on the `aboutus.blade.php` page, noting the usage of the `<x-document-link>` component which utilized the `documents.download` route. 

### 3. Key Findings
- The `documents.download` route in `routes/web.php` maps to `PDFController@downloadDoc`.
- Modifying the footer link to use this route with the correct filename allows the document to be downloaded directly.

## Root Cause
The footer was hardcoded to use a named route `privacypolicy` instead of the document download route for the PDF file.

## Prevention / Rule
**Guardrail:** Maintain consistency in document links across the application. When a specific policy document is meant to be downloaded (as established on other pages), use the unified `documents.download` route.

## Solution

### Immediate Fix
Updated the `href` attribute for the "Privacy Policy" link in `resources/views/includes/footer.blade.php` to use the `documents.download` route.

```blade
- <li class="list-item"><a href="{{ route('privacypolicy') }}" class="footer-link px-3 border-end border-white-2 op-8">Privacy Policy</a></li>
+ <li class="list-item"><a href="{{ route('documents.download', 'Privacy Policy Review.pdf') }}" class="footer-link px-3 border-end border-white-2 op-8">Privacy Policy</a></li>
```

### Long-term Fix
Ensure that all legal and policy documents consistently use the document management routes instead of standalone views unless explicitly required.

## Prevention
- [ ] Code changes required

## Related Issues
- N/A

## References
- N/A

---

**Resolved By:** Antigravity
**Time to Resolution:** 5 minutes
