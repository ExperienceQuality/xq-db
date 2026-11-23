#!/usr/bin/env bash
# Builds and verifies a throwaway migrated xq database in container xq-db-ci on localhost:5432.
set -euo pipefail
source versions.env
C=xq-db-ci

docker rm -f "$C" >/dev/null 2>&1 || true
docker run -d --name "$C" -e POSTGRES_PASSWORD=ci -e POSTGRES_DB=xq -p 5432:5432 -v "$PWD:/repo:ro" "postgres:$PG_VERSION-bookworm"
for i in $(seq 1 60); do docker exec "$C" pg_isready -h 127.0.0.1 -U postgres -d xq >/dev/null 2>&1 && break; sleep 1; done

as_super() { docker exec -e PGPASSWORD=ci "$C" psql -h 127.0.0.1 -U postgres -d xq -v ON_ERROR_STOP=1 -tA "$@"; }
as_role()  { local role=$1; shift; docker exec -e PGPASSWORD="$role"_test "$C" psql -h 127.0.0.1 -U "$role" -d xq -v ON_ERROR_STOP=1 -tA "$@"; }
fw()       { docker run --rm --network host -v "$PWD:/repo:ro" -w /repo -e FLYWAY_URL=jdbc:postgresql://localhost:5432/xq -e FLYWAY_USER="$1"_migrator -e FLYWAY_PASSWORD="$1"_migrator_test "flyway/flyway:$FLYWAY_VERSION" -configFiles="flyway/$1.toml" "$2"; }
expect()   { local got; got=$(as_super -c "$1"); if [ "$got" != "$2" ]; then echo "::error::expected $2 from: $1 (got $got)"; exit 1; fi; }

as_super -f /repo/image/initdb/00-roles.sql
for s in exercise routine; do
  as_role "$s"_migrator -f "/repo/guard/$s.sql"
  fw "$s" migrate
  as_role "$s"_migrator -f "/repo/guard/$s.sql"
  fw "$s" validate
done

expect "select has_schema_privilege('routine_app', 'exercise', 'USAGE')" f
expect "select has_schema_privilege('exercise_app', 'routine', 'USAGE')" f
expect "select has_schema_privilege('routine_app', 'routine', 'CREATE')" f
expect "select has_schema_privilege('exercise_app', 'exercise', 'CREATE')" f
expect "select has_database_privilege('routine_app', 'xq', 'CREATE')" f
expect "select has_database_privilege('exercise_app', 'xq', 'CREATE')" f
for s in exercise routine; do
  app="$s"_app
  if [ "$(as_super -c "select to_regclass('$s.flyway_schema_history') is not null")" = t ]; then
    expect "select has_table_privilege('$app', '$s.flyway_schema_history', 'SELECT')" t
    expect "select has_table_privilege('$app', '$s.flyway_schema_history', 'INSERT')" f
    echo "$s version: $(as_role "$app" -c "select coalesce(max(cast(version as integer)), 0) from $s.flyway_schema_history where success and version is not null")"
  fi
done
echo "xq database verified"
