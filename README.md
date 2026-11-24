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
| `migrations/{routine,exercise}/` | Versioned table migrations (`V1` for both schemas) |
| `image/Dockerfile` | TEST-ONLY migrated Postgres image (`POSTGRES_DB=xq`) |
| `image/initdb/00-roles.sql` | Test-only roles/grants (`*_test` passwords) |
| `image/initdb/10-xq.sql` | Generated pg_dump (gitignored); baked into the image in CI |
| `scripts/lint-migrations.sh` | Naming + forbidden DDL lint |
| `scripts/build-db.sh` | Throwaway Postgres 18.7: roles → guard → Flyway → privilege checks |
| `scripts/publish-image.sh` | Build/smoke-test (and optionally push) GHCR tags `18.7-<sha>` + `18.7-latest` |
| `scripts/migrate-prod.sh` | Guard → Flyway against Neon `xq` on the **direct** endpoint |

Migrations must never create/drop/alter schemas, extensions, roles, or databases, and must never `GRANT`/`REVOKE` (lint enforces). Guards own that. Integer versions only (`V1`, `V2`, …). Flyway `clean` stays disabled.

## Local verify

```bash
bash scripts/lint-migrations.sh
bash scripts/build-db.sh          # expect: exercise/routine version: 1, then xq database verified
docker exec xq-db-ci pg_dump -U postgres -d xq --schema=routine --schema=exercise > image/initdb/10-xq.sql
bash scripts/publish-image.sh local   # smoke-test only; no push
docker rm -f xq-db-ci
```

## Test image (GHCR)

Dual tags on each publish:

| Tag | Meaning |
|-----|---------|
| `ghcr.io/experiencequality/xq-db-postgres:18.7-<git-sha>` | Immutable pin (cutovers / F2) |
| `ghcr.io/experiencequality/xq-db-postgres:18.7-latest` | Floating tip of the 18.7 line |

- TEST ONLY — fixed passwords `<role>_test`; never deploy to prod.
- Database name `xq`. Start with `-e POSTGRES_PASSWORD=<anything>`.
- Services should pin the **sha** tag and minimum schema version together in `src/main/resources/xq-db.properties`; use `18.7-latest` only when a floating tip is intentional.
- Local pull: `docker login ghcr.io` with a PAT that has `read:packages`.

Published automatically after CI succeeds on `main` (`Publish image` workflow), or via `workflow_dispatch` on `main`.

## Migrate prod

1. Actions → **Migrate prod**
2. Target: `exercise` / `routine` / `both`
3. Confirm: type exactly `migrate xq`
4. Approve the `production` environment

Order per schema: guard → Flyway info → migrate → guard → validate → info. Script rejects `*-pooler*` hosts. Never edit an applied migration; every change is a new `V<n+1>` that stays backward compatible with deployed services.

## Release flow

1. PR → CI (`Guard and migrations`) on throwaway Postgres 18.7  
2. Merge to `main` → **Publish image** pushes `…:18.7-<sha>` and `…:18.7-latest`  
3. Services bump their image pin + minimum schema version  
4. David runs **Actions → Migrate prod** against Neon `xq` (direct endpoint)

## Expand / contract

- **expand** (`expand` label): additive, backward-compatible with the service version currently deployed.  
- **contract** (`contract` label): removals only after no deployed service uses the old shape.  
- Cross-repo DB work uses `db-change`.

## GitHub `production` environment

Used by the **Migrate prod** workflow. Secrets (direct Neon endpoint; never commit values):

| Secret | Purpose |
|--------|---------|
| `NEON_DIRECT_HOST` | Neon direct host for database `xq` (reject `*-pooler*`) |
| `ROUTINE_MIGRATOR_PASSWORD` | Password for `routine_migrator` |
| `EXERCISE_MIGRATOR_PASSWORD` | Password for `exercise_migrator` |

CI never talks to Neon. No Neon secrets outside the `production` environment.
