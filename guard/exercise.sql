do $$
begin
  if current_user <> 'exercise_migrator' then
    raise exception 'guard/exercise.sql must run as exercise_migrator, not %', current_user;
  end if;
end $$;

create schema if not exists exercise;

do $$
begin
  if (select nspowner::regrole::text from pg_namespace where nspname = 'exercise') <> 'exercise_migrator' then
    raise exception 'schema exercise exists but is not owned by exercise_migrator';
  end if;
end $$;

revoke all on schema exercise from public;
grant usage on schema exercise to exercise_app;
grant select, insert, update, delete on all tables in schema exercise to exercise_app;
grant usage, select on all sequences in schema exercise to exercise_app;
alter default privileges in schema exercise grant select, insert, update, delete on tables to exercise_app;
alter default privileges in schema exercise grant usage, select on sequences to exercise_app;

-- F2: the app role may read, never write, its Flyway history.
do $$
begin
  if to_regclass('exercise.flyway_schema_history') is not null then
    execute 'revoke insert, update, delete, truncate on exercise.flyway_schema_history from exercise_app';
    execute 'grant select on exercise.flyway_schema_history to exercise_app';
  end if;
end $$;
