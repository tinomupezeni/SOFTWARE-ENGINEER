# ADR: Multi-VM High-Availability Database Infrastructure & Failover Architecture

**Date:** 2026-11-24  
**Project:** TESC (ScalarEye)  
**Type:** Architecture Decision Record (ADR)  
**Status:** Proposed / Approved for Prototyping  

---

## 1. Context & Problem Statement

During an in-person institutional training session and large-scale bulk data upload in Chinhoyi, TESC (ScalarEye) experienced an infrastructure disruption that required restarting the host virtual machine (VM). 

While a local blue-green deployment pipeline was operational on the host, **both blue and green environments were co-located on the same physical VM (`10.50.200.35`)**. When the underlying VM became unresponsive:
1. Both application environments went down simultaneously.
2. The single PostgreSQL 15 database instance was immediately unavailable.
3. Recovery required full manual intervention, taking approximately 1–2 hours of downtime (RTO) before operations could be restored from backups.

### The Problem
- **Single Point of Failure (SPOF)**: Containerization and local blue-green pipelines provide software release safety, but provide **zero infrastructure redundancy**. A host-level crash, kernel panic, hypervisor glitch, or physical maintenance causes total system outages.
- **Data Risk & Recovery Friction**: Relying on periodic manual `pg_dump` backups for recovery results in an unpredictable Recovery Point Objective (RPO) and high Recovery Time Objective (RTO).

---

## 2. Decision Drivers & Constraints

1. **RTO (Recovery Time Objective)**: Target $< 30$ seconds for automatic database failover (down from 1–2 hours).
2. **RPO (Recovery Point Objective)**: Target $\approx 0$ (no uncommitted or lost data during an unexpected host failure).
3. **Split-Brain Prevention**: Zero tolerance for split-brain where two database instances accept concurrent conflicting writes.
4. **Application Transparency**: Django, Celery, and Nginx must seamlessly route traffic to the active primary without requiring manual configuration rewrites or container rebuilds.
5. **Infrastructure Topology**: The ZCHPC VM infrastructure allows provisioning additional VMs with static private network connectivity (`10.50.x.x`).

---

## 3. Considered Options

### Option 1: Managed Cloud Database (DBaaS)
- *Description*: Offload replication, backups, and failover to a cloud provider (e.g. AWS RDS, Azure Postgres).
- *Pros*: Out-of-the-box HA, automated point-in-time recovery.
- *Cons*: **Violates sovereignty and infrastructure requirements**. TESC is a national educational record system hosted on government infrastructure (ZCHPC) on premises/private cloud. External public cloud DBaaS is disallowed.

### Option 2: Active-Passive VM with Shared Network Storage (NFS/SAN)
- *Description*: Run standby VM attached to the same shared network storage volume.
- *Pros*: Simple replication model.
- *Cons*: Storage becomes the SPOF. Corrupted file systems propagate immediately to the standby. High risk of split-brain if lock files are not properly released.

### Option 3: Distributed PostgreSQL Cluster via Patroni + etcd + Streaming Replication (Selected)
- *Description*: Deploy a multi-node Patroni cluster managing PostgreSQL 15 instances with physical streaming replication, coordinated by a 3-member `etcd` distributed consensus cluster across distinct VMs.
- *Pros*: Industry standard for PostgreSQL HA. Automatic, safe failover. Mathematical split-brain prevention via Raft consensus. Decoupled from application releases.
- *Cons*: Requires managing distributed consensus (`etcd`) and health-checking proxies (HAProxy/PgBouncer).

---

## 4. Architectural Decision & Target Topology

We agree to adopt **Option 3: PostgreSQL High Availability with Patroni and etcd consensus across a minimum of 3 nodes/VMs**.

### System Diagram

```
                        [ Ingress Layer: DNS / Floating IP / VIP ]
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
  ┌──────────────┐            ┌──────────────┐            ┌──────────────┐
  │     VM 1     │            │     VM 2     │            │ VM 3 (Witness│
  │ (App + DB 1) │            │ (App + DB 2) │            │  / Arbiter)  │
  ├──────────────┤            ├──────────────┤            ├──────────────┤
  │ Nginx        │            │ Nginx        │            │              │
  │ Dual Frontends│           │ Dual Frontends│           │              │
  │ Django API   │            │ Django API   │            │              │
  │ Celery Worker│            │ Celery Worker│            │              │
  ├──────────────┤            ├──────────────┤            ├──────────────┤
  │ HAProxy      │            │ HAProxy      │            │              │
  │ (Port 5000)  │            │ (Port 5000)  │            │              │
  ├──────────────┤            ├──────────────┤            ├──────────────┤
  │ Patroni + PG │ ◄────────► │ Patroni + PG │            │              │
  │ (Leader)     │StreamingRep│ (Replica)    │            │              │
  ├──────────────┤            ├──────────────┤            ├──────────────┤
  │ etcd Node 1  │ ◄────────► │ etcd Node 2  │ ◄────────► │ etcd Node 3  │
  └──────────────┘    Raft    └──────────────┘    Raft    └──────────────┘
         │                           │                           │
         └───────────────────────────┴───────────────────────────┘
                                     │
                             (pgBackRest WAL Archive)
                                     ▼
                    [ Dedicated Remote Backup Storage ]
```

### Detailed Component Specifications

#### 1. Consensus & Leader Election (`etcd`)
- A 3-member `etcd` cluster using the Raft consensus protocol.
- Quorum rule: Requires $\lfloor N/2 \rfloor + 1 = 2$ votes.
- If VM 1 drops, VM 2 and VM 3 form a quorum (2/3 votes) and safely authorize leadership transition.
- If VM 2 and VM 3 lose network access to each other, promotion is strictly blocked, preventing dual primaries.

#### 2. PostgreSQL Role & Lifecycle Management (`Patroni`)
- Patroni acts as the supervisor on each database node, continuously holding a dynamic lease in `etcd` (TTL 10s, loop_wait 2s).
- **Replication Mode**: Semi-synchronous (`synchronous_mode: true`, `synchronous_mode_strict: false`). Transactions wait for standby acknowledgment during normal operation ($RPO=0$), but gracefully downgrade to asynchronous if the standby is down, avoiding write freezes during isolated maintenance.
- **Demotion & Rewind**: If a partitioned leader rejoins after being superseded, Patroni automatically issues `pg_rewind` to resynchronize its WAL timeline with the new leader before re-attaching as a standby.

#### 3. Database Connection Routing (`HAProxy`)
- To avoid hardcoded database IP addresses in Django (`backend/.env`), a local `HAProxy` sidecar runs on each application VM listening on `127.0.0.1:5000`.
- HAProxy continuously polls Patroni’s REST endpoint:
  - `GET http://<db-node>:8008/primary` (Returns HTTP 200 on Leader, 503 on Standby).
- Django and Celery configure:
  ```env
  DB_HOST=127.0.0.1
  DB_PORT=5000
  ```
- Connection failover happens in $< 3$ seconds without restarting Django or Celery containers.

#### 4. Backup & Disaster Recovery (`pgBackRest` / Continuous WAL Archiving)
- Reiteration of the rule: **Replication is for availability; Backups are for recovery.**
- Introduce **`pgBackRest`** with scheduled full/differential base backups and continuous WAL archiving to an off-VM NFS mount or S3-compatible bucket.
- Unlocks **Point-in-Time Recovery (PITR)**: Enables rolling back database state to an exact second prior to accidental data deletion or schema corruption.

---

## 5. Consequences & Trade-offs

### Positive Consequences
- **Eliminates Database SPOF**: Complete immunity to single-VM crashes, power drops, or kernel freezes.
- **RTO reduced from 1–2 hours to $< 30$ seconds**: Automatic detection and promotion without manual intervention.
- **Safe Maintenance**: OS patches, kernel updates, and hypervisor reboots can be performed via controlled `patroni switchover` with zero downtime.
- **Preserved Blue-Green Deployment**: Application code updates retain the fast rollback safety of Docker blue-green, now running across redundant nodes.

### Negative / Operational Consequences
- **Operational Complexity**: Managing an etcd cluster requires monitoring quorum health, disk write latency, and clock synchronization (NTP).
- **Resource Footprint**: Requires a 3rd VM or lightweight witness instance (can be 1 vCPU, 2GB RAM) to maintain etcd consensus.
- **Network Dependency**: Low-latency private network link ($< 10$ms) between VMs is required for streaming replication and Raft heartbeats.

---

## 6. Implementation Roadmap

1. **Phase 1: Continuous WAL Archiving & Recovery Verification**
   - Deploy `pgBackRest` to ship continuous WAL logs off-host.
   - Validate PITR restore onto a scratch environment.
2. **Phase 2: Staging Sandbox Prototype**
   - Provision test VMs; configure 3-node etcd and 2-node Patroni PostgreSQL cluster.
   - Perform Chaos Injection tests: Kill primary container, measure promotion latency, verify zero data loss.
3. **Phase 3: Connection Routing & Application Validation**
   - Configure HAProxy sidecar; test Django connection re-establishment on failover.
4. **Phase 4: Ingress & Redundant Production Deployment**
   - Provision production secondary VM; join cluster; test planned switchover during low-traffic window.

---

## 7. Compliance with Engineering Guides

This ADR directly implements mandates from:
- **Guide 4 (Site Reliability Engineering)**: Elimination of SPOF, explicit RTO/RPO budgets.
- **Guide 6 (Database Engineering)**: Replication topology, split-brain protection, PITR WAL archiving.
- **Guide 10 (Deployment & Maintenance)**: Host-level failure resilience beneath Docker.

---
**Author:** Antigravity (Principal Systems Architect)  
**Status:** Approved for implementation planning  
