-- Privileges
--

REVOKE CREATE on SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE "{{db_name}}" FROM PUBLIC;

-- create cap schema (pub/sub)
CREATE SCHEMA cap;

---
GRANT CREATE, CONNECT, TEMPORARY ON DATABASE "{{db_name}}" TO {{db_username}};

-- readwrite in public schema
GRANT USAGE, CREATE ON SCHEMA public TO {{db_username}};
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO {{db_username}};
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO {{db_username}};
ALTER DEFAULT PRIVILEGES FOR ROLE {{db_admin_username}} IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {{db_username}};
ALTER DEFAULT PRIVILEGES FOR ROLE {{db_admin_username}} IN SCHEMA public GRANT USAGE ON SEQUENCES TO {{db_username}};

-- readwrite in cap schema
GRANT USAGE, CREATE ON SCHEMA cap TO {{db_username}};
GRANT ALL ON ALL TABLES IN SCHEMA cap TO {{db_username}};
GRANT ALL ON ALL SEQUENCES IN SCHEMA cap TO {{db_username}};
ALTER DEFAULT PRIVILEGES FOR ROLE {{db_admin_username}} IN SCHEMA cap GRANT ALL ON TABLES TO {{db_username}};
ALTER DEFAULT PRIVILEGES FOR ROLE {{db_admin_username}} IN SCHEMA cap GRANT ALL ON SEQUENCES TO {{db_username}};

---
GRANT CREATE, CONNECT ON DATABASE "{{db_name}}" TO {{db_admin_username}};

-- readwrite in public schema
GRANT ALL ON SCHEMA public TO {{db_admin_username}};
GRANT ALL ON ALL TABLES IN SCHEMA public TO {{db_admin_username}};
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO {{db_admin_username}};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO {{db_admin_username}};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO {{db_admin_username}};

-- readwrite in cap schema
GRANT ALL ON SCHEMA cap TO {{db_admin_username}};
GRANT ALL ON ALL TABLES IN SCHEMA cap TO {{db_admin_username}};
GRANT ALL ON ALL SEQUENCES IN SCHEMA cap TO {{db_admin_username}};
ALTER DEFAULT PRIVILEGES IN SCHEMA cap GRANT ALL ON TABLES TO {{db_admin_username}};
ALTER DEFAULT PRIVILEGES IN SCHEMA cap GRANT ALL ON SEQUENCES TO {{db_admin_username}};
