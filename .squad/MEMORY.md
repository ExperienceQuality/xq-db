# Squad Memory

This file holds canonical, human-readable knowledge for the repository. Update it during memory maintenance when durable conventions, architecture, or decisions are discovered.

## Repository map

- `versions.env` — single pin: `PG_VERSION=18.7`, `FLYWAY_VERSION=13.13.0`
- `guard/{routine,exercise}.sql` — idempotent schema + grants; must run as matching `*_migrator`
- `flyway/{routine,exercise}.toml` — per-schema Flyway 13 TOML (`schemas` under `[environments.default]`)
- `migrations/{routine,exercise}/` — versioned SQL only (empty until Step 2.1); no schema/extension/role/grant DDL
- `image/initdb/00-roles.sql` — test-only roles (`*_test` passwords); `10-xq.sql` gitignored (Step 2.1 dump)
- `scripts/lint-migrations.sh` — naming + forbidden DDL
- `scripts/build-db.sh` — throwaway `postgres:18.7-bookworm` + Flyway verify on localhost:5432
- `.github/workflows/ci.yml` — PR/main CI; never talks to Neon

## Conventions

- Pin Postgres image as `postgres:$PG_VERSION-bookworm` (not bare major).
- Flyway OSS 13: put `schemas` under `[environments.default]`; keep `defaultSchema` / `createSchemas` / `table` under `[flyway]`. Connection via `FLYWAY_URL` / `FLYWAY_USER` / `FLYWAY_PASSWORD`.
- Guards run before and after Flyway. App roles get DML + SELECT on `flyway_schema_history` only (no INSERT/UPDATE/DELETE on history).
- Integer migration versions only: `V<n>__snake_case.sql`.
- Labels: `db-change`, `expand`, `contract`.

## Architecture

- Neon project `xq`, branch `production`, active DB `xq`, schemas `routine` + `exercise`.
- Roles: `routine_migrator`, `exercise_migrator`, `routine_app`, `exercise_app`. Legacy DB `fitness` remains until Step 5.1.
- Direct Neon endpoint for migrators; pooled for service app roles.
- GitHub `production` environment secrets (values not in repo): `NEON_DIRECT_HOST`, `ROUTINE_MIGRATOR_PASSWORD`, `EXERCISE_MIGRATOR_PASSWORD`.

## Testing strategy

- Local/CI: `bash scripts/lint-migrations.sh` then `bash scripts/build-db.sh` → ends with `xq database verified`.
- Privilege asserts in `build-db.sh`: no cross-schema USAGE, no CREATE for app roles, history SELECT yes / INSERT no.

## Lessons

- Spec draft put `schemas` under `[flyway]`; Flyway 13.13.0 rejects that (`Unknown: 'flyway.schemas'`). Use environments namespace instead.
