#!/usr/bin/env bash
# Usage: publish-image.sh <git-sha> [--push]. Needs image/initdb/10-xq.sql (build-db.sh + pg_dump).
# Tags: $PG_VERSION-<sha> (immutable) and $PG_VERSION-latest (floating).
set -euo pipefail
source versions.env
REPO="ghcr.io/experiencequality/xq-db-postgres"
TAG="$REPO:$PG_VERSION-$1"
LATEST="$REPO:$PG_VERSION-latest"
S=xq-db-image-smoke
docker build --build-arg PG_VERSION="$PG_VERSION" -t "$TAG" -t "$LATEST" image
docker rm -f "$S" >/dev/null 2>&1 || true
docker run -d --name "$S" -e POSTGRES_PASSWORD=smoke "$TAG"
for i in $(seq 1 90); do docker exec "$S" pg_isready -h 127.0.0.1 -U postgres -d xq >/dev/null 2>&1 && break; sleep 1; done
for s in routine exercise; do
  v=$(docker exec -e PGPASSWORD="$s"_app_test "$S" psql -h 127.0.0.1 -U "$s"_app -d xq -v ON_ERROR_STOP=1 -tA -c "select coalesce(max(cast(version as integer)), 0) from $s.flyway_schema_history where success and version is not null")
  echo "$s schema version in image: $v"
  [ "$v" -ge 1 ]
done
docker rm -f "$S"
if [ "$#" -ge 2 ] && [ "$2" = "--push" ]; then
  docker push "$TAG"
  docker push "$LATEST"
  {
    echo "Published $TAG"
    echo "Published $LATEST"
  } >> "$GITHUB_STEP_SUMMARY"
fi
echo "$TAG"
echo "$LATEST"
