# Initiative Report: School Onboarding Bulk Student Account Creation & Password Policy

- **Date:** 2026-11-20
- **Project:** HBEC / HBCA
- **Author:** Tinotenda Mupezeni & Agentic Engineering
- **Status:** Complete

---

## 1. Context & Trigger
School administrators onboarding entire classes via the School Dashboard (`/import`) previously had 10-character random passwords generated for students (`secrets.token_urlsafe(10)`). These generated passwords were not exportable or downloadable, leaving administrators unable to hand out credentials and resulting in students being locked out. Furthermore, distributing hundreds of random strings creates unnecessary administrative overhead for schools.

ProjectFlow Task: `53c2e07f-c93a-4e48-9f9b-afde7ed11f4e` (*"Improve School Onboarding for Bulk Student Account Creation"*).

---

## 2. Scope & Design Decisions
1. **Surname-based Default Passwords:**
   - In bulk imports, the default password is deterministic and derived from the student's normalized surname: `surname.lower().replace(/[^a-z0-9]/, "")`.
   - If shorter than 6 characters (e.g. `Ng`), padded with `2026` (`ng2026`).
2. **Forced First-Login Password Change:**
   - On bulk import, `requires_password_change` flag is set on the School's `Student` model and synchronized as `must_change_password: True` to the Student Backend's `StudentProfile`.
   - When a student signs in with their temporary credentials, the login flow intercepts the session and routes them to `/change-password`.
   - Once a new password is set via `ChangePasswordView`, `must_change_password` is cleared to `False`.
3. **School Dashboard UX Improvements:**
   - Downloadable CSV Roster Template directly on the drop screen (`HBCA_Student_Import_Template.csv`).
   - "Download Credentials (.csv)" button upon import completion exporting `{ Student ID, Name, Grade, Default Password, Synced }`.
   - Visual credentials preview and warning callout on the completion step.
   - Explicit row-by-row error reporting if validation issues or sync failures occur.

---

## 3. Changes Made
- `SCHOOLS/schools_backend/institutions/models.py`: Added `requires_password_change` boolean field to `Student`.
- `SCHOOLS/schools_backend/institutions/migrations/0010_student_requires_password_change.py`: Created migration.
- `SCHOOLS/schools_backend/institutions/services/import_service.py`: Added `generate_default_password()`, populated `requires_password_change`, passed `must_change_password: True` in sync payload.
- `SCHOOLS/schools_backend/institutions/tests.py`: Updated import tests to verify surname password generation and flag persistence.
- `STUDENT/hbec_backend/apps/accounts/models.py`: Added `must_change_password` boolean field to `StudentProfile`.
- `STUDENT/hbec_backend/apps/accounts/migrations/0036_studentprofile_must_change_password.py`: Created migration.
- `STUDENT/hbec_backend/apps/internal/views.py`: Processed `must_change_password` in `SyncStudentView`.
- `STUDENT/hbec_backend/apps/accounts/views.py`: Enforced `/change-password` redirection on `StudentLoginView` and cleared flag on `ChangePasswordView`.
- `SCHOOLS/school_dashboard/src/routes/import.tsx`: Added template download, CSV credentials export, inline error rendering, and credential preview cards.

---

## 4. Verification
- `SCHOOLS/schools_backend`: 32/32 tests passed (`manage.py test institutions`).
- `STUDENT/Frontend`: `npm run typecheck` passed (0 errors).
- Origin commits: `9ceb8d217` merged with `experimental` into `be5c93266` and pushed to GitHub.
- Deployed to `green` staging environment on `hbca-vps`.
