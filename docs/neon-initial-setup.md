# Neon Initial Setup (Historical Record)

Recorded: 2026-11-23  
Related: ADR-001 (Decouple database infrastructure from `xq-svc-routine` and `xq-svc-exercice`), `xq-db#1`

## Environment

- **Platform:** Neon (production only; no staging branch)
- **Project:** `xq`
- **Branch:** `main`
- **PostgreSQL version:** `PostgreSQL 18.7 (84da7d8) on aarch64-unknown-linux-gnu, compiled by gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0, 64-bit`
- **New database:** `xq`
- **Legacy database:** `fitness` (retained until both services pass Deployment Smoke Tests on `xq`, then dropped in Step 5 / `xq-db#3`)

## Manual Provisioning Steps Executed (Step 1.1)

### 1. Confirmed production PostgreSQL version

Ran in the Neon SQL Editor on branch `main`:

```sql
SELECT version();
```

Result: `PostgreSQL 18.7 (84da7d8) on aarch64-unknown-linux-gnu`.
This version is pinned in xq-db CI (`postgres:18.7-bookworm`) and in the GHCR test image tag (`ghcr.io/experiencequality/xq-db-postgres:18.7-<sha>`).

### 2. Created database `xq`

Created fresh database `xq` inside the existing Neon project `xq` (alongside the legacy `fitness` database).

### 3. Created migrator roles

Created `routine_migrator` and `exercise_migrator` in Neon Console (Roles → Add role), and granted database-level `CONNECT` and `CREATE` on `xq`:

```sql
GRANT CONNECT, CREATE ON DATABASE xq TO routine_migrator;
GRANT CONNECT, CREATE ON DATABASE xq TO exercise_migrator;
```

Passwords are stored only in xq-db's GitHub production environment secrets (`ROUTINE_MIGRATOR_PASSWORD`, `EXERCISE_MIGRATOR_PASSWORD`, along with `NEON_DIRECT_HOST`) and are used over Neon's direct (non-pooled) endpoint by `migrate-prod.yml`.

### 4. Created least-privilege runtime app roles via SQL

Created via SQL Editor connected to database `xq` (not via Neon Console, because Console-created roles automatically join `neon_superuser`):

```sql
CREATE ROLE routine_app WITH LOGIN PASSWORD '<stored-in-render>';
CREATE ROLE exercise_app WITH LOGIN PASSWORD '<stored-in-render>';

GRANT CONNECT ON DATABASE xq TO routine_app;
GRANT CONNECT ON DATABASE xq TO exercise_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
```

Passwords are stored in each service's Render environment group (`xq-svc-routine` and `xq-svc-exercise`) using Neon's pooled endpoint.

### 5. Verified app roles are not `neon_superuser`

```sql
SELECT rolname,
       pg_has_role(rolname, 'neon_superuser', 'member') AS is_neon_superuser
FROM pg_roles
WHERE rolname IN ('routine_migrator', 'exercise_migrator', 'routine_app', 'exercise_app');
```

Confirmed `is_neon_superuser = false` for both `routine_app` and `exercise_app`.

## Managed by xq-db (Not Created Manually)

- Schemas `routine` and `exercise`
- `USAGE`, DML, default table privileges, and `SELECT` on each schema's `flyway_schema_history` table (applied idempotently by `guard/routine.sql` and `guard/exercise.sql`)
- All table DDL via Flyway migrations in `migrations/routine/` and `migrations/exercise/`
