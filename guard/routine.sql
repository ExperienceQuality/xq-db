do $$
begin
  if current_user <> 'routine_migrator' then
    raise exception 'guard/routine.sql must run as routine_migrator, not %', current_user;
  end if;
end $$;

create schema if not exists routine;

do $$
begin
  if (select nspowner::regrole::text from pg_namespace where nspname = 'routine') <> 'routine_migrator' then
    raise exception 'schema routine exists but is not owned by routine_migrator';
  end if;
end $$;

revoke all on schema routine from public;
grant usage on schema routine to routine_app;
grant select, insert, update, delete on all tables in schema routine to routine_app;
grant usage, select on all sequences in schema routine to routine_app;
alter default privileges in schema routine grant select, insert, update, delete on tables to routine_app;
alter default privileges in schema routine grant usage, select on sequences to routine_app;

-- F2: the app role may read, never write, its Flyway history.
do $$
begin
  if to_regclass('routine.flyway_schema_history') is not null then
    execute 'revoke insert, update, delete, truncate on routine.flyway_schema_history from routine_app';
    execute 'grant select on routine.flyway_schema_history to routine_app';
  end if;
end $$;
