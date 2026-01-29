-- ============================================================================
-- SNOWFLAKE TEMPORAL ARCHIVE - SEMANTIC LAYER
-- ============================================================================
-- 
-- Semantic Views for Cortex Analyst - Natural language queries on ACCOUNT_USAGE
-- 
-- This script uses a metadata-driven approach to build semantic views:
--   1. SEMANTIC_CONFIG table stores all view definitions
--   2. BUILD_SEMANTIC_LAYER procedure reads config and creates views
--   3. Adding new views = inserting rows, not editing SQL
--
-- Reference: https://docs.snowflake.com/en/user-guide/backups
--
-- RUN AS: DATA_ADMIN (owner of all Temporal Archive objects)
-- ============================================================================

USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

-- ═══════════════════════════════════════════════════════════════════════════
-- CREATE SEMANTIC SCHEMA
-- ═══════════════════════════════════════════════════════════════════════════

CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.SEMANTIC
    COMMENT = 'Semantic views for Cortex Analyst. Ref: https://docs.snowflake.com/en/user-guide/backups';

USE SCHEMA TEMPORAL_ARCHIVE.SEMANTIC;


-- ═══════════════════════════════════════════════════════════════════════════
-- SEMANTIC CONFIGURATION TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS TEMPORAL_ARCHIVE.SEMANTIC.SEMANTIC_CONFIG (
    CONFIG_ID               NUMBER AUTOINCREMENT PRIMARY KEY,
    SOURCE_SCHEMA           VARCHAR(100) NOT NULL,
    VIEW_NAME               VARCHAR(100) NOT NULL,
    VIEW_TYPE               VARCHAR(30) DEFAULT 'SEMANTIC_VIEW',
    VIEW_SQL                VARCHAR(32000) NOT NULL,
    VIEW_COMMENT            VARCHAR(1000),
    IS_ACTIVE               BOOLEAN DEFAULT TRUE,
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- SCD Metadata Columns
    "_LOADED_AT"            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_SOURCE_SYSTEM"        VARCHAR(100) DEFAULT 'TEMPORAL_ARCHIVE',
    "_SOURCE_TABLE"         VARCHAR(100) DEFAULT 'SEMANTIC_CONFIG',
    "_ROW_HASH"             VARCHAR(64),
    "_IS_CURRENT"           BOOLEAN DEFAULT TRUE,
    "_VALID_FROM"           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_VALID_TO"             VARCHAR(50) DEFAULT '9999-12-31 23:59:59',
    
    CONSTRAINT UK_SEMANTIC_CONFIG UNIQUE (SOURCE_SCHEMA, VIEW_NAME)
)
COMMENT = 'Semantic view configuration for Cortex Analyst. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- ═══════════════════════════════════════════════════════════════════════════
-- ACCOUNT_USAGE SEMANTIC VIEWS
-- ═══════════════════════════════════════════════════════════════════════════

-- Clear existing config for rebuild
DELETE FROM TEMPORAL_ARCHIVE.SEMANTIC.SEMANTIC_CONFIG WHERE SOURCE_SCHEMA = 'ACCOUNT_USAGE';

INSERT INTO TEMPORAL_ARCHIVE.SEMANTIC.SEMANTIC_CONFIG 
    (SOURCE_SCHEMA, VIEW_NAME, VIEW_TYPE, VIEW_SQL, VIEW_COMMENT)
VALUES

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY_COST_ANALYTICS - Warehouse and query cost analysis
-- ─────────────────────────────────────────────────────────────────────────────
('ACCOUNT_USAGE', 'QUERY_COST_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.QUERY_COST_ANALYTICS
  TABLES (
    queries AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE PRIMARY KEY (QUERY_ID)
  )
  DIMENSIONS (
    queries.QUERY_ID AS query_id,
    queries.USER_NAME AS user_name,
    queries.ROLE_NAME AS role_name,
    queries.WAREHOUSE_NAME AS warehouse_name,
    queries.WAREHOUSE_SIZE AS warehouse_size,
    queries.DATABASE_NAME AS database_name,
    queries.SCHEMA_NAME AS schema_name,
    queries.QUERY_TYPE AS query_type,
    queries.EXECUTION_STATUS AS execution_status,
    queries.START_TIME AS start_time,
    queries.END_TIME AS end_time
  )
  METRICS (
    queries.total_elapsed_ms AS SUM(queries.TOTAL_ELAPSED_TIME),
    queries.query_count AS COUNT(queries.QUERY_ID),
    queries.avg_elapsed_ms AS AVG(queries.TOTAL_ELAPSED_TIME),
    queries.bytes_scanned AS SUM(queries.BYTES_SCANNED),
    queries.rows_produced AS SUM(queries.ROWS_PRODUCED)
  )
  COMMENT = ''Query cost and performance analytics - Historical analysis across years''
', 'Query cost analysis for optimization and chargeback'),

-- ─────────────────────────────────────────────────────────────────────────────
-- WAREHOUSE_USAGE_ANALYTICS - Warehouse metering and utilization
-- ─────────────────────────────────────────────────────────────────────────────
('ACCOUNT_USAGE', 'WAREHOUSE_USAGE_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.WAREHOUSE_USAGE_ANALYTICS
  TABLES (
    metering AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE PRIMARY KEY (START_TIME, WAREHOUSE_ID)
  )
  DIMENSIONS (
    metering.WAREHOUSE_NAME AS warehouse_name,
    metering.WAREHOUSE_ID AS warehouse_id,
    metering.START_TIME AS start_time,
    metering.END_TIME AS end_time
  )
  METRICS (
    metering.credits_used AS SUM(metering.CREDITS_USED),
    metering.credits_compute AS SUM(metering.CREDITS_USED_COMPUTE),
    metering.credits_cloud_services AS SUM(metering.CREDITS_USED_CLOUD_SERVICES),
    metering.measurement_count AS COUNT(*)
  )
  COMMENT = ''Warehouse credit usage and cost analysis - Multi-year trends''
', 'Warehouse credit consumption for cost optimization'),

-- ─────────────────────────────────────────────────────────────────────────────
-- STORAGE_ANALYTICS - Storage usage and growth trends
-- ─────────────────────────────────────────────────────────────────────────────
('ACCOUNT_USAGE', 'STORAGE_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.STORAGE_ANALYTICS
  TABLES (
    storage AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.STORAGE_USAGE_ARCHIVE PRIMARY KEY (USAGE_DATE)
  )
  DIMENSIONS (
    storage.USAGE_DATE AS usage_date
  )
  METRICS (
    storage.database_bytes AS SUM(storage.AVERAGE_DATABASE_BYTES),
    storage.stage_bytes AS SUM(storage.AVERAGE_STAGE_BYTES),
    storage.failsafe_bytes AS SUM(storage.AVERAGE_FAILSAFE_BYTES),
    storage.total_bytes AS SUM(storage.AVERAGE_DATABASE_BYTES + storage.AVERAGE_STAGE_BYTES + storage.AVERAGE_FAILSAFE_BYTES)
  )
  COMMENT = ''Storage usage analytics - Historical growth and capacity planning''
', 'Storage consumption for capacity planning'),

-- ─────────────────────────────────────────────────────────────────────────────
-- LOGIN_SECURITY_ANALYTICS - Login patterns and security analysis
-- ─────────────────────────────────────────────────────────────────────────────
('ACCOUNT_USAGE', 'LOGIN_SECURITY_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.LOGIN_SECURITY_ANALYTICS
  TABLES (
    logins AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE PRIMARY KEY (EVENT_ID)
  )
  DIMENSIONS (
    logins.EVENT_ID AS event_id,
    logins.EVENT_TIMESTAMP AS event_timestamp,
    logins.USER_NAME AS user_name,
    logins.CLIENT_IP AS client_ip,
    logins.REPORTED_CLIENT_TYPE AS client_type,
    logins.FIRST_AUTHENTICATION_FACTOR AS first_auth_factor,
    logins.SECOND_AUTHENTICATION_FACTOR AS second_auth_factor,
    logins.IS_SUCCESS AS is_success,
    logins.ERROR_CODE AS error_code,
    logins.ERROR_MESSAGE AS error_message
  )
  METRICS (
    logins.login_count AS COUNT(logins.EVENT_ID),
    logins.success_count AS SUM(CASE WHEN logins.IS_SUCCESS = ''YES'' THEN 1 ELSE 0 END),
    logins.failure_count AS SUM(CASE WHEN logins.IS_SUCCESS = ''NO'' THEN 1 ELSE 0 END),
    logins.unique_users AS COUNT(DISTINCT logins.USER_NAME),
    logins.unique_ips AS COUNT(DISTINCT logins.CLIENT_IP)
  )
  COMMENT = ''Login security analytics - Authentication patterns and threat detection''
', 'Login history for security auditing and compliance'),

-- ─────────────────────────────────────────────────────────────────────────────
-- USER_ANALYTICS - User activity and lifecycle
-- ─────────────────────────────────────────────────────────────────────────────
('ACCOUNT_USAGE', 'USER_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.USER_ANALYTICS
  TABLES (
    users AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE PRIMARY KEY (USER_ID)
  )
  DIMENSIONS (
    users.USER_ID AS user_id,
    users.NAME AS user_name,
    users.LOGIN_NAME AS login_name,
    users.DISPLAY_NAME AS display_name,
    users.EMAIL AS email,
    users.DEFAULT_WAREHOUSE AS default_warehouse,
    users.DEFAULT_ROLE AS default_role,
    users.CREATED_ON AS created_on,
    users.LAST_SUCCESS_LOGIN AS last_login,
    users.DISABLED AS is_disabled,
    users.HAS_MFA AS has_mfa
  )
  METRICS (
    users.user_count AS COUNT(users.USER_ID),
    users.disabled_count AS SUM(CASE WHEN users.DISABLED = ''true'' THEN 1 ELSE 0 END),
    users.mfa_enabled_count AS SUM(CASE WHEN users.HAS_MFA = ''true'' THEN 1 ELSE 0 END)
  )
  COMMENT = ''User analytics - Account lifecycle and access patterns''
', 'User management and dormant account analysis'),

-- ─────────────────────────────────────────────────────────────────────────────
-- ROLE_ANALYTICS - Role configuration and privilege analysis
-- ─────────────────────────────────────────────────────────────────────────────
('ACCOUNT_USAGE', 'ROLE_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.ROLE_ANALYTICS
  TABLES (
    roles AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ROLES_ARCHIVE PRIMARY KEY (ROLE_ID)
  )
  DIMENSIONS (
    roles.ROLE_ID AS role_id,
    roles.NAME AS role_name,
    roles.COMMENT AS role_comment,
    roles.CREATED_ON AS created_on,
    roles.OWNER AS owner,
    roles.DELETED_ON AS deleted_on
  )
  METRICS (
    roles.role_count AS COUNT(roles.ROLE_ID),
    roles.active_count AS SUM(CASE WHEN roles.DELETED_ON IS NULL THEN 1 ELSE 0 END)
  )
  COMMENT = ''Role analytics - Privilege hierarchy and access control''
', 'Role management for security governance'),

-- ─────────────────────────────────────────────────────────────────────────────
-- DATABASE_ANALYTICS - Database inventory and evolution
-- ─────────────────────────────────────────────────────────────────────────────
('ACCOUNT_USAGE', 'DATABASE_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.DATABASE_ANALYTICS
  TABLES (
    databases AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASES_ARCHIVE PRIMARY KEY (DATABASE_ID)
  )
  DIMENSIONS (
    databases.DATABASE_ID AS database_id,
    databases.DATABASE_NAME AS database_name,
    databases.DATABASE_OWNER AS database_owner,
    databases.CREATED AS created_on,
    databases.DELETED AS deleted_on,
    databases.COMMENT AS database_comment,
    databases.TYPE AS database_type,
    databases.IS_TRANSIENT AS is_transient,
    databases.RETENTION_TIME AS retention_time
  )
  METRICS (
    databases.database_count AS COUNT(databases.DATABASE_ID),
    databases.active_count AS SUM(CASE WHEN databases.DELETED IS NULL THEN 1 ELSE 0 END)
  )
  COMMENT = ''Database analytics - Inventory and lifecycle tracking''
', 'Database management and change tracking'),

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE_ANALYTICS - Table inventory and storage
-- ─────────────────────────────────────────────────────────────────────────────
('ACCOUNT_USAGE', 'TABLE_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.TABLE_ANALYTICS
  TABLES (
    tables AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TABLES_ARCHIVE PRIMARY KEY (TABLE_ID)
  )
  DIMENSIONS (
    tables.TABLE_ID AS table_id,
    tables.TABLE_NAME AS table_name,
    tables.TABLE_SCHEMA AS schema_name,
    tables.TABLE_CATALOG AS database_name,
    tables.TABLE_OWNER AS table_owner,
    tables.TABLE_TYPE AS table_type,
    tables.IS_TRANSIENT AS is_transient,
    tables.CREATED AS created_on,
    tables.DELETED AS deleted_on,
    tables.ROW_COUNT AS row_count,
    tables.BYTES AS bytes,
    tables.RETENTION_TIME AS retention_time
  )
  METRICS (
    tables.table_count AS COUNT(tables.TABLE_ID),
    tables.total_rows AS SUM(tables.ROW_COUNT),
    tables.total_bytes AS SUM(tables.BYTES),
    tables.active_count AS SUM(CASE WHEN tables.DELETED IS NULL THEN 1 ELSE 0 END)
  )
  COMMENT = ''Table analytics - Inventory, storage, and growth tracking''
', 'Table management and storage optimization');


-- ═══════════════════════════════════════════════════════════════════════════
-- BUILD SEMANTIC LAYER PROCEDURE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE PROCEDURE TEMPORAL_ARCHIVE.SEMANTIC.BUILD_SEMANTIC_LAYER()
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'Builds all semantic views from configuration. Ref: https://docs.snowflake.com/en/user-guide/backups'
AS
$$
DECLARE
    results ARRAY DEFAULT ARRAY_CONSTRUCT();
    view_result VARIANT;
    success_count INTEGER DEFAULT 0;
    error_count INTEGER DEFAULT 0;
    
    config_cursor CURSOR FOR
        SELECT 
            SOURCE_SCHEMA,
            VIEW_NAME,
            VIEW_SQL,
            VIEW_COMMENT
        FROM TEMPORAL_ARCHIVE.SEMANTIC.SEMANTIC_CONFIG
        WHERE IS_ACTIVE = TRUE
        ORDER BY SOURCE_SCHEMA, VIEW_NAME;
BEGIN
    FOR rec IN config_cursor DO
        BEGIN
            EXECUTE IMMEDIATE rec.VIEW_SQL;
            
            results := ARRAY_APPEND(results, OBJECT_CONSTRUCT(
                'source_schema', rec.SOURCE_SCHEMA,
                'view_name', rec.VIEW_NAME,
                'status', 'SUCCESS'
            ));
            success_count := success_count + 1;
        EXCEPTION
            WHEN OTHER THEN
                results := ARRAY_APPEND(results, OBJECT_CONSTRUCT(
                    'source_schema', rec.SOURCE_SCHEMA,
                    'view_name', rec.VIEW_NAME,
                    'status', 'ERROR',
                    'error', SQLERRM
                ));
                error_count := error_count + 1;
        END;
    END FOR;
    
    RETURN OBJECT_CONSTRUCT(
        'status', CASE WHEN error_count = 0 THEN 'SUCCESS' ELSE 'PARTIAL' END,
        'views_created', success_count,
        'views_failed', error_count,
        'details', results,
        'reference', 'https://docs.snowflake.com/en/user-guide/backups'
    );
END;
$$;


-- ═══════════════════════════════════════════════════════════════════════════
-- BUILD SEMANTIC VIEWS
-- ═══════════════════════════════════════════════════════════════════════════

-- Execute the build procedure
CALL TEMPORAL_ARCHIVE.SEMANTIC.BUILD_SEMANTIC_LAYER();


-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION SUMMARY VIEW
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW TEMPORAL_ARCHIVE.SEMANTIC.V_SEMANTIC_CONFIG_SUMMARY AS
SELECT 
    SOURCE_SCHEMA,
    VIEW_TYPE,
    COUNT(*) AS VIEW_COUNT,
    SUM(CASE WHEN IS_ACTIVE THEN 1 ELSE 0 END) AS ACTIVE_COUNT
FROM TEMPORAL_ARCHIVE.SEMANTIC.SEMANTIC_CONFIG
GROUP BY SOURCE_SCHEMA, VIEW_TYPE
ORDER BY SOURCE_SCHEMA;


-- ═══════════════════════════════════════════════════════════════════════════
-- GRANTS
-- ═══════════════════════════════════════════════════════════════════════════

GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_WRITER;
GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_ADMIN;

GRANT SELECT ON ALL TABLES IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT SELECT ON ALL VIEWS IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_READER;

GRANT USAGE ON PROCEDURE TEMPORAL_ARCHIVE.SEMANTIC.BUILD_SEMANTIC_LAYER() TO ROLE TEMPORAL_ARCHIVE_ADMIN;


-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- View configuration summary
SELECT * FROM TEMPORAL_ARCHIVE.SEMANTIC.V_SEMANTIC_CONFIG_SUMMARY;

-- List semantic views
-- SHOW SEMANTIC VIEWS IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC;

SELECT '03_semantic_layer.sql completed successfully' AS STATUS;


-- ═══════════════════════════════════════════════════════════════════════════
-- USAGE INSTRUCTIONS
-- ═══════════════════════════════════════════════════════════════════════════
/*
View configuration summary:
  SELECT * FROM TEMPORAL_ARCHIVE.SEMANTIC.V_SEMANTIC_CONFIG_SUMMARY;

Rebuild all semantic views:
  CALL TEMPORAL_ARCHIVE.SEMANTIC.BUILD_SEMANTIC_LAYER();

Use with Cortex Analyst (natural language queries):
  "What was total query cost by warehouse last quarter?"
  "Show me login failures by user in 2024"
  "Which users haven't logged in for 90 days?"
  "Show storage growth trend over the last 3 years"
  "Compare warehouse credit usage year over year"

Reference: https://docs.snowflake.com/en/user-guide/backups
*/
