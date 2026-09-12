# Production Cutover — Replaced Deployed Codebase With PearsonMunasheTorto/Market-Link Fork

**Date:** 2026-09-12
**Project:** Market-Link (agromarket)
**Environment:** Production (agromarketing-vm VPS, `10.50.101.17`)
**Severity:** Medium
**Status:** Resolved

## Summary
After confirming the deployed codebase and the `torto` fork (`PearsonMunasheTorto/Market-Link`) had diverged with neither being a strict superset (see `Architecture_and_Design/Market-Link-2026-09-12-unmerged-fork-divergence-origin-vs-torto.md`), the project owner decided to cut the live deployment over to the `torto` fork entirely. Performed a full backup first (DB, uploaded files, code, images), archived — rather than deleted — the prior deployment, then deployed the fork in its place with no data loss.

## Symptoms
N/A — this is a planned cutover, not an incident. Preceding context: owners reported the deployed app looked outdated (see related stale-image and fork-divergence entries).

## Environment Details
- **Server/Host:** agromarketing-vm (10.50.101.17)
- **Services Affected:** `marketlink_frontend`, `marketlink_backend`, `marketlink_db` (DB untouched, only code/images replaced)
- **Related Components:** `/home/user/Documents/agromarket` (live path), `/home/user/Documents/agromarket.archived-2026-09-12` (archived prior deployment), `/home/user/backups/agromarket-2026-09-12/`
- **Time First Observed:** 2026-09-12 (planned action, not a fault)

## Investigation Steps

### 1. Initial Diagnosis
N/A — proceeded directly to backup + cutover per owner decision.

### 2. Root Cause Analysis
Not applicable (deployment action). One unexpected finding during execution: a plain `git clone https://github.com/PearsonMunasheTorto/Market-Link.git` from the VPS failed:
```
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```
`curl` to the same URL's `info/refs` endpoint returned `Repository not found` unauthenticated, and `GIT_CURL_VERBOSE=1 git ls-remote` showed an explicit `401` with `WWW-Authenticate: Basic realm="GitHub"`. This repo is **not** anonymously cloneable from this VPS despite appearing public from another environment — worth remembering for any future automation that assumes a plain `git clone` will work.

### 3. Key Findings / Steps Taken
**Backup (before any destructive action):**
```bash
# MongoDB
docker exec marketlink_db mongodump --db digital-agro --archive=/tmp/digital-agro-backup.archive --gzip
docker cp marketlink_db:/tmp/digital-agro-backup.archive /home/user/backups/agromarket-2026-09-12/digital-agro-backup.archive.gz

# Untracked, user-uploaded product images (never in git)
tar -czf /home/user/backups/agromarket-2026-09-12/backend-uploads.tar.gz backend/uploads

# Git tag + full repo snapshot of the deployed code
git tag -a pre-torto-replace-2026-09-12 -m "Snapshot before replacing with PearsonMunasheTorto/Market-Link"
tar --exclude='**/node_modules' --exclude='backend/uploads' -czf /home/user/backups/agromarket-2026-09-12/agromarket-repo-snapshot.tar.gz -C /home/user/Documents agromarket

# Docker images
docker tag agromarket-frontend:latest agromarket-frontend:pre-torto-2026-09-12
docker tag agromarket-backend:latest agromarket-backend:pre-torto-2026-09-12

# Raw mongo_data volume (belt-and-suspenders on top of the mongodump)
docker run --rm -v market-link-main_mongo_data:/data -v /home/user/backups/agromarket-2026-09-12:/backup alpine \
  tar -czf /backup/mongo_data_volume.tar.gz -C /data .
```
Also copied the DB dump, uploads archive, and repo snapshot off the VPS to a local machine for an off-box copy.

**Cutover (archive, not delete):**
```bash
cd /home/user/Documents
mv agromarket agromarket.archived-2026-09-12

# Anonymous clone failed (see finding above), so reused the credentialed
# `torto` remote already fetched inside the archived repo instead:
cd agromarket.archived-2026-09-12
git branch deploy-torto torto/main
git clone --branch deploy-torto --single-branch /home/user/Documents/agromarket.archived-2026-09-12 /home/user/Documents/agromarket
cd /home/user/Documents/agromarket
git branch -m deploy-torto main
git remote remove origin
git remote add origin https://github.com/PearsonMunasheTorto/Market-Link.git   # no embedded credentials

# Carry over secrets and user-uploaded content (both untracked/gitignored)
cp ../agromarket.archived-2026-09-12/backend/.env backend/.env
cp ../agromarket.archived-2026-09-12/frontend/.env frontend/.env
cp -a ../agromarket.archived-2026-09-12/backend/uploads/. backend/uploads/

docker compose build --no-cache backend frontend
docker compose up -d
```

### 4. Verification
- Both containers `Up`, no restart loops.
- `curl http://localhost:3001` → 200, `curl http://localhost:5001/api/products` → 200.
- Backend logs: MongoDB connected, NLP classifier initialized, market data seeded — no errors.
- Confirmed no data loss directly against MongoDB (`mongosh --eval 'db.<collection>.countDocuments()'`): 15 products, 46 users, 71 market prices, 4 chat histories — matching the pre-cutover backup exactly. (One product-listing API response showed `count: 4`, which is this fork's own listing-endpoint filter/pagination logic, not a data issue.)

## Root Cause
N/A (planned cutover). Env var names between the two forks' `.env.example` files matched exactly, and `docker-compose.yml` was byte-identical (same container names, same external `mongo_data` volume) — this made the swap low-risk once the decision was made.

## Solution

### Immediate Fix
See commands above. Live app now serves `PearsonMunasheTorto/Market-Link` (`efbb551`) at the same URLs, same database.

### Long-term Fix
- Known gap: this fork's `main` predates Emmanuel's 2026-09-05 wording fixes and this week's React-18 dependency correction (both only existed on the now-archived deployment's history) — those are not present in the newly deployed code and would need to be reapplied/re-merged if still wanted.
- `origin` in the new checkout has no working credentials for future `git pull` (same anonymous-access problem noted above) — needs an SSH deploy key or credential helper if ongoing pulls from this fork are expected.

## Prevention
- [ ] Decide and document the single canonical Market-Link repo going forward (see linked Architecture_and_Design entry)
- [ ] Set up a real credential (SSH deploy key or PAT via credential helper, not embedded in a remote URL) for whichever repo is canonical
- [ ] Consider porting the deployed-only content (Sep 5 wording fixes, React 18 fix) into the fork now live, since it's currently missing

## Related Issues
- [[Market-Link-2026-09-12-unmerged-fork-divergence-origin-vs-torto]] — the investigation and decision that led to this cutover.
- [[Market-Link-2026-09-11-stale-images-not-rebuilt]]
- [[Market-Link-2026-09-10-frontend-build-json-syntax-stuck-rebase]]
- [[Market-Link-2026-09-11-react-version-mismatch-frontend-build]]

## References
- Archived prior deployment: `/home/user/Documents/agromarket.archived-2026-09-12`
- Backups: `/home/user/backups/agromarket-2026-09-12/`
- Rollback path: `git checkout pre-torto-replace-2026-09-12` in the archived repo, retag `*-2026-09-12` images back to `:latest`, `docker compose up -d`; restore DB via `mongorestore --archive=digital-agro-backup.archive.gz --gzip` if ever needed.

---

**Resolved By:** Tino (via Claude Code)
**Time to Resolution:** ~40 minutes (including full backup)
