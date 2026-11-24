# TESC High-Availability Database Cluster Implementation & Verification Report

**Date:** 2026-11-24  
**Project:** TESC (ScalarEye)  
**Type:** Infrastructure / Reliability Implementation  
**Status:** Completed & Staged  

---

## 1. Summary
Following the infrastructure downtime experienced during training in Chinhoyi, we designed, deployed, and validated an isolated, multi-VM high-availability database cluster without disrupting the live production environment (`tesc-main-db-1` on port 5432).

The implementation distributes database responsibilities across three VMs:
- **`tesc-prod` (`10.50.200.35`)**: Patroni PostgreSQL Member + `etcd` Member 1
- **`tesc-staging` (`10.50.1.37`)**: Patroni PostgreSQL Member + `etcd` Member 2 + HAProxy Router
- **`erp-vm` (`10.50.14.12`)**: `etcd` Member 3 (Arbiter / Witness for Raft quorum)

---

## 2. Infrastructure Setup & Non-Disruptive Port Allocation

To guarantee zero disturbance to running production workloads:
1. **Production DB remains untouched**: The live database container `tesc-main-db-1` continues running undisturbed on internal port `5432`.
2. **HA Cluster isolated to port `5433`**: Both Patroni instances communicate on host port `5433` with REST API on `8008`.
3. **Consensus on standard ports `2379/2380`**: All three VMs form an etcd v3.5 cluster using Raft consensus.
4. **HAProxy Smart Router on ports `5000/5001`**:
   - `127.0.0.1:5000`: Primary / Read-Write (health checks `GET /primary` expecting HTTP 200).
   - `127.0.0.1:5001`: Standby / Read-Only (health checks `GET /replica` expecting HTTP 200).

---

## 3. Verification & Live Switchover Results

### A. Cluster State & Quorum
```text
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+
|         ENDPOINT         |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+
|   http://10.50.1.37:2379 | f98640db5c0a4bc5 |  3.5.15 |   20 kB |      true |      false |         2 |         11 |
| http://10.50.200.35:2379 | 2f13bb1254fc4151 |  3.5.15 |   20 kB |     false |      false |         2 |         11 |
|  http://10.50.14.12:2379 |  79062ad7dc67bf1 |  3.5.15 |   20 kB |     false |      false |         2 |         11 |
+--------------------------+------------------+---------+---------+-----------+------------+-----------+------------+
```

### B. Streaming Replication Test
- Created table `ha_test_log` on initial leader (`pg-staging`, `10.50.1.37`).
- Inserted record: *"Live streaming replication active between tesc-staging and tesc-prod"*.
- Queried standby replica (`pg-prod`, `10.50.200.35`): Immediately present with 0 lag (`receive_lag: 0`, `replay_lag: 0`).

### C. Live Failover / Switchover Test
Triggered controlled switchover using `patronictl switchover --leader pg-staging --candidate pg-prod --force`:
1. `pg-staging` demoted cleanly and stopped.
2. `pg-prod` promoted to Leader on Timeline 2.
3. `pg-staging` re-attached automatically as streaming replica.
4. HAProxy (`127.0.0.1:5000`) detected the promotion via Patroni HTTP health checks and automatically shifted write traffic from `10.50.1.37` to `10.50.200.35` within 3 seconds.
5. Executed write test through HAProxy port `5000`:
   ```sql
   INSERT INTO ha_test_log (note) VALUES ('Write completed to new leader on tesc-prod through port 5000!');
   ```
   Successfully written to `10.50.200.35` while connected to local `127.0.0.1:5000`.

---

## 4. Operational Runbook

### Inspecting Cluster Status
On either `tesc-staging` or `tesc-prod`:
```bash
docker exec tesc-ha-db patronictl -c /etc/patroni/patroni.yml list
```

### Checking etcd Quorum Health
```bash
docker exec tesc-etcd etcdctl endpoint health --endpoints=http://10.50.1.37:2379,http://10.50.200.35:2379,http://10.50.14.12:2379
```

### Performing Controlled Maintenance Switchover
```bash
docker exec tesc-ha-db patronictl -c /etc/patroni/patroni.yml switchover
```

---

## 5. Next Steps for Production Cutover (Scheduled Window)
When ready to migrate production traffic to the HA cluster:
1. Schedule a brief 2-minute maintenance window.
2. Take a fresh `pg_dump` of `tesc-main-db-1` on `tesc-prod`.
3. Restore dump into Patroni cluster via HAProxy port `5000`:
   ```bash
   psql -h 127.0.0.1 -p 5000 -U postgres tesc_db < prod_backup.sql
   ```
4. Update `docker-compose.yml` backend DB settings:
   ```env
   DB_HOST=127.0.0.1
   DB_PORT=5000
   ```
5. Remove the legacy single-host `db` service container.
