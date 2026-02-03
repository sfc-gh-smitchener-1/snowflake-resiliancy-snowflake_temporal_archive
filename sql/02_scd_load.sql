/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - SCD TYPE 2 LOAD (SIMPLIFIED)
================================================================================

Dynamically discovers ALL views from SNOWFLAKE.ACCOUNT_USAGE and 
SNOWFLAKE.ORGANIZATION_USAGE and archives them using SCD Type 2 with:
  - Surrogate key (_ARCHIVE_ID) as primary key
  - Row hash for change detection
  - No hardcoded PK mappings needed

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
-- PROCEDURE: RUN_SCD_LOAD
-- Discovers ALL views dynamically and processes them
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
    views_processed INTEGER DEFAULT 0;
    v_source_schema VARCHAR;
    v_source_view VARCHAR;
    -- Static cursor to get all views from our PK mapping (for views that exist)
    cur CURSOR FOR 
        SELECT 
            TABLE_SCHEMA,
            TABLE_NAME
        FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS
        WHERE TABLE_SCHEMA IN ('ACCOUNT_USAGE', 'ORGANIZATION_USAGE')
        ORDER BY TABLE_SCHEMA, TABLE_NAME;
BEGIN
    start_time := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    
    -- Process all views dynamically discovered from SNOWFLAKE
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
            total_updated := total_updated + table_result:rows_updated::INTEGER;
            total_inserted := total_inserted + table_result:rows_inserted::INTEGER;
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
        'views_processed', views_processed,
        'total_updated', total_updated,
        'total_inserted', total_inserted,
        'error_count', error_count,
        'success_count', views_processed - error_count,
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
    COMMENT = 'Morning SCD load at 6 AM ET. Dynamically discovers all ACCOUNT_USAGE and ORGANIZATION_USAGE views.'
AS
    CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();

CREATE OR REPLACE TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING
    WAREHOUSE = TEMPORAL_ARCHIVE_WH
    SCHEDULE = 'USING CRON 0 18 * * * America/New_York'
    COMMENT = 'Evening SCD load at 6 PM ET. Dynamically discovers all ACCOUNT_USAGE and ORGANIZATION_USAGE views.'
AS
    CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();

ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_MORNING RESUME;

ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING RESUME;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

SHOW TASKS IN SCHEMA TEMPORAL_ARCHIVE.ARCHIVE;

-- Show how many views are available
SELECT 
    TABLE_SCHEMA,
    COUNT(*) AS VIEW_COUNT
FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA IN ('ACCOUNT_USAGE', 'ORGANIZATION_USAGE')
GROUP BY TABLE_SCHEMA
ORDER BY TABLE_SCHEMA;

SELECT 'SCD load setup complete. All views will be discovered dynamically.' AS STATUS;
