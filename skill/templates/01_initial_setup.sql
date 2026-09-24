/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - INITIAL SETUP (PARAMETERIZED)
================================================================================

One-time setup script for the Temporal Archive infrastructure.
This is a parameterized template - replace {{VARIABLE}} placeholders.

Reference: https://docs.snowflake.com/en/user-guide/backups
================================================================================
*/

-- =============================================================================
-- RUN AS ACCOUNTADMIN
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- CREATE ADMIN ROLE (Owner of all Temporal Archive objects)
-- =============================================================================

CREATE ROLE IF NOT EXISTS {{ADMIN_ROLE}}
    COMMENT = 'Owner of Temporal Archive objects. Manages all archive infrastructure.';

GRANT ROLE {{ADMIN_ROLE}} TO ROLE SYSADMIN;


-- =============================================================================
-- CREATE DATABASE
-- =============================================================================

CREATE DATABASE IF NOT EXISTS {{DATABASE_NAME}}
    COMMENT = 'Snowflake Temporal Archive - SCD Type 2 history of Snowflake.* shares. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- CREATE WAREHOUSE
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS {{WAREHOUSE_NAME}}
    WAREHOUSE_SIZE = '{{WAREHOUSE_SIZE}}'
    WAREHOUSE_TYPE = 'STANDARD'
    GENERATION = '2'
    AUTO_SUSPEND = {{WAREHOUSE_AUTO_SUSPEND}}
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = {{WAREHOUSE_MIN_CLUSTERS}}
    MAX_CLUSTER_COUNT = {{WAREHOUSE_MAX_CLUSTERS}}
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'Warehouse for Temporal Archive SCD loads. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- CREATE SCHEMAS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS {{DATABASE_NAME}}.{{ARCHIVE_SCHEMA}}
    COMMENT = 'Core archive utilities, procedures, and configuration';

CREATE SCHEMA IF NOT EXISTS {{DATABASE_NAME}}.{{ACCOUNT_USAGE_SCHEMA}}
    COMMENT = 'Archive of SNOWFLAKE.ACCOUNT_USAGE views';

CREATE SCHEMA IF NOT EXISTS {{DATABASE_NAME}}.{{ORGANIZATION_USAGE_SCHEMA}}
    COMMENT = 'Archive of SNOWFLAKE.ORGANIZATION_USAGE views';

CREATE SCHEMA IF NOT EXISTS {{DATABASE_NAME}}.{{DATA_SHARING_SCHEMA}}
    COMMENT = 'Archive of SNOWFLAKE.DATA_SHARING_USAGE views';

CREATE SCHEMA IF NOT EXISTS {{DATABASE_NAME}}.{{READER_ACCOUNT_SCHEMA}}
    COMMENT = 'Archive of SNOWFLAKE.READER_ACCOUNT_USAGE views';

CREATE SCHEMA IF NOT EXISTS {{DATABASE_NAME}}.{{SEMANTIC_SCHEMA}}
    COMMENT = 'Semantic views and Cortex Agent for AI-powered account analysis';

CREATE SCHEMA IF NOT EXISTS {{DATABASE_NAME}}.{{STREAMLIT_SCHEMA}}
    COMMENT = 'Streamlit application and supporting objects';


-- =============================================================================
-- GRANT OWNERSHIP TO ADMIN ROLE
-- =============================================================================

GRANT OWNERSHIP ON DATABASE {{DATABASE_NAME}} TO ROLE {{ADMIN_ROLE}} COPY CURRENT GRANTS;

GRANT OWNERSHIP ON WAREHOUSE {{WAREHOUSE_NAME}} TO ROLE {{ADMIN_ROLE}} COPY CURRENT GRANTS;


-- =============================================================================
-- GRANT ADMIN ROLE ACCESS TO SNOWFLAKE.ACCOUNT_USAGE
-- =============================================================================

GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE {{ADMIN_ROLE}};


-- =============================================================================
-- GRANT ADMIN ROLE EXECUTE TASK PRIVILEGE
-- =============================================================================

GRANT EXECUTE TASK ON ACCOUNT TO ROLE {{ADMIN_ROLE}};

GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE {{ADMIN_ROLE}};

GRANT CREATE AGENT ON SCHEMA {{DATABASE_NAME}}.{{SEMANTIC_SCHEMA}} TO ROLE {{ADMIN_ROLE}};


-- =============================================================================
-- CREATE SUBORDINATE ROLES
-- =============================================================================

CREATE ROLE IF NOT EXISTS {{READER_ROLE}}
    COMMENT = 'Read-only access to Temporal Archive for analysts and AI agents';

CREATE ROLE IF NOT EXISTS {{WRITER_ROLE}}
    COMMENT = 'Write access for SCD load Task execution';

CREATE ROLE IF NOT EXISTS {{ARCHIVE_ADMIN_ROLE}}
    COMMENT = 'Admin access for backup policy and maintenance';

GRANT ROLE {{READER_ROLE}} TO ROLE {{ADMIN_ROLE}};

GRANT ROLE {{WRITER_ROLE}} TO ROLE {{ADMIN_ROLE}};

GRANT ROLE {{ARCHIVE_ADMIN_ROLE}} TO ROLE {{ADMIN_ROLE}};

GRANT ROLE {{READER_ROLE}} TO ROLE {{WRITER_ROLE}};

GRANT ROLE {{WRITER_ROLE}} TO ROLE {{ARCHIVE_ADMIN_ROLE}};


-- =============================================================================
-- GRANT ROLES TO USERS (Configure as needed)
-- =============================================================================
-- Uncomment and replace <YOUR_USERNAME> with the actual username(s) who need access.
-- Example: GRANT ROLE {{ADMIN_ROLE}} TO USER JOHN_DOE;
-- =============================================================================

-- GRANT ROLE {{ADMIN_ROLE}} TO USER <YOUR_USERNAME>;
-- GRANT ROLE {{ARCHIVE_ADMIN_ROLE}} TO USER <YOUR_USERNAME>;
-- GRANT ROLE {{WRITER_ROLE}} TO USER <YOUR_USERNAME>;
-- GRANT ROLE {{READER_ROLE}} TO USER <YOUR_USERNAME>;


-- =============================================================================
-- NOTE: LOAD_LOG is created by 02_scd_load.sql (run as {{ADMIN_ROLE}}), not here.
-- Keeping it in a single place avoids inconsistent schemas for the same table.
-- =============================================================================


-- =============================================================================
-- GRANT PERMISSIONS TO SUBORDINATE ROLES
-- =============================================================================

GRANT USAGE ON DATABASE {{DATABASE_NAME}} TO ROLE {{READER_ROLE}};

GRANT USAGE ON ALL SCHEMAS IN DATABASE {{DATABASE_NAME}} TO ROLE {{READER_ROLE}};

GRANT SELECT ON ALL TABLES IN DATABASE {{DATABASE_NAME}} TO ROLE {{READER_ROLE}};

GRANT SELECT ON FUTURE TABLES IN DATABASE {{DATABASE_NAME}} TO ROLE {{READER_ROLE}};

GRANT USAGE ON WAREHOUSE {{WAREHOUSE_NAME}} TO ROLE {{READER_ROLE}};

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN DATABASE {{DATABASE_NAME}} TO ROLE {{WRITER_ROLE}};

GRANT SELECT, INSERT, UPDATE ON FUTURE TABLES IN DATABASE {{DATABASE_NAME}} TO ROLE {{WRITER_ROLE}};

GRANT ALL ON ALL SCHEMAS IN DATABASE {{DATABASE_NAME}} TO ROLE {{ARCHIVE_ADMIN_ROLE}};

GRANT ALL ON FUTURE SCHEMAS IN DATABASE {{DATABASE_NAME}} TO ROLE {{ARCHIVE_ADMIN_ROLE}};

-- Grant semantic view access
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA {{DATABASE_NAME}}.{{SEMANTIC_SCHEMA}} TO ROLE {{READER_ROLE}};

GRANT SELECT ON FUTURE SEMANTIC VIEWS IN SCHEMA {{DATABASE_NAME}}.{{SEMANTIC_SCHEMA}} TO ROLE {{READER_ROLE}};


-- =============================================================================
-- WORM BACKUP POLICY - NOT CREATED BY THIS SCRIPT
-- =============================================================================
-- The retention-locked WORM backup policy is OPTIONAL and is never created
-- automatically (features.create_backup_policy must be explicitly set to true,
-- and even then only in the manual 01b_backup_policy.sql script). Once a
-- scheduled backup has run, the retention-locked backup set CANNOT be
-- deleted - even by ACCOUNTADMIN - until every backup expires
-- ({{BACKUP_RETENTION_DAYS}} days with the default policy). See 06_cleanup.sql.
--
-- To enable it, run 01b_backup_policy.sql MANUALLY after this script.

-- =============================================================================
-- VERIFICATION
-- =============================================================================

SELECT '{{DATABASE_NAME}} setup complete. Next: Run 02_scd_load.sql as {{ADMIN_ROLE}}' AS STATUS;
