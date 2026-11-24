ARG PG_VERSION=18.7
FROM postgres:${PG_VERSION}-bookworm
# resolves to postgres:18.7-bookworm (verified on Docker Hub 2026-11-23)
LABEL org.opencontainers.image.source="https://github.com/ExperienceQuality/xq-db"
LABEL org.opencontainers.image.description="TEST ONLY: Postgres with xq roles and schemas routine + exercise fully migrated"
ENV POSTGRES_DB=xq
COPY initdb/ /docker-entrypoint-initdb.d/
