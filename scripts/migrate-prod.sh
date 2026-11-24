#!/usr/bin/env bash
# Usage: migrate-prod.sh <routine|exercise>. Env: NEON_DIRECT_HOST, MIGRATOR_PASSWORD. Direct Neon endpoint only.
set -euo pipefail
source versions.env
s=$1
case "$s" in routine|exercise) ;; *) echo "unknown schema: $s"; exit 1 ;; esac
case "$NEON_DIRECT_HOST" in *-pooler*) echo "NEON_DIRECT_HOST must be the direct endpoint, not -pooler"; exit 1 ;; esac
export PGPASSWORD="$MIGRATOR_PASSWORD" FLYWAY_PASSWORD="$MIGRATOR_PASSWORD"
user="$s"_migrator
guard() { docker run --rm -v "$PWD:/repo:ro" -e PGPASSWORD "postgres:$PG_VERSION-bookworm" psql "host=$NEON_DIRECT_HOST dbname=xq user=$user sslmode=require" -v ON_ERROR_STOP=1 -f "/repo/guard/$s.sql"; }
fw() { docker run --rm -v "$PWD:/repo:ro" -w /repo -e FLYWAY_PASSWORD -e FLYWAY_URL="jdbc:postgresql://$NEON_DIRECT_HOST/xq?sslmode=require" -e FLYWAY_USER="$user" "flyway/flyway:$FLYWAY_VERSION" -configFiles="flyway/$s.toml" "$1"; }
guard
fw info
fw migrate
guard
fw validate
fw info
