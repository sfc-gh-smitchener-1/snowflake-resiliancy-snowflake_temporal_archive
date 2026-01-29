/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - INITIAL SETUP
================================================================================

One-time setup script for the Temporal Archive infrastructure.
Run this before the first SCD load.

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
    Id                  VARCHAR(18)     - Primary identifier
    IsDeleted           BOOLEAN         - Soft delete flag
    CreatedDate         VARCHAR(50)     - Original creation timestamp
    CreatedById         VARCHAR(18)     - Creator user ID
    LastModifiedDate    VARCHAR(50)     - Last modification timestamp
    LastModifiedById    VARCHAR(18)     - Last modifier user ID
    SystemModstamp      VARCHAR(50)     - System modification timestamp

================================================================================
*/

-- =============================================================================
-- USE ACCOUNTADMIN ROLE
-- =============================================================================
USE ROLE ACCOUNTADMIN;


-- =============================================================================
-- CREATE DATABASE
-- =============================================================================

-- Main archive database for SCD Type 2 tables
CREATE DATABASE IF NOT EXISTS TEMPORAL_ARCHIVE
    COMMENT = 'Snowflake Temporal Archive - SCD Type 2 history of Snowflake.* shares. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- CREATE SCHEMAS (mirror Snowflake.* structure)
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
-- CREATE WAREHOUSE
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
-- CREATE WORM BACKUP POLICY
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
-- CREATE ROLES (for access control)
-- =============================================================================

-- Read-only role for analysts and research
CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_READER
    COMMENT = 'Read-only access to Temporal Archive for analysts and AI agents';

-- Write role for SCD load processes
CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_WRITER
    COMMENT = 'Write access for SCD load Task execution';

-- Admin role for configuration and maintenance
CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_ADMIN
    COMMENT = 'Admin access for backup policy and maintenance';


-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

-- Reader permissions
GRANT USAGE ON DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT SELECT ON ALL TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT SELECT ON FUTURE TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;

-- Writer permissions
GRANT USAGE ON DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_WRITER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_WRITER;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_WRITER;
GRANT SELECT, INSERT, UPDATE ON FUTURE TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_WRITER;
GRANT USAGE ON WAREHOUSE TEMPORAL_ARCHIVE_WH TO ROLE TEMPORAL_ARCHIVE_WRITER;

-- Admin permissions
GRANT ALL ON DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_ADMIN;
GRANT ALL ON WAREHOUSE TEMPORAL_ARCHIVE_WH TO ROLE TEMPORAL_ARCHIVE_ADMIN;


-- =============================================================================
-- CREATE LOGGING TABLE
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
    "_VALID_TO"         VARCHAR(50) DEFAULT '9999-12-31 23:59:59',
    "Id"                VARCHAR(18),
    "IsDeleted"         BOOLEAN DEFAULT FALSE,
    "CreatedDate"       VARCHAR(50),
    "CreatedById"       VARCHAR(18),
    "LastModifiedDate"  VARCHAR(50),
    "LastModifiedById"  VARCHAR(18),
    "SystemModstamp"    VARCHAR(50)
)
COMMENT = 'Audit log of all SCD load operations. Ref: https://docs.snowflake.com/en/user-guide/backups';


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

-- Confirm policy is applied
SHOW DATABASES LIKE 'TEMPORAL_ARCHIVE';

SELECT 'Setup complete. WORM backup policy applied. Ready for SCD loads.' AS STATUS;


-- =============================================================================
-- SETUP SUMMARY
-- =============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    TEMPORAL ARCHIVE - INITIAL SETUP COMPLETE                    │
├─────────────────────────────────────────────────────────────────────────────────┤
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
│   ROLES:            TEMPORAL_ARCHIVE_READER  (SELECT only)                      │
│                     TEMPORAL_ARCHIVE_WRITER  (SCD load operations)              │
│                     TEMPORAL_ARCHIVE_ADMIN   (Full access)                      │
│                                                                                 │
│   Reference: https://docs.snowflake.com/en/user-guide/backups                   │
└─────────────────────────────────────────────────────────────────────────────────┘
*/
