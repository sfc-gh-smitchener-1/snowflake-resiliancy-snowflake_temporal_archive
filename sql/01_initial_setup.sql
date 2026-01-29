/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - INITIAL SETUP
================================================================================

One-time setup script for the Temporal Archive infrastructure.
Run this ONCE by ACCOUNTADMIN or SECURITYADMIN to bootstrap the environment.

PREREQUISITE: ACCOUNTADMIN or SECURITYADMIN must run this script to:
    • Create the DATA_ADMIN role
    • Grant DATA_ADMIN necessary privileges
    • Create initial infrastructure

After this script, DATA_ADMIN owns all objects and can manage the archive.

Reference: https://docs.snowflake.com/en/user-guide/backups

WORM Compliance:
    • Backup Policy with RETENTION LOCK (immutable backups)
    • Daily backups retained for 7 years (2555 days)
    • Requires Business Critical Edition or higher

SCD Metadata Columns (appended to ALL archive tables):
    _LOADED_AT          TIMESTAMP_NTZ   - When record was loaded
    _SOURCE_SYSTEM      VARCHAR(100)    - Source system identifier
    _SOURCE_TABLE       VARCHAR(100)    - Original source table name
    _ROW_HASH           VARCHAR(64)     - SHA-256 hash for change detection
    _IS_CURRENT         BOOLEAN         - Current version flag
    _VALID_FROM         TIMESTAMP_NTZ   - Version start timestamp
    _VALID_TO           VARCHAR(50)     - Version end timestamp

================================================================================
*/

-- =============================================================================
-- SECTION 1: RUN AS ACCOUNTADMIN/SECURITYADMIN
-- Creates roles, database, and grants privileges to DATA_ADMIN
-- =============================================================================
USE ROLE ACCOUNTADMIN;


-- =============================================================================
-- CREATE DATA_ADMIN ROLE (Owner of all Temporal Archive objects)
-- =============================================================================

CREATE ROLE IF NOT EXISTS DATA_ADMIN
    COMMENT = 'Owner of Temporal Archive objects. Manages all archive infrastructure.';

-- Grant DATA_ADMIN to SYSADMIN for role hierarchy
GRANT ROLE DATA_ADMIN TO ROLE SYSADMIN;


-- =============================================================================
-- CREATE DATABASE (as ACCOUNTADMIN, then transfer ownership)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS TEMPORAL_ARCHIVE
    COMMENT = 'Snowflake Temporal Archive - SCD Type 2 history of Snowflake.* shares. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- CREATE WAREHOUSE (as ACCOUNTADMIN, then transfer ownership)
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS TEMPORAL_ARCHIVE_WH
    WAREHOUSE_SIZE = 'XSMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'Warehouse for Temporal Archive SCD loads. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- CREATE WORM BACKUP POLICY (requires ACCOUNTADMIN)
-- Reference: https://docs.snowflake.com/en/user-guide/backups
--
-- RETENTION LOCK ensures backups cannot be deleted by ANY user
-- Daily backups (1440 minutes) retained for 7 years (2555 days)
-- Requires Business Critical Edition or higher
-- =============================================================================

CREATE BACKUP POLICY IF NOT EXISTS TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY
    WITH RETENTION LOCK
    SCHEDULE = '1440 MINUTE'
    EXPIRE_AFTER_DAYS = 2555
    COMMENT = 'Snowflake Temporal Archive: WORM-compliant daily backups with 7-year retention. Immutable per regulatory requirements. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- APPLY BACKUP POLICY TO DATABASE
-- =============================================================================

ALTER DATABASE TEMPORAL_ARCHIVE
    SET BACKUP POLICY = TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY;


-- =============================================================================
-- GRANT OWNERSHIP TO DATA_ADMIN
-- =============================================================================

-- Transfer database ownership
GRANT OWNERSHIP ON DATABASE TEMPORAL_ARCHIVE TO ROLE DATA_ADMIN COPY CURRENT GRANTS;

-- Transfer warehouse ownership
GRANT OWNERSHIP ON WAREHOUSE TEMPORAL_ARCHIVE_WH TO ROLE DATA_ADMIN COPY CURRENT GRANTS;


-- =============================================================================
-- GRANT DATA_ADMIN ACCESS TO SNOWFLAKE.ACCOUNT_USAGE
-- Required to read source views for archiving
-- =============================================================================

GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE DATA_ADMIN;


-- =============================================================================
-- GRANT DATA_ADMIN EXECUTE TASK PRIVILEGE
-- Required to create and manage Tasks
-- =============================================================================

GRANT EXECUTE TASK ON ACCOUNT TO ROLE DATA_ADMIN;
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE DATA_ADMIN;


-- =============================================================================
-- CREATE SUBORDINATE ROLES (owned by DATA_ADMIN)
-- =============================================================================

CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_READER
    COMMENT = 'Read-only access to Temporal Archive for analysts and AI agents';

CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_WRITER
    COMMENT = 'Write access for SCD load Task execution';

CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_ADMIN
    COMMENT = 'Admin access for backup policy and maintenance';

-- Grant subordinate roles to DATA_ADMIN
GRANT ROLE TEMPORAL_ARCHIVE_READER TO ROLE DATA_ADMIN;
GRANT ROLE TEMPORAL_ARCHIVE_WRITER TO ROLE DATA_ADMIN;
GRANT ROLE TEMPORAL_ARCHIVE_ADMIN TO ROLE DATA_ADMIN;

-- Role hierarchy: WRITER includes READER, ADMIN includes WRITER
GRANT ROLE TEMPORAL_ARCHIVE_READER TO ROLE TEMPORAL_ARCHIVE_WRITER;
GRANT ROLE TEMPORAL_ARCHIVE_WRITER TO ROLE TEMPORAL_ARCHIVE_ADMIN;


-- =============================================================================
-- GRANT ALL ROLES TO USER STEVE (for demo purposes)
-- =============================================================================

GRANT ROLE DATA_ADMIN TO USER STEVE;
GRANT ROLE TEMPORAL_ARCHIVE_ADMIN TO USER STEVE;
GRANT ROLE TEMPORAL_ARCHIVE_WRITER TO USER STEVE;
GRANT ROLE TEMPORAL_ARCHIVE_READER TO USER STEVE;


-- =============================================================================
-- SECTION 2: SWITCH TO DATA_ADMIN
-- All subsequent objects will be owned by DATA_ADMIN
-- =============================================================================
USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;


-- =============================================================================
-- CREATE SCHEMAS (owned by DATA_ADMIN)
-- =============================================================================

-- Core archive schema (procedures, registry, logs)
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE
    COMMENT = 'Core archive utilities, procedures, and configuration';

-- ACCOUNT_USAGE archive
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE
    COMMENT = 'Archive of SNOWFLAKE.ACCOUNT_USAGE views';

-- ORGANIZATION_USAGE archive
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ORGANIZATION_USAGE
    COMMENT = 'Archive of SNOWFLAKE.ORGANIZATION_USAGE views';

-- DATA_SHARING_USAGE archive
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.DATA_SHARING_USAGE
    COMMENT = 'Archive of SNOWFLAKE.DATA_SHARING_USAGE views';

-- READER_ACCOUNT_USAGE archive
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.READER_ACCOUNT_USAGE
    COMMENT = 'Archive of SNOWFLAKE.READER_ACCOUNT_USAGE views';


-- =============================================================================
-- CREATE LOGGING TABLE (owned by DATA_ADMIN)
-- =============================================================================

CREATE TABLE IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG (
    LOG_ID              NUMBER AUTOINCREMENT,
    LOAD_TIMESTAMP      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_TABLE        VARCHAR(256),
    TARGET_TABLE        VARCHAR(256),
    ROWS_UPDATED        NUMBER,
    ROWS_INSERTED       NUMBER,
    STATUS              VARCHAR(50),
    ERROR_MESSAGE       VARCHAR(16777216),
    DURATION_SECONDS    NUMBER(10,2),
    
    -- SCD Metadata Columns (REQUIRED for ALL tables)
    "_LOADED_AT"        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_SOURCE_SYSTEM"    VARCHAR(100) DEFAULT 'TEMPORAL_ARCHIVE',
    "_SOURCE_TABLE"     VARCHAR(100) DEFAULT 'LOAD_LOG',
    "_ROW_HASH"         VARCHAR(64),
    "_IS_CURRENT"       BOOLEAN DEFAULT TRUE,
    "_VALID_FROM"       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_VALID_TO"         VARCHAR(50) DEFAULT '9999-12-31 23:59:59'
)
COMMENT = 'Audit log of all SCD load operations. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- GRANT PERMISSIONS TO SUBORDINATE ROLES
-- =============================================================================

-- Reader permissions
GRANT USAGE ON DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT SELECT ON ALL TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT SELECT ON FUTURE TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT USAGE ON WAREHOUSE TEMPORAL_ARCHIVE_WH TO ROLE TEMPORAL_ARCHIVE_READER;

-- Writer permissions (inherits READER via role hierarchy)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_WRITER;
GRANT SELECT, INSERT, UPDATE ON FUTURE TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_WRITER;

-- Admin permissions (inherits WRITER via role hierarchy)
GRANT ALL ON ALL SCHEMAS IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_ADMIN;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_ADMIN;


-- =============================================================================
-- VERIFICATION
-- =============================================================================

-- Verify database setup
SHOW DATABASES LIKE 'TEMPORAL_ARCHIVE%';

-- Verify schemas
SHOW SCHEMAS IN DATABASE TEMPORAL_ARCHIVE;

-- Verify warehouse
SHOW WAREHOUSES LIKE 'TEMPORAL_ARCHIVE%';

-- Verify backup policy
DESCRIBE BACKUP POLICY TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY;

-- Verify current role
SELECT CURRENT_ROLE() AS CURRENT_ROLE, 'DATA_ADMIN should own all objects' AS NOTE;

SELECT '01_initial_setup.sql completed successfully' AS STATUS;


-- =============================================================================
-- SETUP SUMMARY
-- =============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    TEMPORAL ARCHIVE - INITIAL SETUP COMPLETE                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   OWNER ROLE:       DATA_ADMIN (owns all objects)                               │
│                                                                                 │
│   DATABASE:         TEMPORAL_ARCHIVE                                            │
│                                                                                 │
│   SCHEMAS:          ARCHIVE            (procedures, config, logs)               │
│                     ACCOUNT_USAGE      (Snowflake.ACCOUNT_USAGE archive)        │
│                     ORGANIZATION_USAGE (Snowflake.ORGANIZATION_USAGE archive)   │
│                     DATA_SHARING_USAGE (Snowflake.DATA_SHARING_USAGE archive)   │
│                     READER_ACCOUNT_USAGE                                        │
│                                                                                 │
│   WAREHOUSE:        TEMPORAL_ARCHIVE_WH (XSMALL, auto-suspend 60s)              │
│                                                                                 │
│   BACKUP POLICY:    TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY                         │
│                     • WITH RETENTION LOCK (immutable)                           │
│                     • SCHEDULE: Daily (1440 minutes)                            │
│                     • RETENTION: 7 years (2555 days)                            │
│                     • Requires Business Critical Edition                        │
│                                                                                 │
│   SUBORDINATE       TEMPORAL_ARCHIVE_READER  (SELECT only)                      │
│   ROLES:            TEMPORAL_ARCHIVE_WRITER  (SCD load operations)              │
│                     TEMPORAL_ARCHIVE_ADMIN   (Full access)                      │
│                                                                                 │
│   DATA_ADMIN        • Owns TEMPORAL_ARCHIVE database                            │
│   PRIVILEGES:       • Owns TEMPORAL_ARCHIVE_WH warehouse                        │
│                     • IMPORTED PRIVILEGES on SNOWFLAKE database                 │
│                     • EXECUTE TASK on account                                   │
│                                                                                 │
│   USER GRANTS:      User STEVE granted all roles for demo                       │
│                                                                                 │
│   Reference: https://docs.snowflake.com/en/user-guide/backups                   │
└─────────────────────────────────────────────────────────────────────────────────┘
*/
