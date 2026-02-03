-- ============================================================================
-- SNOWFLAKE TEMPORAL ARCHIVE - SEMANTIC LAYER
-- ============================================================================
-- 
-- Semantic Views for Cortex Analyst - Natural language queries on ACCOUNT_USAGE
-- Run this script in a Snowflake Worksheet after 02_scd_load_procedure.sql.
--
-- Reference: https://docs.snowflake.com/en/user-guide/backups
-- ============================================================================

-- =============================================================================
-- RUN AS DATA_ADMIN
-- =============================================================================
USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

-- =============================================================================
-- CREATE SEMANTIC SCHEMA
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.SEMANTIC
    COMMENT = 'Semantic views for Cortex Analyst. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- SEMANTIC CONFIGURATION TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS TEMPORAL_ARCHIVE.SEMANTIC.SEMANTIC_CONFIG (
    CONFIG_ID               NUMBER AUTOINCREMENT PRIMARY KEY,
    SOURCE_SCHEMA           VARCHAR(100) NOT NULL,
    VIEW_NAME               VARCHAR(100) NOT NULL,
    VIEW_TYPE               VARCHAR(30) DEFAULT 'SEMANTIC_VIEW',
    VIEW_SQL                VARCHAR(32000) NOT NULL,
    VIEW_COMMENT            VARCHAR(1000),
    IS_ACTIVE               BOOLEAN DEFAULT TRUE,
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
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


-- =============================================================================
-- POPULATE SEMANTIC CONFIG
-- =============================================================================

DELETE FROM TEMPORAL_ARCHIVE.SEMANTIC.SEMANTIC_CONFIG WHERE SOURCE_SCHEMA = 'ACCOUNT_USAGE';

INSERT INTO TEMPORAL_ARCHIVE.SEMANTIC.SEMANTIC_CONFIG 
    (SOURCE_SCHEMA, VIEW_NAME, VIEW_TYPE, VIEW_SQL, VIEW_COMMENT)
VALUES
('ACCOUNT_USAGE', 'QUERY_COST_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE VIEW TEMPORAL_ARCHIVE.SEMANTIC.QUERY_COST_ANALYTICS AS
SELECT 
    QUERY_ID,
    USER_NAME,
    ROLE_NAME,
    WAREHOUSE_NAME,
    WAREHOUSE_SIZE,
    DATABASE_NAME,
    SCHEMA_NAME,
    QUERY_TYPE,
    EXECUTION_STATUS,
    START_TIME,
    END_TIME,
    TOTAL_ELAPSED_TIME,
    BYTES_SCANNED,
    ROWS_PRODUCED,
    "_IS_CURRENT",
    "_VALID_FROM",
    "_VALID_TO"
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
', 'Query cost analysis for optimization and chargeback'),

('ACCOUNT_USAGE', 'WAREHOUSE_USAGE_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE VIEW TEMPORAL_ARCHIVE.SEMANTIC.WAREHOUSE_USAGE_ANALYTICS AS
SELECT 
    WAREHOUSE_NAME,
    WAREHOUSE_ID,
    START_TIME,
    END_TIME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES,
    "_IS_CURRENT",
    "_VALID_FROM",
    "_VALID_TO"
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
', 'Warehouse credit consumption for cost optimization'),

('ACCOUNT_USAGE', 'STORAGE_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE VIEW TEMPORAL_ARCHIVE.SEMANTIC.STORAGE_ANALYTICS AS
SELECT 
    USAGE_DATE,
    AVERAGE_DATABASE_BYTES,
    AVERAGE_STAGE_BYTES,
    AVERAGE_FAILSAFE_BYTES,
    "_IS_CURRENT",
    "_VALID_FROM",
    "_VALID_TO"
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.STORAGE_USAGE_ARCHIVE
', 'Storage consumption for capacity planning'),

('ACCOUNT_USAGE', 'LOGIN_SECURITY_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE VIEW TEMPORAL_ARCHIVE.SEMANTIC.LOGIN_SECURITY_ANALYTICS AS
SELECT 
    EVENT_ID,
    EVENT_TIMESTAMP,
    USER_NAME,
    CLIENT_IP,
    REPORTED_CLIENT_TYPE,
    FIRST_AUTHENTICATION_FACTOR,
    SECOND_AUTHENTICATION_FACTOR,
    IS_SUCCESS,
    ERROR_CODE,
    ERROR_MESSAGE,
    "_IS_CURRENT",
    "_VALID_FROM",
    "_VALID_TO"
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
', 'Login history for security auditing and compliance'),

('ACCOUNT_USAGE', 'USER_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE VIEW TEMPORAL_ARCHIVE.SEMANTIC.USER_ANALYTICS AS
SELECT 
    USER_ID,
    NAME AS USER_NAME,
    LOGIN_NAME,
    DISPLAY_NAME,
    EMAIL,
    DEFAULT_WAREHOUSE,
    DEFAULT_ROLE,
    CREATED_ON,
    LAST_SUCCESS_LOGIN,
    DISABLED,
    HAS_MFA,
    "_IS_CURRENT",
    "_VALID_FROM",
    "_VALID_TO"
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
', 'User management and dormant account analysis'),

('ACCOUNT_USAGE', 'ROLE_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE VIEW TEMPORAL_ARCHIVE.SEMANTIC.ROLE_ANALYTICS AS
SELECT 
    ROLE_ID,
    NAME AS ROLE_NAME,
    COMMENT AS ROLE_COMMENT,
    CREATED_ON,
    OWNER,
    DELETED_ON,
    "_IS_CURRENT",
    "_VALID_FROM",
    "_VALID_TO"
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ROLES_ARCHIVE
', 'Role management for security governance'),

('ACCOUNT_USAGE', 'DATABASE_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE VIEW TEMPORAL_ARCHIVE.SEMANTIC.DATABASE_ANALYTICS AS
SELECT 
    DATABASE_ID,
    DATABASE_NAME,
    DATABASE_OWNER,
    CREATED AS CREATED_ON,
    DELETED AS DELETED_ON,
    COMMENT AS DATABASE_COMMENT,
    TYPE AS DATABASE_TYPE,
    IS_TRANSIENT,
    RETENTION_TIME,
    "_IS_CURRENT",
    "_VALID_FROM",
    "_VALID_TO"
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASES_ARCHIVE
', 'Database management and change tracking'),

('ACCOUNT_USAGE', 'TABLE_ANALYTICS', 'SEMANTIC_VIEW', '
CREATE OR REPLACE VIEW TEMPORAL_ARCHIVE.SEMANTIC.TABLE_ANALYTICS AS
SELECT 
    TABLE_ID,
    TABLE_NAME,
    TABLE_SCHEMA AS SCHEMA_NAME,
    TABLE_CATALOG AS DATABASE_NAME,
    TABLE_OWNER,
    TABLE_TYPE,
    IS_TRANSIENT,
    CREATED AS CREATED_ON,
    DELETED AS DELETED_ON,
    ROW_COUNT,
    BYTES,
    RETENTION_TIME,
    "_IS_CURRENT",
    "_VALID_FROM",
    "_VALID_TO"
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TABLES_ARCHIVE
', 'Table management and storage optimization');


-- =============================================================================
-- BUILD SEMANTIC LAYER PROCEDURE
-- =============================================================================

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


-- =============================================================================
-- CONFIGURATION SUMMARY VIEW
-- =============================================================================

CREATE OR REPLACE VIEW TEMPORAL_ARCHIVE.SEMANTIC.V_SEMANTIC_CONFIG_SUMMARY AS
SELECT 
    SOURCE_SCHEMA,
    VIEW_TYPE,
    COUNT(*) AS VIEW_COUNT,
    SUM(CASE WHEN IS_ACTIVE THEN 1 ELSE 0 END) AS ACTIVE_COUNT
FROM TEMPORAL_ARCHIVE.SEMANTIC.SEMANTIC_CONFIG
GROUP BY SOURCE_SCHEMA, VIEW_TYPE
ORDER BY SOURCE_SCHEMA;


-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_READER;

GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_WRITER;

GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_ADMIN;

GRANT SELECT ON ALL TABLES IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_READER;

GRANT SELECT ON ALL VIEWS IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_READER;


-- =============================================================================
-- VERIFICATION
-- =============================================================================

SELECT * FROM TEMPORAL_ARCHIVE.SEMANTIC.V_SEMANTIC_CONFIG_SUMMARY;

SELECT '03_semantic_layer.sql completed. Next: Run 04_streamlit_ddl.sql as DATA_ADMIN' AS STATUS;
