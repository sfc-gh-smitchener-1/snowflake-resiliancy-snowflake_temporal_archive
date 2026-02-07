/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - SCD TYPE 2 LOAD (SIMPLIFIED)
================================================================================

Dynamically discovers ALL views from SNOWFLAKE.ACCOUNT_USAGE and 
SNOWFLAKE.ORGANIZATION_USAGE and archives them using SCD Type 2 with:
  - Surrogate key (_ARCHIVE_ID) as primary key
  - Row hash for change detection
  - No hardcoded PK mappings needed

TIMEZONE HANDLING:
  - All timestamps use TIMESTAMP_NTZ (no timezone) via CURRENT_TIMESTAMP()
  - Tasks are scheduled in America/New_York timezone (6 AM and 6 PM ET)
  - _LOADED_AT, _VALID_FROM, _VALID_TO columns store UTC-equivalent times
  - When querying, be aware that timestamps are session timezone dependent
  - For consistent reporting, use CONVERT_TIMEZONE() when needed

Run this script in a Snowflake Worksheet after 01_initial_setup.sql.

Reference: https://docs.snowflake.com/en/user-guide/backups
================================================================================
*/

USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE SCHEMA ARCHIVE;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

-- =============================================================================
-- LOAD LOG TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG (
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
-- VIEW REGISTRY: All known ACCOUNT_USAGE and ORGANIZATION_USAGE views
-- This ensures we attempt to load ALL views, not just what INFORMATION_SCHEMA shows
-- =============================================================================

CREATE OR REPLACE TABLE TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (
    SOURCE_SCHEMA VARCHAR(100),
    SOURCE_VIEW VARCHAR(200),
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Registry of all known views to archive from SNOWFLAKE database';

-- Truncate and reload to ensure we have the full list
TRUNCATE TABLE TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY;

-- Insert ALL known ACCOUNT_USAGE views (as of 2024)
INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW) VALUES
-- Core metadata views
('ACCOUNT_USAGE', 'DATABASES'),
('ACCOUNT_USAGE', 'SCHEMATA'),
('ACCOUNT_USAGE', 'TABLES'),
('ACCOUNT_USAGE', 'VIEWS'),
('ACCOUNT_USAGE', 'COLUMNS'),
('ACCOUNT_USAGE', 'TABLE_CONSTRAINTS'),
('ACCOUNT_USAGE', 'REFERENTIAL_CONSTRAINTS'),
('ACCOUNT_USAGE', 'SEQUENCES'),
('ACCOUNT_USAGE', 'FILE_FORMATS'),
('ACCOUNT_USAGE', 'FUNCTIONS'),
('ACCOUNT_USAGE', 'PROCEDURES'),
('ACCOUNT_USAGE', 'STAGES'),
('ACCOUNT_USAGE', 'PIPES'),
('ACCOUNT_USAGE', 'STREAMS'),
('ACCOUNT_USAGE', 'TASKS'),
('ACCOUNT_USAGE', 'TAGS'),
('ACCOUNT_USAGE', 'TAG_REFERENCES'),
-- Security and access
('ACCOUNT_USAGE', 'USERS'),
('ACCOUNT_USAGE', 'ROLES'),
('ACCOUNT_USAGE', 'GRANTS_TO_USERS'),
('ACCOUNT_USAGE', 'GRANTS_TO_ROLES'),
('ACCOUNT_USAGE', 'LOGIN_HISTORY'),
('ACCOUNT_USAGE', 'SESSIONS'),
('ACCOUNT_USAGE', 'ACCESS_HISTORY'),
('ACCOUNT_USAGE', 'QUERY_HISTORY'),
('ACCOUNT_USAGE', 'POLICY_REFERENCES'),
('ACCOUNT_USAGE', 'MASKING_POLICIES'),
('ACCOUNT_USAGE', 'ROW_ACCESS_POLICIES'),
('ACCOUNT_USAGE', 'PASSWORD_POLICIES'),
('ACCOUNT_USAGE', 'SESSION_POLICIES'),
('ACCOUNT_USAGE', 'NETWORK_POLICIES'),
-- Metering and usage
('ACCOUNT_USAGE', 'WAREHOUSE_METERING_HISTORY'),
('ACCOUNT_USAGE', 'WAREHOUSE_LOAD_HISTORY'),
('ACCOUNT_USAGE', 'WAREHOUSE_EVENTS_HISTORY'),
('ACCOUNT_USAGE', 'METERING_HISTORY'),
('ACCOUNT_USAGE', 'METERING_DAILY_HISTORY'),
('ACCOUNT_USAGE', 'STORAGE_USAGE'),
('ACCOUNT_USAGE', 'DATABASE_STORAGE_USAGE_HISTORY'),
('ACCOUNT_USAGE', 'STAGE_STORAGE_USAGE_HISTORY'),
('ACCOUNT_USAGE', 'TABLE_STORAGE_METRICS'),
('ACCOUNT_USAGE', 'DATA_TRANSFER_HISTORY'),
('ACCOUNT_USAGE', 'REPLICATION_USAGE_HISTORY'),
('ACCOUNT_USAGE', 'DATABASE_REPLICATION_USAGE_HISTORY'),
('ACCOUNT_USAGE', 'REPLICATION_GROUP_USAGE_HISTORY'),
('ACCOUNT_USAGE', 'REPLICATION_GROUP_REFRESH_HISTORY'),
-- Data loading
('ACCOUNT_USAGE', 'LOAD_HISTORY'),
('ACCOUNT_USAGE', 'COPY_HISTORY'),
('ACCOUNT_USAGE', 'PIPE_USAGE_HISTORY'),
-- Features
('ACCOUNT_USAGE', 'AUTOMATIC_CLUSTERING_HISTORY'),
('ACCOUNT_USAGE', 'MATERIALIZED_VIEW_REFRESH_HISTORY'),
('ACCOUNT_USAGE', 'SEARCH_OPTIMIZATION_HISTORY'),
('ACCOUNT_USAGE', 'QUERY_ACCELERATION_HISTORY'),
('ACCOUNT_USAGE', 'SERVERLESS_TASK_HISTORY'),
('ACCOUNT_USAGE', 'TASK_HISTORY'),
('ACCOUNT_USAGE', 'TASK_VERSIONS'),
('ACCOUNT_USAGE', 'LOCK_WAIT_HISTORY'),
('ACCOUNT_USAGE', 'OBJECT_DEPENDENCIES'),
('ACCOUNT_USAGE', 'EVENT_USAGE_HISTORY'),
('ACCOUNT_USAGE', 'HYBRID_TABLE_USAGE_HISTORY'),
-- Additional views
('ACCOUNT_USAGE', 'CLASSES'),
('ACCOUNT_USAGE', 'CLASS_INSTANCES'),
('ACCOUNT_USAGE', 'ALERTS'),
('ACCOUNT_USAGE', 'ALERT_HISTORY'),
('ACCOUNT_USAGE', 'SERVICES'),
('ACCOUNT_USAGE', 'COMPUTE_POOLS'),
('ACCOUNT_USAGE', 'WAREHOUSES'),
('ACCOUNT_USAGE', 'RESOURCE_MONITORS'),
('ACCOUNT_USAGE', 'INTEGRATIONS'),
('ACCOUNT_USAGE', 'EXTERNAL_ACCESS_HISTORY'),
('ACCOUNT_USAGE', 'AGGREGATE_QUERY_HISTORY'),
('ACCOUNT_USAGE', 'AGGREGATE_ACCESS_HISTORY'),
('ACCOUNT_USAGE', 'CORTEX_FUNCTIONS_USAGE_HISTORY'),
('ACCOUNT_USAGE', 'CORTEX_SEARCH_DAILY_USAGE_HISTORY'),
('ACCOUNT_USAGE', 'SNOWPARK_CONTAINER_SERVICES_HISTORY'),
('ACCOUNT_USAGE', 'SNOWPIPE_STREAMING_CLIENT_HISTORY'),
('ACCOUNT_USAGE', 'DYNAMIC_TABLE_REFRESH_HISTORY'),
('ACCOUNT_USAGE', 'DATA_CLASSIFICATION_LATEST'),
('ACCOUNT_USAGE', 'DATA_METRIC_FUNCTION_REFERENCES'),
('ACCOUNT_USAGE', 'PRIVACY_POLICIES'),
('ACCOUNT_USAGE', 'PROJECTION_POLICIES'),
('ACCOUNT_USAGE', 'AGGREGATION_POLICIES'),
('ACCOUNT_USAGE', 'BACKUP_POLICIES'),
('ACCOUNT_USAGE', 'BACKUPS'),
('ACCOUNT_USAGE', 'BACKUP_SETS'),
-- ORGANIZATION_USAGE views
('ORGANIZATION_USAGE', 'WAREHOUSE_METERING_HISTORY'),
('ORGANIZATION_USAGE', 'STORAGE_DAILY_HISTORY'),
('ORGANIZATION_USAGE', 'DATA_TRANSFER_HISTORY'),
('ORGANIZATION_USAGE', 'METERING_DAILY_HISTORY'),
('ORGANIZATION_USAGE', 'RATE_SHEET_DAILY'),
('ORGANIZATION_USAGE', 'REMAINING_BALANCE_DAILY'),
('ORGANIZATION_USAGE', 'USAGE_IN_CURRENCY_DAILY'),
('ORGANIZATION_USAGE', 'CONTRACT_ITEMS'),
('ORGANIZATION_USAGE', 'ACCOUNTS'),
('ORGANIZATION_USAGE', 'REGION_GROUPS'),
('ORGANIZATION_USAGE', 'REGIONS'),
('ORGANIZATION_USAGE', 'REPLICATION_GROUP_USAGE_HISTORY'),
('ORGANIZATION_USAGE', 'DATABASE_REPLICATION_USAGE_HISTORY'),
('ORGANIZATION_USAGE', 'AUTOMATIC_CLUSTERING_HISTORY'),
('ORGANIZATION_USAGE', 'MATERIALIZED_VIEW_REFRESH_HISTORY'),
('ORGANIZATION_USAGE', 'SEARCH_OPTIMIZATION_HISTORY'),
('ORGANIZATION_USAGE', 'SERVERLESS_TASK_HISTORY'),
('ORGANIZATION_USAGE', 'QUERY_ACCELERATION_HISTORY'),
('ORGANIZATION_USAGE', 'PIPE_USAGE_HISTORY'),
('ORGANIZATION_USAGE', 'MARKETPLACE_DISBURSEMENT_REPORT'),
('ORGANIZATION_USAGE', 'MARKETPLACE_PAID_USAGE_DAILY'),
-- DATA_SHARING_USAGE views (for accounts with data sharing enabled)
('DATA_SHARING_USAGE', 'LISTING_EVENTS_DAILY'),
('DATA_SHARING_USAGE', 'LISTING_TELEMETRY_DAILY'),
('DATA_SHARING_USAGE', 'MARKETPLACE_PAID_USAGE_DAILY'),
-- READER_ACCOUNT_USAGE views (for accounts with reader accounts)
('READER_ACCOUNT_USAGE', 'LOGIN_HISTORY'),
('READER_ACCOUNT_USAGE', 'QUERY_HISTORY'),
('READER_ACCOUNT_USAGE', 'RESOURCE_MONITORS'),
('READER_ACCOUNT_USAGE', 'STORAGE_USAGE'),
('READER_ACCOUNT_USAGE', 'WAREHOUSE_METERING_HISTORY');

-- =============================================================================
-- PROCEDURE: LOAD_VIEW_ARCHIVE
-- Simplified SCD Type 2 load using surrogate key and row hash
-- No PK mapping needed - works with ANY view
-- =============================================================================

CREATE OR REPLACE PROCEDURE TEMPORAL_ARCHIVE.ARCHIVE.LOAD_VIEW_ARCHIVE(
    p_source_schema VARCHAR,
    p_source_view VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_schema VARCHAR;
    v_view VARCHAR;
    v_target_table VARCHAR;
    v_source_fqn VARCHAR;
    v_target_fqn VARCHAR;
    v_target_schema VARCHAR;
    v_table_exists INTEGER DEFAULT 0;
    v_source_exists INTEGER DEFAULT 0;
    v_create_sql VARCHAR;
    v_insert_sql VARCHAR;
    v_update_sql VARCHAR;
    v_rows_inserted INTEGER DEFAULT 0;
    v_rows_updated INTEGER DEFAULT 0;
BEGIN
    -- Copy parameters to local variables
    v_schema := p_source_schema;
    v_view := p_source_view;
    v_target_table := v_view || '_ARCHIVE';
    v_target_schema := v_schema;
    v_source_fqn := 'SNOWFLAKE.' || v_schema || '.' || v_view;
    v_target_fqn := 'TEMPORAL_ARCHIVE.' || v_target_schema || '.' || v_target_table;
    
    -- Validate source view exists before attempting to load
    SELECT COUNT(*) INTO :v_source_exists
    FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS
    WHERE TABLE_SCHEMA = :v_schema
      AND TABLE_NAME = :v_view;
    
    IF (v_source_exists = 0) THEN
        -- Source view does not exist - return warning without failing
        RETURN OBJECT_CONSTRUCT(
            'source', v_source_fqn,
            'target', v_target_fqn,
            'status', 'skipped',
            'reason', 'Source view does not exist or is not accessible',
            'timestamp', CURRENT_TIMESTAMP()::VARCHAR
        );
    END IF;
    
    -- Check if target table exists
    SELECT COUNT(*) INTO :v_table_exists
    FROM TEMPORAL_ARCHIVE.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = :v_target_schema
      AND TABLE_NAME = :v_target_table;
    
    -- Create target table if not exists
    IF (v_table_exists = 0) THEN
        -- Create schema if needed
        EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.' || v_target_schema;
        
        -- Create table with surrogate key and SCD columns
        -- Use OBJECT_CONSTRUCT(*) to create a JSON object of all columns for hashing
        v_create_sql := 'CREATE TABLE ' || v_target_fqn || ' AS 
            SELECT 
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS "_ARCHIVE_ID",
                src.*,
                SHA2(TO_JSON(OBJECT_CONSTRUCT(*)), 256) AS "_ROW_HASH",
                CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_LOADED_AT",
                ''SNOWFLAKE_' || v_schema || ''' AS "_SOURCE_SYSTEM",
                ''' || v_view || ''' AS "_SOURCE_TABLE",
                TRUE AS "_IS_CURRENT",
                CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_VALID_FROM",
                ''9999-12-31 23:59:59''::TIMESTAMP_NTZ AS "_VALID_TO"
            FROM ' || v_source_fqn || ' src';
        
        EXECUTE IMMEDIATE v_create_sql;
        
        -- =====================================================================
        -- INDEX RECOMMENDATIONS (for query performance on large tables):
        -- Snowflake uses micro-partitions and automatic clustering, but you can
        -- improve query performance with clustering keys on frequently filtered columns.
        -- 
        -- Recommended clustering keys for archive tables:
        --   ALTER TABLE <table> CLUSTER BY ("_IS_CURRENT", "_VALID_FROM");
        -- 
        -- This helps queries that filter on current records (WHERE "_IS_CURRENT" = TRUE)
        -- which is the most common query pattern.
        -- 
        -- For very large tables (>1TB), consider:
        --   ALTER TABLE <table> CLUSTER BY ("_IS_CURRENT", "_LOADED_AT");
        -- =====================================================================
        
        SELECT COUNT(*) INTO :v_rows_inserted FROM IDENTIFIER(:v_target_fqn);
        
        RETURN OBJECT_CONSTRUCT(
            'source', v_source_fqn,
            'target', v_target_fqn,
            'action', 'INITIAL_LOAD',
            'rows_inserted', v_rows_inserted,
            'rows_updated', 0,
            'status', 'success',
            'timestamp', CURRENT_TIMESTAMP()::VARCHAR
        );
    END IF;
    
    -- Table exists - do incremental SCD Type 2 load
    
    -- Step 1: Close records that have changed (update _IS_CURRENT = FALSE)
    -- Compare hashes - if source hash not in target's current hashes, mark as closed
    v_update_sql := '
        UPDATE ' || v_target_fqn || ' tgt
        SET "_IS_CURRENT" = FALSE,
            "_VALID_TO" = CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
        WHERE tgt."_IS_CURRENT" = TRUE
          AND tgt."_ROW_HASH" NOT IN (
              SELECT SHA2(TO_JSON(OBJECT_CONSTRUCT(*)), 256) 
              FROM ' || v_source_fqn || '
          )';
    
    EXECUTE IMMEDIATE v_update_sql;
    v_rows_updated := SQLROWCOUNT;
    
    -- Step 2: Insert new/changed records
    -- Only insert rows whose hash doesn't exist in target's current records
    v_insert_sql := '
        INSERT INTO ' || v_target_fqn || '
        SELECT 
            (SELECT COALESCE(MAX("_ARCHIVE_ID"), 0) FROM ' || v_target_fqn || ') + 
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS "_ARCHIVE_ID",
            src.*,
            SHA2(TO_JSON(OBJECT_CONSTRUCT(*)), 256) AS "_ROW_HASH",
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_LOADED_AT",
            ''SNOWFLAKE_' || v_schema || ''' AS "_SOURCE_SYSTEM",
            ''' || v_view || ''' AS "_SOURCE_TABLE",
            TRUE AS "_IS_CURRENT",
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_VALID_FROM",
            ''9999-12-31 23:59:59''::TIMESTAMP_NTZ AS "_VALID_TO"
        FROM ' || v_source_fqn || ' src
        WHERE SHA2(TO_JSON(OBJECT_CONSTRUCT(*)), 256) NOT IN (
            SELECT "_ROW_HASH" FROM ' || v_target_fqn || ' WHERE "_IS_CURRENT" = TRUE
        )';
    
    EXECUTE IMMEDIATE v_insert_sql;
    v_rows_inserted := SQLROWCOUNT;
    
    RETURN OBJECT_CONSTRUCT(
        'source', v_source_fqn,
        'target', v_target_fqn,
        'action', 'INCREMENTAL_LOAD',
        'rows_inserted', v_rows_inserted,
        'rows_updated', v_rows_updated,
        'status', 'success',
        'timestamp', CURRENT_TIMESTAMP()::VARCHAR
    );
    
EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT(
            'source', v_source_fqn,
            'target', v_target_fqn,
            'status', 'error',
            'error', SQLERRM,
            'timestamp', CURRENT_TIMESTAMP()::VARCHAR
        );
END;
$$;

-- =============================================================================
-- PROCEDURE: LOAD_VIEW_ARCHIVE_WITH_RETRY
-- Wrapper with configurable retry logic for transient failures
-- =============================================================================

CREATE OR REPLACE PROCEDURE TEMPORAL_ARCHIVE.ARCHIVE.LOAD_VIEW_ARCHIVE_WITH_RETRY(
    p_source_schema VARCHAR,
    p_source_view VARCHAR,
    p_max_retries INTEGER DEFAULT 3,
    p_retry_delay_seconds INTEGER DEFAULT 5
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_result VARIANT;
    v_retry_count INTEGER DEFAULT 0;
    v_success BOOLEAN DEFAULT FALSE;
    v_last_error VARCHAR DEFAULT '';
BEGIN
    -- Retry loop with exponential backoff
    WHILE (v_retry_count < p_max_retries AND NOT v_success) DO
        BEGIN
            -- Attempt the load
            CALL TEMPORAL_ARCHIVE.ARCHIVE.LOAD_VIEW_ARCHIVE(
                :p_source_schema,
                :p_source_view
            ) INTO v_result;
            
            -- Check if successful or skipped (not an error)
            IF (v_result:status IN ('success', 'skipped')) THEN
                v_success := TRUE;
            ELSE
                -- Error occurred - prepare for retry
                v_last_error := v_result:error::VARCHAR;
                v_retry_count := v_retry_count + 1;
                
                IF (v_retry_count < p_max_retries) THEN
                    -- Wait before retry (exponential backoff: delay * 2^retry)
                    CALL SYSTEM$WAIT(p_retry_delay_seconds * POWER(2, v_retry_count - 1));
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHER THEN
                v_last_error := SQLERRM;
                v_retry_count := v_retry_count + 1;
                
                IF (v_retry_count < p_max_retries) THEN
                    CALL SYSTEM$WAIT(p_retry_delay_seconds * POWER(2, v_retry_count - 1));
                END IF;
        END;
    END WHILE;
    
    -- Add retry metadata to result
    IF (v_success) THEN
        RETURN OBJECT_INSERT(v_result, 'retries', v_retry_count);
    ELSE
        RETURN OBJECT_CONSTRUCT(
            'source', 'SNOWFLAKE.' || p_source_schema || '.' || p_source_view,
            'target', 'TEMPORAL_ARCHIVE.' || p_source_schema || '.' || p_source_view || '_ARCHIVE',
            'status', 'error',
            'error', v_last_error,
            'retries', v_retry_count,
            'max_retries_exceeded', TRUE,
            'timestamp', CURRENT_TIMESTAMP()::VARCHAR
        );
    END IF;
END;
$$;

-- =============================================================================
-- PROCEDURE: RUN_SCD_LOAD
-- Processes ALL views from VIEW_REGISTRY
-- =============================================================================

CREATE OR REPLACE PROCEDURE TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD()
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    start_time TIMESTAMP_NTZ;
    end_time TIMESTAMP_NTZ;
    results ARRAY DEFAULT ARRAY_CONSTRUCT();
    table_result VARIANT;
    total_updated INTEGER DEFAULT 0;
    total_inserted INTEGER DEFAULT 0;
    error_count INTEGER DEFAULT 0;
    success_count INTEGER DEFAULT 0;
    views_processed INTEGER DEFAULT 0;
    v_source_schema VARCHAR;
    v_source_view VARCHAR;
    -- Cursor reads from VIEW_REGISTRY to ensure we get ALL views
    cur CURSOR FOR 
        SELECT 
            SOURCE_SCHEMA,
            SOURCE_VIEW
        FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY
        WHERE IS_ACTIVE = TRUE
        ORDER BY SOURCE_SCHEMA, SOURCE_VIEW;
BEGIN
    start_time := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    
    -- Process all views from the registry
    OPEN cur;
    FETCH cur INTO v_source_schema, v_source_view;
    WHILE (v_source_schema IS NOT NULL) DO
        
        -- Call the simplified load procedure
        CALL TEMPORAL_ARCHIVE.ARCHIVE.LOAD_VIEW_ARCHIVE(
            :v_source_schema,
            :v_source_view
        ) INTO table_result;
        
        results := ARRAY_APPEND(results, table_result);
        views_processed := views_processed + 1;
        
        IF (table_result:status = 'success') THEN
            total_updated := total_updated + COALESCE(table_result:rows_updated::INTEGER, 0);
            total_inserted := total_inserted + COALESCE(table_result:rows_inserted::INTEGER, 0);
            success_count := success_count + 1;
        ELSE
            error_count := error_count + 1;
        END IF;
        
        -- Fetch next
        v_source_schema := NULL;
        FETCH cur INTO v_source_schema, v_source_view;
    END WHILE;
    CLOSE cur;
    
    end_time := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    
    -- Log the run
    LET v_duration INTEGER := TIMESTAMPDIFF('SECOND', start_time, end_time);
    LET v_status VARCHAR := CASE WHEN error_count = 0 THEN 'SUCCESS' ELSE 'PARTIAL_FAILURE' END;
    LET v_hash VARCHAR := SHA2('DYNAMIC' || views_processed || total_updated || total_inserted, 256);
    
    INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG (
        SOURCE_TABLE, TARGET_TABLE, ROWS_UPDATED, ROWS_INSERTED, 
        STATUS, DURATION_SECONDS, "_ROW_HASH"
    )
    VALUES (
        'ALL_VIEWS',
        'ALL_ARCHIVES',
        :total_updated,
        :total_inserted,
        :v_status,
        :v_duration,
        :v_hash
    );
    
    RETURN OBJECT_CONSTRUCT(
        'start_time', start_time::VARCHAR,
        'end_time', end_time::VARCHAR,
        'duration_seconds', TIMESTAMPDIFF('SECOND', start_time, end_time),
        'views_in_registry', views_processed,
        'views_processed', views_processed,
        'success_count', success_count,
        'total_updated', total_updated,
        'total_inserted', total_inserted,
        'error_count', error_count,
        'table_results', results
    );
END;
$$;

-- =============================================================================
-- SNOWFLAKE TASKS: Schedule SCD loads twice daily
-- =============================================================================

CREATE OR REPLACE TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_MORNING
    WAREHOUSE = TEMPORAL_ARCHIVE_WH
    SCHEDULE = 'USING CRON 0 6 * * * America/New_York'
    COMMENT = 'Morning SCD load at 6 AM ET. Processes all views from VIEW_REGISTRY.'
AS
    CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();

CREATE OR REPLACE TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING
    WAREHOUSE = TEMPORAL_ARCHIVE_WH
    SCHEDULE = 'USING CRON 0 18 * * * America/New_York'
    COMMENT = 'Evening SCD load at 6 PM ET. Processes all views from VIEW_REGISTRY.'
AS
    CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();

ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_MORNING RESUME;

ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING RESUME;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

SHOW TASKS IN SCHEMA TEMPORAL_ARCHIVE.ARCHIVE;

-- Show how many views are in the registry
SELECT 
    SOURCE_SCHEMA,
    COUNT(*) AS VIEW_COUNT
FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY
WHERE IS_ACTIVE = TRUE
GROUP BY SOURCE_SCHEMA
ORDER BY SOURCE_SCHEMA;

SELECT 'SCD load setup complete. ' || COUNT(*) || ' views registered for archiving.' AS STATUS
FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY WHERE IS_ACTIVE = TRUE;
