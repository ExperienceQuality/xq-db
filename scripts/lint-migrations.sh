#!/usr/bin/env bash
# Fails on misnamed migrations, duplicate versions, or DDL that belongs to guard/.
set -euo pipefail
status=0
for f in migrations/*/*.sql; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  if ! [[ "$name" =~ ^V[1-9][0-9]*__[a-z0-9_]+[.]sql$ ]]; then
    echo "::error file=$f::name must be V<integer>__<snake_case>.sql (the F2 guard casts version to integer)"; status=1
  fi
  if grep -nEi '^[[:space:]]*((create|drop|alter)[[:space:]]+(schema|extension|role|user|database)|grant|revoke|alter[[:space:]]+default[[:space:]]+privileges)([[:space:]]|$)' "$f"; then
    echo "::error file=$f::schemas, extensions, roles, databases and grants belong in guard/, not migrations/"; status=1
  fi
done
for d in migrations/*/; do
  dups=$(ls "$d" | grep -oE '^V[0-9]+' | sort | uniq -d || true)
  if [ -n "$dups" ]; then echo "::error::duplicate versions in $d: $dups"; status=1; fi
done
exit $status
