# TESC Codebase Clutter Audit (Guide 25: Continuous Codebase Simplification)

**Date:** 2026-10-26
**Project:** TESC
**Type:** Audit
**Status:** §1 and §2 removed, §3 operational-script defaults fixed, all per explicit user authorization; §3's doc rewrite and §4 (student data provenance) remain deferred

## Summary
Audited the TESC repository against `25. Continuous Codebase Simplification.md`'s clutter taxonomy and evidence model. Found ~45 one-off root-level scripts with zero cross-references anywhere in the repo (one of them, `create_admin.py`, is provably broken — imports a model class that no longer exists), plus several higher-severity findings the initial scan didn't anticipate: 78MB of a third-party binary committed to git, a 25MB accidental debug-HTML dump, two committed SQLite database snapshots, and a stale compose file that operational scripts still default to (which already caused a real failure earlier this session). Nothing was deleted — this report is the candidate list with evidence, per the guide's "identify a candidate without modifying the working tree" step.

## Context / Trigger
User added `25. Continuous Codebase Simplification.md` to the engineering guide library (mapped into `MANIFEST.md` earlier today, flagging TESC as a likely-high-fit project based on a root-directory glance). User then asked to actually run the audit.

## Scope
**In scope:** the TESC git repository's tracked files, scanned for the guide's clutter categories (dead/unreachable code, redundant code, dependency clutter, database clutter, documentation/architectural clutter) using static reference search, git history age, and content inspection where warranted.

**Out of scope:** `backend/`/`frontend/`/`inst/` application source code's own internal dead-code (unused functions/imports within the Django/React apps) — this pass focused on repo-root-level and whole-file clutter, which is both higher-confidence to assess (file-level reference search is far more reliable than intra-function reachability analysis) and was the category the initial manifest note flagged. A follow-up pass could apply Vulture/Ruff/Knip-style intra-file analysis per the guide's tool-landscape section.

## Method
For every candidate: `git grep` for the exact filename across the whole repo (catches CI workflows, docs, shell scripts, other Python/JS source) to establish static non-reference; `git log -1 --date=short` for last-touched date as a staleness signal; content inspection for any file where static non-reference alone felt like insufficient evidence (per the guide's explicit caution that absence of reference is not proof of deadness — it's supporting evidence that needs to be weighed, not sufficient on its own, especially for anything that could be invoked directly rather than imported). `du -h` across all git-tracked files to surface disproportionately large committed artifacts, which the initial glance at `ls -la` didn't reveal at all (file size and import-graph dead-ness are orthogonal, but TESC's worst finding turned out to be a size problem, not a reachability problem).

## Decisions & Findings

### 1. Low-risk, high-value: committed artifacts that should never have been in git (78MB+ of outright waste)
| File(s) | Size | Finding |
|---|---|---|
| `k6-v0.49.0-linux-amd64/k6` + `k6-v0.49.0-linux-amd64.tar.gz` | 53MB + 25MB = **78MB** | A third-party load-testing tool's compiled binary, committed **both** as a tarball and already-extracted. `scripts/run_load_test.sh` should download this at run time (standard practice for any binary dependency); nothing should ever commit a compiled ELF executable to a Python/JS application repo. Zero functional reference anywhere in source — only ever invoked as an external CLI tool, if at all. |
| `backend/error_output.html` | 25MB | ASCII text, no line terminators — the exact shape of an accidentally-saved Django `DEBUG=True` crash page. Zero reference anywhere. Classic "someone redirected a crash dump to a file while debugging and forgot to `.gitignore` it." |
| `backend/tesc_db`, `backend/tesc_db.bak` | 856KB + 532KB | **Both are real SQLite 3.x database files**, not scripts or fixtures — confirmed via `file`. The app's actual `settings.py` reads `DB_HOST`/`DB_NAME` from the environment (Postgres in every real environment this session touched); these look like a leftover local `USE_SQLITE=True` dev database (plus a stray backup copy) that got committed by accident. Database clutter per the guide's own named category - "apparently unused... Example: column with no application references" generalizes directly to a whole committed DB file. |

**Risk:** Low. None of these are imported, referenced by any script, or load-bearing for the application to run. Removing them cannot change runtime behavior. The only caution: git history retains them regardless of a future deletion (a `git filter-repo`/BFG pass would be a separate, much higher-risk action to actually shrink repo size — not recommended here without a dedicated decision, since it rewrites history).

### 2. Medium-risk: ~45 one-off root-level scripts, zero cross-references each
Every file below returned **zero** hits for both exact-filename `git grep` and Python-import-style `git grep` (`import X` / `from X import`) across the entire repository, including `.github/workflows/`, `docker-compose*.yml`, `scripts/`, `project_docs/`, and `docs/`:

```
clean_stem.py                configure_testadmin.py       create_admin.py
create_departments.py        create_query_hooks.py        decrypt_search.py
delete_test_placements.py    dynamic_verification.py      export_data.py
export_data_fast.py          export_student_data.py       fix_admin_pass.py
fix_all_dialogs.py           fix_frontend_build.py        fix_frontend_build2.py
fix_inst_build.py            fix_jsx.py                   fix_script.py
fix_user.py                  get_faculty_ids.py           list_faculties.py
patch.js                     patch_bulk.py                patch_error.py
patch_frontend.js            patch_requests.py            patch_semantic.py
quickfixes.patch             remove_custom_levels.py      rewrite_add_program.py
rewrite_dialogs.py           rewrite_edit_program.py      rewrite_frontend_facilities.py
rewrite_frontend_staff.py    rewrite_inst_facilities.py   rewrite_inst_staff.py
rewrite_student_dialogs.py   rewrite_upload_dialog.py     run_phase_tests.py
run_test.py                  update_frontend_services.py  update_innovation_keys.py
update_query_keys.py         update_script.py             update_services.py
update_types.py              verify_bundle.mjs
```

Last-touched dates cluster heavily around 2026-06-16 to 2026-08-17 (one-off batch codemods from early development phases), with three outliers last touched 2026-10-07 (`export_data.py`, `export_data_fast.py`, `export_student_data.py`) and four at 2026-10-18 (`fix_jsx.py`, `patch_error.py`, `patch_frontend.js`, `patch_semantic.py`) — still well before this report.

**Supporting evidence for "dead":** these are exactly the shape of the guide's "Dead/unreachable code" and "Redundant code" rows — standalone scripts meant to be run once (`rewrite_*`, `update_*`, `fix_*`, `patch_*` naming is self-describing: a one-time codemod or hotfix, not a reusable tool), with no caller anywhere in the application, CI, or deploy tooling.

**Contradictory/caution evidence per the guide's own asymmetry principle (absence of reference ≠ proof of deadness):** a handful of these are plausibly still-useful ad-hoc operator tools rather than truly dead (e.g. `export_data.py`/`export_student_data.py` producing the `students_training_data.csv`/`.xlsx` files discussed in §3 could be a recurring manual export someone runs by hand, which would never show up in a reference search since it's invoked directly, not imported). This is exactly the asymmetric-evidence case the guide warns about — static non-reference is real supporting evidence, not proof.

**One confirmed-broken outlier, worth calling out specifically:** `create_admin.py` does `from users.models import User` — **`User` does not exist** in `backend/users/models.py`; the real class is `CustomUser`. This script would crash with `ImportError` if run today. It also hardcodes a plaintext default admin password (`scalareye@123`) directly in the file — a lingering secret-hygiene issue independent of the dead-code question (worth being aware this password exists in git history regardless of whether the file itself is removed going forward).

**Likely redundant pair:** `export_data.py` and `export_data_fast.py` have near-identical opening code (same imports, same `Program`/`Student` setup) — looks like one superseded the other without the older one being removed, the guide's "Redundant code" category almost verbatim.

**Risk:** Medium, not low — unlike the §1 binaries, a few of these *could* still be manually invoked by someone even without being referenced in code. Recommend a quick human confirmation per filename family (or per-family, given there are ~8 natural groups) rather than a blanket delete, even though the static evidence is strong.

### 3. Needs a decision, not a deletion: `docker-compose.prod.yml` is stale but still the *default* in live tooling
`docker-compose.prod.yml` is **referenced by 15 other files** in the repo — `.github/workflows/deploy.yml`, `scripts/backup_database.sh`, `scripts/deploy.sh`, `scripts/reencrypt.sh`, `scripts/rotate-key.sh`, and 10 docs (`DEPLOYMENT.md`, `docs/PRODUCTION_ARCHITECTURE.md`, several `docs/production-readiness/*.md` files, etc.) — **despite being confirmed dead in actual production reality**: `tesc-prod`'s real checkout has it renamed to `docker-compose.prod.yml.retired`, and the root `docker-compose.yml` is what's actually running (confirmed this session via `docker ps` against the live VM).

This is not ordinary clutter - it's **actively misleading tooling**. `scripts/backup_database.sh` defaults `COMPOSE_FILE` to `docker-compose.prod.yml` when unset; this exact default was hit and had to be manually overridden (`COMPOSE_FILE=docker-compose.yml`) earlier this session when taking the pre-blue-green-migration backup, or the backup script would have failed against a compose file that doesn't correspond to any running containers. The same risk applies to `scripts/reencrypt.sh` and `scripts/rotate-key.sh`, which were not exercised this session but share the same default.

**Recommendation:** this isn't a "delete the stale file" case — the fix is updating every operational script's default (and ideally the docs) to reference `docker-compose.yml`, *then* deciding whether `docker-compose.prod.yml` itself should be deleted, archived, or kept as a documented historical reference. Flagging as its own follow-up rather than folding into the generic script cleanup above, since the risk profile (operational scripts silently doing the wrong thing) is categorically different from "nobody runs this file anymore."

### 4. Needs a content/privacy check before any decision
`students_training_data.csv` (6.0MB) and `students_training_data.xlsx` (1.8MB) are tracked in git. The CSV header (`Student_id, institution, institution_type, program, ..., gender, ...`) doesn't show obviously identifying fields like name or national ID in the first row, but the file is large enough (6MB) to plausibly contain real exported student records rather than a small synthetic sample. Given this is a Zimbabwe higher-education system handling real student records elsewhere in the codebase (encrypted `Student` model fields, per `backend/academic/models.py`'s own "ENCRYPTED STUDENT MODEL" section header), this file's provenance should be confirmed - real exported data vs. synthetic/anonymized training data - before deciding whether it belongs in version control at all, independent of whether it's "used" by anything.

## Changes Made
After this report's findings were presented, the user explicitly authorized proceeding ("proceed, lets start removing the junk"). Executed, in one commit (TESC `staging`/`main` `70a4f98`):
- Removed all §1 items: `k6-v0.49.0-linux-amd64/` + `.tar.gz` (78MB), `backend/error_output.html` (25MB), `backend/tesc_db` + `tesc_db.bak`.
- Removed all 44 §2 one-off scripts.
- Fixed the `docker-compose.prod.yml` default/hardcoded reference in `scripts/backup_database.sh`, `scripts/reencrypt.sh`, and `scripts/deploy.sh` (all now point at the real `docker-compose.yml`), and the echoed example commands in `scripts/rotate-key.sh`.
- Added `.gitignore` entries for all three §1 artifact categories to prevent recurrence.
- Synced the same commit onto `tesc-prod`'s checkout (fast-forward, ancestry-verified) since the fixed operational scripts live there.

Deliberately **not** done in this pass: `docker-compose.prod.yml` itself (still referenced descriptively by ~10 docs - a larger rewrite, not a quick fix) and `.github/workflows/deploy.yml`'s stale references (inside the already-disabled `if: false` deploy job) were left alone; `students_training_data.csv`/`.xlsx` was left untouched pending the provenance check below.

## Verification
- `git grep` re-run post-removal for every deleted filename across the whole repo (including `.github/`, `docker-compose*.yml`, `scripts/`, docs) - zero remaining references, confirming the original zero-reference finding held and nothing was silently depending on these files.
- Confirmed `scripts/run_load_test.sh` already has its own `wget`-based k6 download-on-demand fallback (lines 17-25) - the removed binary/tarball will be fetched fresh the next time that script actually needs it, not silently broken.
- Confirmed the `tesc_db`/`DB_NAME=tesc_db` string matches elsewhere in the repo (`settings.py`, `.env.example`, `backup_db.sh`) are the Postgres database *name*, unrelated to the removed SQLite file - the removed file was Django's own `BASE_DIR / 'tesc_db'` local-dev SQLite path (`USE_SQLITE=True` branch), regenerated on demand, never read from git.
- `bash -n` syntax-checked all four modified operational scripts.
- Live verification on `tesc-prod` post-cleanup: `curl -H "Host: tesc.zchpc.ac.zw"` → 200, all 8 blue/green containers still `Up`, confirming the cleanup (repo-root files + shell script text only, no application code touched) had zero effect on the running system, as expected.

## Changes Made (part 2, same day, user said "proceed n fix")
- Renamed `docker-compose.prod.yml` → `docker-compose.prod.yml.retired` (matching the file state already on `tesc-prod`), with a banner explaining why, pointing at the real `docker-compose.yml` and `project_docs/04`.
- Fixed the 5 "living guidance" docs giving literal, currently-wrong commands against it (`docs/deployment-guide.md`, `docs/PRODUCTION_ARCHITECTURE.md`, and 3 `docs/production-readiness/` runbooks) to reference `docker-compose.yml` instead. Left the historical/point-in-time docs alone (`DEPLOYMENT.md` already self-disclaims; `PHASE_9_5` runbook, `ARCHITECTURE_BASELINE`, `ENVIRONMENT_PARITY`, `FINAL_PRODUCTION_CERTIFICATION`, `project_docs/10-changelog` are records of a past state, not live instructions).
- Found and removed a second duplicate while re-verifying references: `tests/DEPLOYMENT.md` was an exact stale copy of the root `DEPLOYMENT.md` from *before* that file's "actual current process" correction banner was added - a second instance of the guide's "Documentation clutter" category, caught only because the verification step re-ran the reference search after the first round of fixes.
- Syncing onto `tesc-prod` surfaced one more piece of drift: the VM already had its own *untracked*, locally-renamed `docker-compose.prod.yml.retired` - an older version than git's (missing the 8081/8082 port mappings, and still carrying the exact `DEBUG=True` hardcoding that `ENVIRONMENT_PARITY.md` documents as a historical, already-mitigated issue). Since the file is confirmed dead either way, replaced it with the tracked version rather than attempt to reconcile two dead copies.

## Changes Made (part 3): student-data provenance check
Read-only check on `students_training_data.csv` (user asked to "proceed n fix," read as covering this deferred item too): single commit in history (2026-10-07), bundled into an unrelated "Optimize database queries" commit rather than added deliberately on its own - itself a small provenance red flag (nobody appears to have consciously decided to commit this file; it rode in with something else). 40,134 rows. Header and sample rows contain only structural/categorical fields (institution, program, gender, status, enrollment year, capacity, etc.) - no name, national ID, email, or phone columns. The `Student_id` values (e.g. `315/2026`) don't match the format of real student IDs seen elsewhere in this system during this session (e.g. `MM3260149`), reading instead like a sequential/synthetic identifier. Combined with the filename itself (`*_training_data`, ML-dataset naming convention), this is **moderate-to-high confidence synthetic or aggregate data, not a raw export of real student PII** - but this is an inference from structure, not a confirmed fact from whoever actually generated the file, so the finding is reported at that confidence level rather than treated as settled. Left untouched pending the user's own confirmation, since they're positioned to know the file's actual origin with certainty.

## Follow-ups / Deferred
1. **`students_training_data.csv`/`.xlsx`**: provenance check complete (moderate-to-high confidence it's synthetic, see above); final call on removal deferred to the user, who can confirm origin with certainty this audit cannot.
2. A deeper, intra-file dead-code pass (unused functions/imports within `backend/`/`frontend/`/`inst/` source, per the guide's Vulture/Ruff/Knip-style tooling) remains out of scope for this pass.
3. Git history still retains everything removed here, including the `create_admin.py` plaintext password - a history rewrite (`git filter-repo`/BFG) is a separate, higher-risk decision not recommended as part of routine cleanup, but worth being aware of if that password was ever reused anywhere real.
4. The broader `docs/production-readiness/` tree's relationship to `project_docs/` (the established "this is the real, current process" documentation set per `DEPLOYMENT.md`'s own redirect) was not fully audited - several of the "living guidance" docs fixed in part 2 may themselves describe the same aspirational GHCR/self-hosted-runner pipeline as the now-retired compose file (e.g. `docs/PRODUCTION_ARCHITECTURE.md`'s "Deploy Production" step describes the same unused `deploy_pipeline.sh`-style flow the user separately confirmed is stale), which would make the filename fix correct-but-incomplete for those docs. Worth a dedicated pass if `docs/` is meant to stay authoritative rather than `project_docs/` fully superseding it.

## References
- `Principal_Engineer/engineering-guides/25. Continuous Codebase Simplification.md` - the guide this audit follows.
- `reports/TESC-2026-10-26-blue-green-production-deployment-guide.md` - the session's own earlier discovery of `docker-compose.prod.yml`'s real-vs-documented status on `tesc-prod`, which this audit's §3 finding extends (same root issue, viewed from the git-hygiene angle rather than the deployment-mechanics angle).

---

**Completed By:** Claude Sonnet 5 (session with tinomupezeni)
