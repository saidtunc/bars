# Syncing Two Operators Over the Network

Each operator runs the app (Docker) on **their own computer**. The two backends sync their databases **over the network** so both see the same projects, members, and checklist state.

---

## Add peers from the app (recommended)

You can connect to another operator **without editing env files**:

1. **Enable sync** on both backends: set `SYNC_ENABLED=true` and a unique `NODE_ID` (e.g. `node-op1`, `node-op2`) in `.env` on each machine, then restart.
2. **Open Sync** in the sidebar (or go to **Sync & Collaboration**).
3. **Your node**: Note your node ID and the URL collaborators should use (your IP and port 8000, e.g. `http://192.168.1.10:8000`). Optionally set `PUBLIC_BASE_URL` in the backend env to show a copyable URL.
4. **Add peer**: Enter the other operator’s backend URL (e.g. `http://192.168.1.20:8000`) and an optional label (e.g. "Operator2"), then click **Add peer**.
5. **Other side**: The other operator does the same and adds your URL as a peer. Once both have added each other, sync runs automatically.

Peers are stored in the database and used by the sync worker. **Env `SYNC_PEERS`** remains optional if you want to configure extra peers or automate setup (env peers and in-app peers are merged).

---

## How it works

- **Operator1’s computer**: runs `docker-compose up` → backend (port 8000) + frontend (3000), own SQLite DB.
- **Operator2’s computer**: runs `docker-compose up` → backend (port 8000) + frontend (3000), own SQLite DB.

Each backend periodically **pulls** events from the other and **pushes** its own events. Users, projects, project members, checklist items, hosts, executions, and claims replicate between the two databases.

**What syncs:** Project variables (including empty values), variable imports from the library, execution creates and updates (status, output, completion, cancel/stop), and execution deletions are all synced. Every event—task start, status change, completion, failure, timeout, cancel, and delete—is replicated so both operators see the same state.

---

## 1. Network requirements

The two machines must reach each other on **port 8000** (backend API):

- **Same LAN**: use the other operator’s local IP (e.g. `192.168.1.20`).
- **Over internet**: use public IP or hostname and ensure port 8000 is forwarded to the backend container on that machine. A VPN (e.g. Tailscale, WireGuard) is recommended so you can use private IPs.

**Firewall**: allow inbound TCP **8000** on the machine running the backend so the other operator’s backend can call `/api/v1/sync/pull` and `/api/v1/sync/push`.

**Check connectivity** (from Operator2’s machine, replace with Operator1’s IP):

```bash
curl -s http://<OP1_IP>:8000/health
```
You should see `{"status":"healthy"}`. If not, check firewall and that the other backend is running.

---

## 2. Enable sync (minimal env)

Each operator uses the **same** `docker-compose.yml` (one backend per machine). In `.env` on **each** computer set at least:

```env
SYNC_ENABLED=true
NODE_ID=node-op1
```

(Use a different `NODE_ID` per instance, e.g. `node-op2` on the other machine.)

You do **not** need to set `SYNC_PEERS` in env if you add peers from the app (Sync page). To add peers via env as well, use:

```env
SYNC_PEERS=http://<OTHER_IP>:8000
```

Restart after changing env:

```bash
docker-compose down && docker-compose up -d
```

---

## 3. Run the app on both computers

- **Operator1**: `docker-compose up --build` (or `-d`). Open http://localhost:3000.
- **Operator2**: `docker-compose up --build` (or `-d`). Open http://localhost:3000.

Each uses their **own** frontend and backend; the backends sync in the background (every few seconds, see `SYNC_PULL_INTERVAL_SECONDS`).

### Operator2 machine: what to do (migrations, etc.)

Use the **same codebase version** on both machines so sync payloads and schema match.

- **Fresh install (new database)**  
  Just start the app. On first start, `init_db()` creates all tables (including `sync_peers` and collaboration columns). No migration step required.

- **Existing database (e.g. app was run before with older code)**  
  Run migrations so the schema matches operator1:
  ```bash
  cd backend && python -m alembic upgrade head
  ```
  Then start the app as usual.

- **Environment**  
  On operator2’s machine set in `.env`: `SYNC_ENABLED=true` and a **unique** `NODE_ID` (e.g. `node-op2`). Restart the backend after changing.

- **Peers**  
  In the app, open **Sync** and add operator1’s backend URL (e.g. `http://<operator1-ip>:8000`). Operator1 must add operator2’s URL as a peer as well. Once both have added each other, sync runs in both directions.

---

## 4. Join the same project

1. **Operator1** registers on their app (their backend). **Operator2** registers on their app (their backend).
2. Wait **~30–60 seconds** so sync replicates both users to the other backend.
3. **Operator1**: Create a project → open **Collaborators** → **Add** Operator2 by **username or email** (the one Operator2 used to register). Save.
4. After sync runs, **Operator2** refreshes; the shared project appears. Both work on the same checklist; changes and claims sync over the network.

---

## 5. Troubleshooting: Op2 doesn’t see the project

For the project (and “Op2 added as member”) to appear on Op2’s app, **Op1’s backend must push** those events to Op2’s backend. Check the following:

1. **Op1 has Op2 as a peer**  
   On **Op1’s** machine: open the app → **Sync** → the list must contain **Op2’s backend URL** (e.g. `http://OP2_IP:8000`). If not, Op1 never pushes to Op2, so Op2 will not see the project. Add Op2’s URL and wait ~10–15 seconds, then Op2 refreshes the dashboard.

2. **Both have sync enabled**  
   On both machines, `.env` must have `SYNC_ENABLED=true` and a unique `NODE_ID`. Restart the backend after changing env.

3. **Op1’s backend can reach Op2’s backend**  
   From Op1’s computer run:  
   `curl -s http://OP2_IP:8000/health`  
   You should get `{"status":"healthy"}`. If it fails, fix firewall or network (port 8000 must be open on Op2’s machine for Op1’s IP).

4. **Op2’s user was synced to Op1 before adding as member**  
   Op1 can only “Add Op2” if Op2’s user already exists on Op1’s node. That requires **Op2 to have Op1 as a peer** so Op2’s backend pushes (e.g. registration) to Op1. So: Op2 adds Op1 as peer first, wait ~30 s, then Op1 creates the project and adds Op2.

5. **Backend logs**  
   If sync fails, the backend logs lines like `[SyncWorker] Peer sync failed for http://...: ...`. Check Docker/backend logs on both sides for errors.

---

## 6. Optional env tuning

In `.env` on either or both machines:

```env
SYNC_PULL_INTERVAL_SECONDS=5
SYNC_BATCH_SIZE=200
PUBLIC_BASE_URL=http://your-ip:8000
```

`PUBLIC_BASE_URL` (optional) is shown on the Sync page as “your node” URL for collaborators. Default sync interval is 5 seconds.

---

## Summary

| Step | Action |
|------|--------|
| 1 | Allow TCP 8000 between the two machines (firewall / port forward if over internet). |
| 2 | On each computer: `SYNC_ENABLED=true`, unique `NODE_ID`. Restart. |
| 3 | In the app: open **Sync**, add the other operator’s URL. **Both** must add each other (Op1 adds Op2’s URL, Op2 adds Op1’s URL) so users and projects sync both ways. |
| 4 | Both run `docker-compose up`; each opens http://localhost:3000 on their own machine. |
| 5 | Both register; wait ~30 s for user sync; then Op1 creates project and adds Op2 in Collaborators. Op2 should see the project within ~10–15 s; if not, see “Troubleshooting” above. |

Databases stay in sync over the network; no shared server or single DB required.
