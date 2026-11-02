-- One non-superuser app role and its database (idempotent). psql variables: role, db, pw.
-- The role owns its database and every relation in its public schema; only it may connect.
\set ON_ERROR_STOP on
\set QUIET on

SELECT format('CREATE ROLE %I', :'role') WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD %L', :'role', :'pw') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'role') WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db') \gexec
SELECT format('ALTER DATABASE %I OWNER TO %I', :'db', :'role') \gexec
SELECT format('REVOKE CONNECT, TEMPORARY ON DATABASE %I FROM PUBLIC', :'db') \gexec
SELECT format('GRANT CONNECT, TEMPORARY ON DATABASE %I TO %I', :'db', :'role') \gexec
REVOKE CONNECT, TEMPORARY ON DATABASE postgres FROM PUBLIC;

-- Tables (their indexes and OWNED BY sequences follow), then standalone sequences and views.
\connect :db
SELECT set_config('app.role', :'role', false) \gset
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT c.oid::regclass AS o, c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm', 'S')
             AND pg_get_userbyid(c.relowner) <> current_setting('app.role')
             AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype IN ('a', 'i', 'e'))
           ORDER BY c.relkind DESC  -- 'r'/'p' before 'm'/'v' before 'S'
  LOOP
    EXECUTE format('ALTER %s %s OWNER TO %I',
      CASE r.relkind WHEN 'S' THEN 'SEQUENCE' WHEN 'v' THEN 'VIEW' WHEN 'm' THEN 'MATERIALIZED VIEW' ELSE 'TABLE' END,
      r.o, current_setting('app.role'));
  END LOOP;
END $$;
SELECT format('ALTER SCHEMA public OWNER TO %I', :'role') \gexec
