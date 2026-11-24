# TESC / ScalarEye — Database Design Decisions

**Last updated:** 2026-11-24  

## 1. Single Database with FK Institutional Isolation (vs. Multi-tenant Schema/DB)
- **Chose:** Single PostgreSQL 15 database where institutional isolation is enforced at the query and service layer via `InstitutionalIsolationMixin` and foreign keys.
- **Alternatives:** Database-per-tenant, schema-per-tenant.
- **Why:** National aggregate analytics and cross-institution reporting across hundreds of institutions need fast single-database joins; maintaining hundreds of independent database migrations for dynamic schemas is an operational bottleneck on a small team.
- **Still-valid:** Yes.

## 2. Standalone `Graduate` Table with Synced `Student` Snapshot
- **Chose:** Separate `Graduate` table with synchronized denormalized snapshots on `Student` (`status`, `graduation_year`, `final_grade`).
- **Alternatives:** Status flag on `Student` only.
- **Why:** Real-world educational workflows allow multiple graduations per person over time (e.g. Diploma then Degree).
- **Still-valid:** Yes.

## 3. High-Availability Multi-VM Clustering (Patroni + etcd)
- **Chose:** PostgreSQL 15 streaming replication managed by Patroni with a 3-member etcd Raft consensus cluster and local HAProxy routing.
- **Alternatives:** Standalone single-host Docker container; shared NFS storage.
- **Why:** The single-VM hosting of both blue and green environments presented a catastrophic single point of failure (demonstrated during the Chinhoyi training downtime). Multi-VM Patroni cluster provides $< 30$ second automatic failover and mathematical split-brain prevention.
- **Still-valid:** Yes. See formal ADR: `reports/TESC-2026-11-24-adr-multi-vm-ha-database-patroni-etcd.md`.
