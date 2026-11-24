# System Architecture — TESC / ScalarEye

## Overview

TESC is structured as a single Django 5 REST Framework backend API backed by PostgreSQL 15 and Redis/Celery, serving two independent React Single Page Applications (SPAs):

```
                         ┌─────────────────────┐
                         │   PostgreSQL 15      │
                         │  (single database,   │
                         │  institution-scoped  │
                         │  via FK, not schema)  │
                         └──────────┬───────────┘
                                    │
                         ┌──────────┴───────────┐
                         │   Django REST API      │
                         │   (backend/, DRF)      │
                         │   + Celery worker      │
                         │   + Redis (broker/cache)│
                         └──────┬────────┬────────┘
                                │        │
                 ┌──────────────┘        └──────────────┐
                 │                                       │
     ┌───────────┴───────────┐             ┌─────────────┴────────────┐
     │  inst/ (Vite + React)   │             │  frontend/ (Vite + React) │
     │  Institution admin UI   │             │  Superadmin / national UI │
     │  scoped to one          │             │  cross-institution        │
     │  institution_id          │             │  analytics + management   │
     └──────────────────────────┘             └──────────────────────────┘
```

## Backend Services (`backend/`)

- **`academic`**: `Student`, `Institution`, `Facility`, `Graduate`, fee models, and secondary domain tables (`IndustryPlacement`, `StudentScholarship`, `InternationalMobility`, `InCountryTransfer`, `StudentInclusivity`, `StudentWorkForFees`, `StudentISEOP`, `StudentEnrollment`, `Equipment`).
- **`faculties`**: `Faculty`, `Department`, `Program`, `AcademicYear`, `AcademicTerm`, `AcademicLevel`, `Module`.
- **`staff`**: `Staff`, `Designation`, `Vacancy`, `StaffDepartment`.
- **`users`**: `CustomUser` (auth), `Person` (shared identity across roles), `Role`, `Permission`, `AuditTrail`.
- **`instauth`**: Institution-admin authentication and OTP flow (`InstitutionAdmin` link table).
- **`iseop`**: Dedicated program tracking for ISEOP initiatives.
- **`innovation`**: Research hubs, projects, intellectual property, grants.
- **`reports`**: Dynamic report generation and Report Studio (`GeneratedReport`).
- **`analysis`**: Statistical and aggregate analysis endpoints (no models of its own).
- **`core`**: Base project settings, Celery tasks, crypto utilities (`Fernet`), and isolation mixins.

## Frontends

- **`inst/` (Institution Admin UI)**:
  - Vite + React + TypeScript + Tailwind CSS + shadcn/ui.
  - Used by institutional staff to manage students, staff, programs, and graduation for their specific institution.
  - Communicates via `/api/instauth/login/` and institution-scoped `/api/...` endpoints.
- **`frontend/` (Superadmin / National UI)**:
  - Vite + React + TypeScript + Tailwind CSS + shadcn/ui.
  - Used by national administrators for cross-institution analytics, dashboards, and system-wide reporting.
  - Communicates via `/api/users/token/` (SimpleJWT).
  - Note: These are separate codebases, not a shared-package monorepo.

## Environments & Infrastructure

- **Staging (`10.50.1.37`)**: Dev and test environment. Directly exposes backend (`8000`), main frontend (`8081`), and inst frontend (`8082`). No local reverse proxy.
- **Production (`10.50.200.35`)**: Live system. Nginx container terminates SSL and routes `tesc.zchpc.ac.zw` to `frontend`, `tesc-inst.zchpc.ac.zw` to `inst`, and `/api/` to `backend`.
- **Image Deployment**: Built on staging, transferred via SFTP as tarballs, loaded into Docker daemon on production (`tinotenda762/tesc-*`).
