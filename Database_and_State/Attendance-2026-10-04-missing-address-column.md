# Issue Log

**Date:** 2026-10-04
**Project:** Attendance
**Area:** Database_and_State

## Description
The FastAPI backend threw a 500 Internal Server Error when querying `/admin/employees` due to a `sqlalchemy.exc.ProgrammingError` indicating `column employees.address does not exist`.

## Root Cause
The `001_initial_schema.sql` file was updated to include the `address` column on the `employees` table, and the ORM models were updated. However, the database container was not properly rebuilt or migrated, leaving the running Postgres instance out of sync with the models and schema file.

## Resolution
Manually applied the missing migration via raw SQL to the live database using `ALTER TABLE employees ADD COLUMN address VARCHAR(255) DEFAULT 'Unknown Location';`. The schema file `001_initial_schema.sql` was verified to already contain the correct definition for future teardowns/rebuilds.

## Resolved By
Antigravity
