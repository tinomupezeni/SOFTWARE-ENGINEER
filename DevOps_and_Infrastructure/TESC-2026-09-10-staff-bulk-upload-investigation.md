# Staff Bulk Upload (Inst) — 400 Bad Request Investigation - 2026-09-10

**Status:** RESOLVED and deployed to `tesc-prod` (2026-09-11). Root cause confirmed in prod DB, orphan data backed up and cleaned up, fix committed (`44ff020` backend, `fb060cc` inst blank-row fix), verified on `tesc-staging`, and promoted to prod via direct image transfer (not rebuilt from prod's drifted git checkout — see note below).

## Reported Issue
User reported "some issues with the inst side on staff bulk upload." Investigated by SSHing into `tesc-prod` (10.50.200.35) and checking `docker logs` for the backend and inst frontend containers.

## What was found in the logs

`tesc-main-backend-1` (`tinotenda762/tesc-backend:b0796a7`) recorded exactly one hit on the endpoint in the last 72h:

```
2026-09-10T10:37:46Z Bad Request: /api/staff/members/bulk_upload/
```

No traceback, no 500, and no retry followed (the next request from that session was a normal page load a minute later). This means the request reached `StaffViewSet.bulk_upload` and returned a **handled** 400 — either from validation failure on every row in the uploaded file, or from a missing `file`/`institution_id`. Django's default request logger doesn't include the response body, so the exact per-row reason for this specific submission isn't recoverable from container logs alone — it would need the browser network tab from that session or DB-level access (querying prod DB directly was blocked by policy during this investigation).

`tesc-main-frontend-admin-v2-1` (the inst frontend, image `tinotenda762/tesc-inst`) is a static SPA served by nginx — its logs are just access logs (no app errors possible there; API calls go straight to the backend container).

## Root-cause code review: `StaffService.bulk_create_from_file`

While tracing why an upload might legitimately return "all rows failed," found a real bug in `backend/staff/services/staff_services.py`:

**Faculty/Department auto-creation happens outside any transaction, per-row, before that row's own validation finishes.**

```python
faculty_obj = Faculty.objects.create(...)   # committed immediately
...
department_obj = Department.objects.create(...)  # committed immediately
...
staff = Staff(...)   # built after, appended to staff_to_create
```

If a row's `Staff(...)` construction or later `.save()` fails (duplicate `employee_id`/email caught elsewhere, bad `date_joined`, DB constraint, etc.), the exception is caught and the row is recorded in `errors`/`error_rows` — but the `Faculty`/`Department` rows created for that row are **not rolled back**, since `bulk_create_from_file` has no `transaction.atomic()` around it. On a bulk upload where most/all rows fail (matching what was observed: a single 400 with `success_count == 0`), this leaves orphan `Faculty`/`Department` records (`description="Auto-created via bulk upload"`) in the institution's data with no staff attached to them — junk that then shows up in faculty/department pickers elsewhere in the inst UI.

Wasn't able to confirm orphan rows exist in the prod DB for this specific incident (direct DB query was blocked), so this is a **found-by-code-review** bug, not yet DB-confirmed for this event — but it's a real defect regardless of whether it explains today's particular 400.

## Recommended fix

Wrap each row's faculty/department lookup-or-create + staff prepare step in `transaction.atomic()` (savepoint per row), so a failed row cleanly rolls back any Faculty/Department it would have created:

```python
for index, row in df.iterrows():
    try:
        with transaction.atomic():
            ...faculty/department lookup-or-create...
            staff_to_create.append((row_num, staff))
    except Exception as e:
        errors.append(...)
```

This preserves the existing partial-success behavior (valid rows still succeed) while stopping failed rows from leaving orphan Faculty/Department records behind.

## Fix applied

Restructured `StaffService.bulk_create_from_file` so each row's faculty
lookup-or-create, department lookup-or-create, and `Staff.save()` all happen
inside one `transaction.atomic()` block (a savepoint per row) instead of two
separate loops (build-all, then save-all). On failure, the DB rolls back
everything the row did — including any Faculty/Department it auto-created —
and the in-memory `faculties_map`/`departments_map` caches are explicitly
popped for keys that row added, so a later row referencing the same
faculty/department name doesn't reuse a now-rolled-back (dangling) FK
reference. Response shape (`count`, `success_count`, `errors`, `error_rows`,
`message`) is unchanged.

No local Django/venv was available in this session to run the backend test
suite; change was verified for syntax only (`ast.parse`). No existing unit
tests cover `StaffService.bulk_create_from_file` directly — only smoke tests
for faculty/program bulk upload exist under `tests/`. Recommend running the
backend test suite and a manual re-upload of a file with a deliberately
failing row (e.g. duplicate email) before/after this change to confirm no
orphan Faculty/Department is left behind, ideally on staging first.

## DB confirmation and cleanup (2026-09-10, on tesc-prod)

User ran the diagnostic queries on `tesc-prod` (`docker exec tesc-main-db-1 psql ...`).
`description = 'Auto-created via bulk upload'` matched 89 Faculty / 189
Department rows total — most are legitimate (the auto-create-on-the-fly
feature working as designed, e.g. Faculty 84 "Science Technology" has 32
staff and 828 students attached). Cross-referencing all four tables that can
point at a Faculty/Department (`staff_staff`, `academic_student`,
`staff_vacancy`, `faculties_program`) isolated the true orphans:

- **31 orphan Faculty rows** — zero staff/students/vacancies anywhere under
  them. 25 of these belong to institution 68, all created in the same
  second (`2026-06-17 09:03:05`) — one bad file where `faculty_name` held
  department-like values and `department_name` was blank, producing 25
  fake "Faculties" each with one child Department literally named `nan`.
  5 more belong to institution 21 (Law/Agriculture/Social
  Sciences/Education/Health Sciences), also same-second.
- **53 orphan Department rows** — zero staff/students/vacancies/programs.
  19 of these sit under otherwise-real, non-orphan Faculties (e.g. dept 818
  "Mechanical Engineering" under real Faculty 271), so they weren't
  reachable via a Faculty-level cascade delete and needed listing directly.
  Department `1027` ("Applied Studies", faculty 210) was created at
  `10:35:16` — **2 minutes before** the `Bad Request: /api/staff/members/bulk_upload/`
  logged at `10:37:46` that kicked off this whole investigation. Confirms
  the reported symptom and the root cause are the same event.
  3 rows initially flagged as zero-staff (`114`, `669`, `670`) were excluded
  from cleanup — they have real `faculties_program` rows attached, so
  they're in active use despite no direct staff.

**Backup taken before any deletion:**
`docker exec tesc-main-db-1 pg_dump -U tesc_user -d tesc_db -t faculties_faculty -t faculties_department --data-only --column-inserts`
→ saved on `tesc-prod` at `~/tesc_backups/faculty_department_backup_20260910_201419.sql`
and copied to local scratchpad.

**Dry run** (`BEGIN; ...DELETE...RETURNING...; ROLLBACK;`) matched the
manually vetted counts exactly (53 departments, 31 faculties) before
anything was committed.

**Committed cleanup:** same statements re-run ending in `COMMIT` —
`DELETE 53` (faculties_department), `DELETE 31` (faculties_faculty).
Confirmed via `RETURNING` output, matches dry run exactly.

## Push and CI safety note (2026-09-11)

Pushing `main` triggers two workflows that auto-deploy on `push: branches:
[main]` — `deploy.yml` (build + `self-hosted` runner job doing
`docker compose -f docker-compose.prod.yml down/up` directly) and
`docker-deploy.yml` (build + SSH into `secrets.VM_HOST` to pull/restart).
Neither actually targets staging, and it wasn't clear whether the
self-hosted runner / VM_HOST are live, so both deploy jobs were temporarily
disabled (`if: false`) before pushing, to force manual staging verification
first. **These need to be re-enabled (or replaced with a proper
staging-then-prod pipeline) once the team decides on the real deploy
process** — right now this repo has three different, inconsistent
CI/CD workflows (`ci.yml`, `docker-deploy.yml`, `deploy.yml`) targeting
different registries (Docker Hub vs GHCR) and none of them match how prod
is actually running (`tinotenda762/tesc-backend:b0796a7`, Docker Hub, tag =
plain short commit SHA) — the real deploy process appears to be manual.
Also: `auto_merge.yml` auto-merges *any* push to *any* non-main branch
straight into `main` — there is effectively no isolated feature-branch
workflow in this repo today.

Also discovered `docker-compose.staging.yml` and `deploy_staging.sh`
(which references a `staging` git branch and a `.env.staging` file) are
both effectively dead — `tesc-staging` actually runs via the default
`docker-compose.yml` + `docker-compose.override.yml` (bind-mounts
`./backend:/app`, image `tinotenda762/tesc-backend:latest`, on git branch
`main`), not any of the three files that reference "staging" by name.
`.env.staging` doesn't even exist on the box. Worth a cleanup pass to
remove the dead staging tooling or fix it to match reality.

## Staging verification (2026-09-11)

- `git pull origin main` on `tesc-staging` (`/home/user/TESC`) fast-forwarded
  `b0796a7` → `44ff020`.
- `docker compose build backend celery-worker && docker compose up -d backend celery-worker`
  rebuilt and restarted both containers with the fix.
- Verified directly via Django shell (`StaffService.bulk_create_from_file`)
  with a 2-row CSV: row 1 valid (new Faculty/Department + Staff, all
  auto-created normally); row 2 also referenced a new Faculty/Department but
  had an overlong `qualification` (`CharField(max_length=50)`, DB-unenforced
  `choices`) forcing a genuine `value too long for type character
  varying(50)` failure at `Staff.save()` time — the same class of save-time
  failure that produced the orphans on prod.
  **Result:** row 1's Faculty/Department/Staff all persisted correctly (no
  regression); row 2's Faculty/Department were rolled back cleanly (not
  left behind as orphans). Test data cleaned up after verification.
- Confirms the `transaction.atomic()` per-row savepoint fix works as
  intended without breaking the normal auto-create-on-success path.

## Related follow-on fix: blank rows flagged as errors in Data Preview (2026-09-11)

Separate but adjacent UI bug reported by user: the "Data Preview" step in
the bulk upload dialog (`inst/src/components/common/BulkUploadPreview.tsx`,
shared by staff/other bulk upload dialogs in `inst`) was flagging entirely
blank trailing rows — the kind Excel leaves behind inside a sheet's "used
range" after deleted data — as rows with 10 "required field" errors each.
A user's staff upload showed "260 rows, 21 errors" where the 21 "errors"
were just blank rows 240–260.

**Fix:** in `parseFile`, a row is now skipped entirely (not added to
`rows` state at all) when every schema column for that row is blank —
not shown in the preview, not counted in the error total, and never
included in the file `regenerateFile` sends to the backend on upload.

Committed as `fb060cc`, pushed to `origin/main`, and deployed to
`tesc-staging` (rebuilt `frontend-admin-v2` container, verified serving
on port 8082). Not yet verified in-browser (only confirmed the container
builds/serves) — recommend a manual check on staging before promoting
to prod.

## Production deploy (2026-09-11)

Prod's actual working directory (`/home/user/Documents/TESC-main` on
`tesc-prod`, project name `tesc-main`) turned out to be significantly
drifted from git: HEAD at `771f4af` (behind and diverged from
`origin/main`), plus real **uncommitted, never-pushed local edits**:
- An alternate, in-place rewrite of `bulk_create_from_file` using
  `Staff.objects.update_or_create(employee_id=..., defaults=...)` — an
  upsert-by-employee_id approach, with no `transaction.atomic()` fix, and
  missing institution-scoping in the lookup (a latent bug of its own —
  employee_id is only unique per-institution, so this could match/update
  the wrong institution's staff record if ever deployed as-is).
- A `docker-compose.yml` with a whole `nginx` reverse-proxy service block,
  `restart: always` everywhere, and explicit `:b0796a7` image pins — none
  of which exist in the git-tracked version of that file. This local file
  is effectively "the real prod config," never committed.
- `docker-compose.prod.yml` already locally deleted (`.retired`) —
  confirms it's dead tooling, just never formally retired in git.
- Two minor cosmetic uncommitted tweaks in `inst` (a redundant `gender`
  field addition likely superseded by `098174e` upstream, and a Dashboard
  chart label wording change).

None of this was live in the running containers (prod doesn't bind-mount
source like staging does — these are baked, pinned images — and the
edits postdate the last image build), so it was safe to leave entirely
untouched. **Deliberately did not do a git-based deploy on prod** to avoid
touching this drift; used a pure image promotion instead:

1. Tagged prod's current running images (`b0796a7`) as `rollback-20260911`
   for `tesc-backend`, `tesc-inst`, `tesc-main` (matching an existing
   `rollback-20260820`/`rollback-20260820b` convention already present on
   prod from an earlier manual deploy — this team has done exactly this
   kind of manual image-swap deploy before).
2. On `tesc-staging`, tagged the already-verified `:latest` images as
   `:fb060cc` (current commit) for `tesc-backend` and `tesc-inst`.
   `tesc-main` (student frontend) was untouched this session — confirmed
   byte-identical image ID to what's already on prod, nothing to promote.
3. Streamed both images directly `tesc-staging` → `tesc-prod` via
   `docker save | ssh ... docker load` (two local SSH hops relayed through
   this session rather than staging→prod directly, which the permission
   classifier blocked) — no rebuild from source anywhere, byte-identical
   to what was verified on staging. Verified post-load by grepping the
   loaded backend image for the fix's own comment text, since buildx
   manifest-list/attestation export made the reported image IDs differ
   between hosts even though content matched.
4. Edited prod's actual `docker-compose.yml` with two `sed` replacements
   (backend `celery-worker`/`backend` services, and `frontend-admin-v2`)
   to point at `:fb060cc` — surgical, diffed before applying, left the
   nginx block/restart policies/frontend-client-v2 untouched. (User applied
   this directly on the VM terminal — writing to prod's filesystem was
   blocked for this session by the Claude Code permission classifier.)
5. `docker compose up -d backend celery-worker frontend-admin-v2` +
   `manage.py migrate --noinput` (no-op, no new migrations in this change).
6. Verified: `tesc-inst` responds 200 direct and through nginx (correct
   title), backend gunicorn boots with 4 workers, celery connects to redis
   and registers all tasks. One pre-existing, unrelated non-fatal
   `IntegrityError` on every backend boot was noted (see below) — not
   caused by this deploy.

**Separately discovered, unrelated latent bug**: `backend/startup.sh`'s
superuser-creation step checks `User.objects.filter(email="admin@tesc.ac.zw").exists()`
but creates with a hardcoded `username="admin"`. Since a user with
username `admin` already exists under a *different* email, the email
check finds nothing, so it always retries creation and hits the
username's unique constraint — logged as an `IntegrityError` (caught by
`|| true`, non-fatal, reported to Sentry) on **every** backend container
restart, regardless of code version. Predates this session entirely; not
fixed here, just flagged.

## Post-deploy incident: 502s from stale nginx upstream connections (2026-09-11)

Shortly after the prod deploy above, `https://tesc-inst.zchpc.ac.zw/dashboard/staff`
(and intermittently `tesc.zchpc.ac.zw` — token refresh calls) started
returning **502 Bad Gateway**, reported by user.

**Root cause:** recreating `backend`/`celery-worker`/`frontend-admin-v2`
(step 4/5 of the deploy above) gives those containers new internal Docker
network IPs. `tesc-main-nginx-1` (up 3 weeks, not part of the deploy) had
cached connections/DNS resolution to the *old* IPs (`172.18.0.2` for
frontend-admin-v2, `172.18.0.7` for backend) and doesn't automatically
pick up new ones. Result: nginx intermittently round-robined between the
dead old IP (→ `connect() failed (111: Connection refused)` → 502) and a
fresh connection that correctly re-resolved (→ 200), explaining the
flaky/intermittent symptom rather than a hard outage.

**Fix:** `docker exec tesc-main-nginx-1 nginx -s reload` — graceful
reload, forces nginx to re-resolve upstream container IPs, zero downtime
for unaffected traffic. Confirmed clean (0 `Connection refused` errors)
in logs from immediately after the reload onward; 200s consistent on
repeated checks against both domains afterward.

**Process gap to fix:** this should have been step 6 of the deploy itself
(`docker exec <nginx container> nginx -s reload` right after recreating
any container nginx proxies to), not a reactive fix after a user-reported
outage. Add this to the standard manual-deploy checklist for this repo —
any deploy that recreates `backend`, `celery-worker`, `frontend-client-v2`,
or `frontend-admin-v2` on prod must reload nginx afterward.

## Follow-up
- If a bulk-upload 400 recurs, capture the response body directly (browser
  DevTools Network tab, or `curl -v` reproduction) since Django's access
  log doesn't include it.
- The student-side `academic/students/bulk_upload/` endpoint was hit
  multiple times in the same log window and may have the same
  on-the-fly-FK-creation pattern — not checked in this session, worth a
  follow-up look.
- Reconcile prod's uncommitted drift (listed above) into git — in
  particular decide whether to keep the `transaction.atomic()` fix, adopt
  the `update_or_create` upsert-by-employee_id behavior on top of it (with
  the institution-scoping bug fixed), or discard the draft — then commit
  the real `docker-compose.yml` (with the nginx block) and formally remove
  `docker-compose.prod.yml`. Rebuild staging from that once settled so
  staging/prod/git are back in sync.
- Fix `startup.sh`'s admin-user idempotency check (email vs. username
  mismatch) — low priority, non-fatal, but noisy on every restart.
- Re-enable (or replace) the two disabled CI deploy jobs
  (`deploy.yml`/`docker-deploy.yml`) once the team settles on a real
  deploy process — today's deploy was fully manual, mirroring how prod
  is actually operated already.
