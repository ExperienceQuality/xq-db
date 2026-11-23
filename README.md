# xq-db

Owns Neon database provisioning guards, Flyway migrations, and the migrated Postgres test image for Experience Quality services. Services keep only runtime data-access code.

## Neon (production)

| Fact | Value |
|------|-------|
| Project | `xq` |
| Branch | `production` |
| Database (active) | `xq` |
| Schemas | `routine`, `exercise` |
| Postgres | **18.7** (`PostgreSQL 18.7 (84da7d8) on aarch64-unknown-linux-gnu`) |
| Migrator roles | `routine_migrator`, `exercise_migrator` |
| App roles | `routine_app`, `exercise_app` |
| Legacy database | `fitness` (still present; dropped in Step 5.1 / issue #3) |

### Endpoints

- **Direct** (non-pooled): Flyway / guards / `Migrate prod` workflow only. Host must not contain `-pooler`.
- **Pooled**: service runtime datasources on Render (`routine_app` / `exercise_app`).

App roles have `search_path` pinned (`routine_app` → `routine`, `exercise_app` → `exercise`) because Neon’s pooled endpoint uses PgBouncer transaction mode.

## Versions

Single pin file: [`versions.env`](versions.env).

```
PG_VERSION=18.7
FLYWAY_VERSION=13.13.0
```

CI and scripts resolve `postgres:$PG_VERSION-bookworm` → `postgres:18.7-bookworm`.

## Layout

| Path | Role |
|------|------|
| `guard/*.sql` | Idempotent schema ownership, DML grants, Flyway-history SELECT for app roles |
| `flyway/*.toml` | Per-schema Flyway config (`createSchemas = false`) |
| `migrations/{routine,exercise}/` | Versioned table migrations (empty until Step 2.1) |
| `image/initdb/00-roles.sql` | Test-only roles/grants for throwaway Postgres / future GHCR image |
| `scripts/lint-migrations.sh` | Naming + forbidden DDL lint |
| `scripts/build-db.sh` | Throwaway Postgres 18.7: roles → guard → Flyway → privilege checks |

Migrations must never create/drop/alter schemas, extensions, roles, or databases, and must never `GRANT`/`REVOKE` (lint enforces). Guards own that. Integer versions only (`V1`, `V2`, …). Flyway `clean` stays disabled.

## Local verify

```bash
bash scripts/lint-migrations.sh
bash scripts/build-db.sh          # ends with: xq database verified
bash scripts/build-db.sh          # second run: guard + Flyway still green
docker rm -f xq-db-ci
```

## Release flow

1. PR → CI (`Guard and migrations`) on throwaway Postgres 18.7  
2. Merge to `main`  
3. Publish migrated GHCR image (Step 2.1)  
4. Services bump their image pin + minimum schema version  
5. David runs **Actions → Migrate prod** against Neon `xq` (direct endpoint)

## Expand / contract

- **expand** (`expand` label): additive, backward-compatible with the service version currently deployed.  
- **contract** (`contract` label): removals only after no deployed service uses the old shape.  
- Cross-repo DB work uses `db-change`.

## GitHub `production` environment

Used by the future `Migrate prod` workflow. Secrets (direct Neon endpoint; never commit values):

| Secret | Purpose |
|--------|---------|
| `NEON_DIRECT_HOST` | Neon direct host for database `xq` (reject `*-pooler*`) |
| `ROUTINE_MIGRATOR_PASSWORD` | Password for `routine_migrator` |
| `EXERCISE_MIGRATOR_PASSWORD` | Password for `exercise_migrator` |

CI never talks to Neon. No Neon secrets outside the `production` environment.
