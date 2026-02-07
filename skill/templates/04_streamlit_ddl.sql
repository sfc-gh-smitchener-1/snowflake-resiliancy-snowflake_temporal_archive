-- ============================================================================
-- SNOWFLAKE TEMPORAL ARCHIVE - STREAMLIT DDL
-- ============================================================================
-- 
-- Creates the supporting database objects for the Streamlit app.
-- Run this script in a Snowflake Worksheet after 03_semantic_layer.sql.
--
-- Reference: https://docs.snowflake.com/en/user-guide/backups
-- ============================================================================

-- =============================================================================
-- RUN AS {{ADMIN_ROLE}}
-- =============================================================================
USE ROLE {{ADMIN_ROLE}};
USE DATABASE {{DATABASE_NAME}};
USE WAREHOUSE {{DATABASE_NAME}}_WH;

-- =============================================================================
-- ENSURE ARCHIVE SCHEMA EXISTS (for LOAD_LOG reference)
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS {{DATABASE_NAME}}.ARCHIVE
    COMMENT = 'Archive control tables and procedures';

CREATE TABLE IF NOT EXISTS {{DATABASE_NAME}}.ARCHIVE.LOAD_LOG (
    LOG_ID                  NUMBER AUTOINCREMENT,
    SOURCE_TABLE            VARCHAR(512),
    TARGET_TABLE            VARCHAR(512),
    ROWS_UPDATED            NUMBER,
    ROWS_INSERTED           NUMBER,
    STATUS                  VARCHAR(50),
    ERROR_MESSAGE           VARCHAR(4096),
    DURATION_SECONDS        NUMBER,
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_ROW_HASH"             VARCHAR(64)
)
COMMENT = 'Log of SCD load executions';

-- =============================================================================
-- CREATE STREAMLIT SCHEMA AND STAGE
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS {{DATABASE_NAME}}.STREAMLIT
    COMMENT = 'Streamlit application objects. Ref: https://docs.snowflake.com/en/user-guide/backups';

CREATE STAGE IF NOT EXISTS {{DATABASE_NAME}}.STREAMLIT.STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for Temporal Archive Streamlit application files';


-- =============================================================================
-- HELPER VIEWS FOR STREAMLIT APP
-- =============================================================================

-- View to show all archive tables (tables ending in _ARCHIVE)
CREATE OR REPLACE VIEW {{DATABASE_NAME}}.STREAMLIT.VW_ARCHIVE_INVENTORY AS
SELECT 
    TABLE_SCHEMA AS SOURCE_SCHEMA,
    TABLE_NAME,
    ROW_COUNT,
    BYTES,
    CREATED AS CREATED_AT,
    LAST_ALTERED AS LAST_MODIFIED
FROM {{DATABASE_NAME}}.INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%_ARCHIVE'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- Summary of archive tables by schema
CREATE OR REPLACE VIEW {{DATABASE_NAME}}.STREAMLIT.VW_ARCHIVE_SUMMARY AS
SELECT 
    TABLE_SCHEMA AS SOURCE_SCHEMA,
    COUNT(*) AS TABLE_COUNT,
    COALESCE(SUM(ROW_COUNT), 0) AS TOTAL_ROWS,
    COALESCE(SUM(BYTES), 0) AS TOTAL_BYTES,
    MAX(LAST_ALTERED) AS LAST_UPDATE
FROM {{DATABASE_NAME}}.INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%_ARCHIVE'
  AND TABLE_TYPE = 'BASE TABLE'
GROUP BY TABLE_SCHEMA
ORDER BY TABLE_SCHEMA;

-- Load history from the LOAD_LOG table
CREATE OR REPLACE VIEW {{DATABASE_NAME}}.STREAMLIT.VW_LOAD_HISTORY AS
SELECT 
    LOG_ID,
    LOAD_TIMESTAMP,
    SOURCE_TABLE,
    TARGET_TABLE,
    ROWS_UPDATED,
    ROWS_INSERTED,
    STATUS,
    DURATION_SECONDS,
    ERROR_MESSAGE
FROM {{DATABASE_NAME}}.ARCHIVE.LOAD_LOG
ORDER BY LOAD_TIMESTAMP DESC
LIMIT 100;

-- Semantic views - read from INFORMATION_SCHEMA.SEMANTIC_VIEWS
-- Columns in INFORMATION_SCHEMA.SEMANTIC_VIEWS: CATALOG, SCHEMA, NAME, OWNER, CREATED, COMMENT
CREATE OR REPLACE VIEW {{DATABASE_NAME}}.STREAMLIT.VW_SEMANTIC_VIEWS AS
SELECT 
    SCHEMA AS SOURCE_SCHEMA,
    NAME AS VIEW_NAME,
    'SEMANTIC_VIEW' AS VIEW_TYPE,
    COMMENT AS DESCRIPTION,
    TRUE AS IS_ACTIVE,
    CREATED AS CREATED_AT
FROM {{DATABASE_NAME}}.INFORMATION_SCHEMA.SEMANTIC_VIEWS
WHERE SCHEMA = 'SEMANTIC';

-- Backup status
CREATE OR REPLACE VIEW {{DATABASE_NAME}}.STREAMLIT.VW_BACKUP_STATUS AS
SELECT
    '{{DATABASE_NAME}}_WORM_BACKUP_POLICY' AS POLICY_NAME,
    'ENABLED' AS STATUS,
    'Daily (1440 minutes)' AS SCHEDULE,
    '7 years (2555 days)' AS RETENTION,
    'Business Critical' AS EDITION_REQUIRED;


-- =============================================================================
-- STREAMLIT APP CONFIGURATION TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS {{DATABASE_NAME}}.STREAMLIT.APP_CONFIG (
    CONFIG_KEY          VARCHAR(100) PRIMARY KEY,
    CONFIG_VALUE        VARIANT,
    DESCRIPTION         VARCHAR(500),
    UPDATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_LOADED_AT"        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_SOURCE_SYSTEM"    VARCHAR(100) DEFAULT '{{DATABASE_NAME}}',
    "_SOURCE_TABLE"     VARCHAR(100) DEFAULT 'APP_CONFIG',
    "_ROW_HASH"         VARCHAR(64),
    "_IS_CURRENT"       BOOLEAN DEFAULT TRUE,
    "_VALID_FROM"       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_VALID_TO"         VARCHAR(50) DEFAULT '9999-12-31 23:59:59'
);

INSERT INTO {{DATABASE_NAME}}.STREAMLIT.APP_CONFIG (CONFIG_KEY, CONFIG_VALUE, DESCRIPTION)
SELECT 'SOURCE_SCHEMAS', PARSE_JSON('["{{ACCOUNT_USAGE_SCHEMA}}", "{{ORGANIZATION_USAGE_SCHEMA}}", "DATA_SHARING_USAGE"]'), 'Archived source schemas'
WHERE NOT EXISTS (SELECT 1 FROM {{DATABASE_NAME}}.STREAMLIT.APP_CONFIG WHERE CONFIG_KEY = 'SOURCE_SCHEMAS');

INSERT INTO {{DATABASE_NAME}}.STREAMLIT.APP_CONFIG (CONFIG_KEY, CONFIG_VALUE, DESCRIPTION)
SELECT 'CORTEX_MODEL', PARSE_JSON('"llama3.1-70b"'), 'Cortex model for natural language queries'
WHERE NOT EXISTS (SELECT 1 FROM {{DATABASE_NAME}}.STREAMLIT.APP_CONFIG WHERE CONFIG_KEY = 'CORTEX_MODEL');


-- =============================================================================
-- STREAMLIT SUPPORT PROCEDURES
-- =============================================================================

CREATE OR REPLACE PROCEDURE {{DATABASE_NAME}}.STREAMLIT.SAMPLE_ARCHIVE_DATA(
    P_SCHEMA VARCHAR,
    P_TABLE_NAME VARCHAR,
    P_LIMIT INTEGER DEFAULT 100
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    result_sql VARCHAR;
BEGIN
    result_sql := 'SELECT * FROM {{DATABASE_NAME}}.' || P_SCHEMA || '.' || P_TABLE_NAME || 
                  ' WHERE "_IS_CURRENT" = TRUE LIMIT ' || P_LIMIT::VARCHAR;
    
    EXECUTE IMMEDIATE result_sql;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'schema', P_SCHEMA,
        'table', P_TABLE_NAME,
        'limit', P_LIMIT,
        'sql', result_sql
    );
EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT(
            'success', FALSE,
            'error', SQLERRM
        );
END;
$$;

CREATE OR REPLACE PROCEDURE {{DATABASE_NAME}}.STREAMLIT.GET_TABLE_COLUMNS(
    P_SCHEMA VARCHAR,
    P_TABLE_NAME VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    columns ARRAY DEFAULT ARRAY_CONSTRUCT();
    col_cursor CURSOR FOR
        SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
        FROM {{DATABASE_NAME}}.INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = P_SCHEMA
          AND TABLE_NAME = P_TABLE_NAME
        ORDER BY ORDINAL_POSITION;
BEGIN
    FOR rec IN col_cursor DO
        columns := ARRAY_APPEND(columns, OBJECT_CONSTRUCT(
            'column_name', rec.COLUMN_NAME,
            'data_type', rec.DATA_TYPE,
            'is_nullable', rec.IS_NULLABLE
        ));
    END FOR;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'schema', P_SCHEMA,
        'table', P_TABLE_NAME,
        'column_count', ARRAY_SIZE(columns),
        'columns', columns
    );
EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT(
            'success', FALSE,
            'error', SQLERRM
        );
END;
$$;

CREATE OR REPLACE PROCEDURE {{DATABASE_NAME}}.STREAMLIT.TRIGGER_SCD_LOAD()
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    load_result VARIANT;
BEGIN
    CALL {{DATABASE_NAME}}.ARCHIVE.RUN_SCD_LOAD() INTO load_result;
    RETURN load_result;
EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT(
            'success', FALSE,
            'error', SQLERRM
        );
END;
$$;


-- =============================================================================
-- GRANTS
-- =============================================================================

-- STREAMLIT schema grants
GRANT USAGE ON SCHEMA {{DATABASE_NAME}}.STREAMLIT TO ROLE {{DATABASE_NAME}}_READER;
GRANT USAGE ON SCHEMA {{DATABASE_NAME}}.STREAMLIT TO ROLE {{DATABASE_NAME}}_WRITER;
GRANT USAGE ON SCHEMA {{DATABASE_NAME}}.STREAMLIT TO ROLE {{DATABASE_NAME}}_ADMIN;
GRANT SELECT ON ALL VIEWS IN SCHEMA {{DATABASE_NAME}}.STREAMLIT TO ROLE {{DATABASE_NAME}}_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA {{DATABASE_NAME}}.STREAMLIT TO ROLE {{DATABASE_NAME}}_READER;

-- SEMANTIC schema grants (for Cortex Analyst)
GRANT USAGE ON SCHEMA {{DATABASE_NAME}}.SEMANTIC TO ROLE {{DATABASE_NAME}}_READER;
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA {{DATABASE_NAME}}.SEMANTIC TO ROLE {{DATABASE_NAME}}_READER;

-- ARCHIVE schema grants (for LOAD_LOG)
GRANT USAGE ON SCHEMA {{DATABASE_NAME}}.ARCHIVE TO ROLE {{DATABASE_NAME}}_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA {{DATABASE_NAME}}.ARCHIVE TO ROLE {{DATABASE_NAME}}_READER;

-- {{ACCOUNT_USAGE_SCHEMA}} and {{ORGANIZATION_USAGE_SCHEMA}} schema grants
GRANT USAGE ON SCHEMA {{DATABASE_NAME}}.{{ACCOUNT_USAGE_SCHEMA}} TO ROLE {{DATABASE_NAME}}_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA {{DATABASE_NAME}}.{{ACCOUNT_USAGE_SCHEMA}} TO ROLE {{DATABASE_NAME}}_READER;
GRANT USAGE ON SCHEMA {{DATABASE_NAME}}.{{ORGANIZATION_USAGE_SCHEMA}} TO ROLE {{DATABASE_NAME}}_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA {{DATABASE_NAME}}.{{ORGANIZATION_USAGE_SCHEMA}} TO ROLE {{DATABASE_NAME}}_READER;

-- Stage grants
GRANT READ ON STAGE {{DATABASE_NAME}}.STREAMLIT.STREAMLIT_STAGE TO ROLE {{DATABASE_NAME}}_ADMIN;
GRANT WRITE ON STAGE {{DATABASE_NAME}}.STREAMLIT.STREAMLIT_STAGE TO ROLE {{DATABASE_NAME}}_ADMIN;


-- =============================================================================
-- VERIFICATION
-- =============================================================================

SELECT '04_streamlit_ddl.sql completed. Next: Upload app.py and run 05_streamlit_app.sql' AS STATUS;
