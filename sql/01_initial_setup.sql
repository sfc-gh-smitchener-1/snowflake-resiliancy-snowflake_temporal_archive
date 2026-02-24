/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - INITIAL SETUP
================================================================================

One-time setup script for the Temporal Archive infrastructure.
Run this script in a Snowflake Worksheet.

Reference: https://docs.snowflake.com/en/user-guide/backups
================================================================================
*/

-- =============================================================================
-- RUN AS ACCOUNTADMIN
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- CREATE DATA_ADMIN ROLE (Owner of all Temporal Archive objects)
-- =============================================================================

CREATE ROLE IF NOT EXISTS DATA_ADMIN
    COMMENT = 'Owner of Temporal Archive objects. Manages all archive infrastructure.';

GRANT ROLE DATA_ADMIN TO ROLE SYSADMIN;


-- =============================================================================
-- CREATE DATABASE
-- =============================================================================

CREATE DATABASE IF NOT EXISTS TEMPORAL_ARCHIVE
    COMMENT = 'Snowflake Temporal Archive - SCD Type 2 history of Snowflake.* shares. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- CREATE WAREHOUSE
-- =============================================================================

CREATE WAREHOUSE IF NOT EXISTS TEMPORAL_ARCHIVE_WH
    WAREHOUSE_SIZE = 'LARGE'
    WAREHOUSE_TYPE = 'STANDARD'
    GENERATION = '2'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'Warehouse for Temporal Archive SCD loads. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- CREATE SCHEMAS
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE
    COMMENT = 'Core archive utilities, procedures, and configuration';

CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE
    COMMENT = 'Archive of SNOWFLAKE.ACCOUNT_USAGE views';

CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ORGANIZATION_USAGE
    COMMENT = 'Archive of SNOWFLAKE.ORGANIZATION_USAGE views';

CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.DATA_SHARING_USAGE
    COMMENT = 'Archive of SNOWFLAKE.DATA_SHARING_USAGE views';

CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.READER_ACCOUNT_USAGE
    COMMENT = 'Archive of SNOWFLAKE.READER_ACCOUNT_USAGE views';


-- =============================================================================
-- GRANT OWNERSHIP TO DATA_ADMIN
-- =============================================================================

GRANT OWNERSHIP ON DATABASE TEMPORAL_ARCHIVE TO ROLE DATA_ADMIN COPY CURRENT GRANTS;

GRANT OWNERSHIP ON WAREHOUSE TEMPORAL_ARCHIVE_WH TO ROLE DATA_ADMIN COPY CURRENT GRANTS;


-- =============================================================================
-- GRANT DATA_ADMIN ACCESS TO SNOWFLAKE.ACCOUNT_USAGE
-- =============================================================================

GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE DATA_ADMIN;


-- =============================================================================
-- GRANT DATA_ADMIN EXECUTE TASK PRIVILEGE
-- =============================================================================

GRANT EXECUTE TASK ON ACCOUNT TO ROLE DATA_ADMIN;

GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE DATA_ADMIN;


-- =============================================================================
-- CREATE SUBORDINATE ROLES
-- =============================================================================

CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_READER
    COMMENT = 'Read-only access to Temporal Archive for analysts and AI agents';

CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_WRITER
    COMMENT = 'Write access for SCD load Task execution';

CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_ADMIN
    COMMENT = 'Admin access for backup policy and maintenance';

GRANT ROLE TEMPORAL_ARCHIVE_READER TO ROLE DATA_ADMIN;

GRANT ROLE TEMPORAL_ARCHIVE_WRITER TO ROLE DATA_ADMIN;

GRANT ROLE TEMPORAL_ARCHIVE_ADMIN TO ROLE DATA_ADMIN;

GRANT ROLE TEMPORAL_ARCHIVE_READER TO ROLE TEMPORAL_ARCHIVE_WRITER;

GRANT ROLE TEMPORAL_ARCHIVE_WRITER TO ROLE TEMPORAL_ARCHIVE_ADMIN;


-- =============================================================================
-- GRANT ROLES TO USERS (Configure as needed)
-- =============================================================================
-- Uncomment and replace <YOUR_USERNAME> with the actual username(s) who need access.
-- Example: GRANT ROLE DATA_ADMIN TO USER JOHN_DOE;
-- =============================================================================

-- GRANT ROLE DATA_ADMIN TO USER <YOUR_USERNAME>;
-- GRANT ROLE TEMPORAL_ARCHIVE_ADMIN TO USER <YOUR_USERNAME>;
-- GRANT ROLE TEMPORAL_ARCHIVE_WRITER TO USER <YOUR_USERNAME>;
-- GRANT ROLE TEMPORAL_ARCHIVE_READER TO USER <YOUR_USERNAME>;


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

GRANT USAGE ON DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;

GRANT USAGE ON ALL SCHEMAS IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;

GRANT SELECT ON ALL TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;

GRANT SELECT ON FUTURE TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;

GRANT USAGE ON WAREHOUSE TEMPORAL_ARCHIVE_WH TO ROLE TEMPORAL_ARCHIVE_READER;

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_WRITER;

GRANT SELECT, INSERT, UPDATE ON FUTURE TABLES IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_WRITER;

GRANT ALL ON ALL SCHEMAS IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_ADMIN;

GRANT ALL ON FUTURE SCHEMAS IN DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_ADMIN;


-- =============================================================================
-- CREATE BACKUP POLICY (REQUIRES BUSINESS CRITICAL EDITION)
-- =============================================================================
-- WORM-compliant backup policy with 7-year retention
-- Note: RETENTION LOCK requires Business Critical Edition or higher
-- Reference: https://docs.snowflake.com/en/user-guide/backups
-- =============================================================================

CREATE BACKUP POLICY IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE.TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY
    WITH RETENTION LOCK
    SCHEDULE = '1440 MINUTE'
    EXPIRE_AFTER_DAYS = 2555
    COMMENT = 'WORM-compliant backup policy with 7-year retention for SEC 17a-4, HIPAA, FINRA compliance';

-- Apply backup policy to database
ALTER DATABASE TEMPORAL_ARCHIVE 
    SET BACKUP_POLICY = TEMPORAL_ARCHIVE.ARCHIVE.TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY;


-- =============================================================================
-- VERIFICATION
-- =============================================================================

SELECT 'TEMPORAL_ARCHIVE setup complete. Next: Run 02_scd_load_procedure.sql as DATA_ADMIN' AS STATUS;
