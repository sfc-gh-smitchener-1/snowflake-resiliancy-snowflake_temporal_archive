/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - SCD TYPE 2 LOAD
================================================================================

Creates the TABLE_REGISTRY, SCD procedures, and scheduled Tasks.
Run this script in a Snowflake Worksheet after 01_initial_setup.sql.

Reference: https://docs.snowflake.com/en/user-guide/backups
================================================================================
*/

USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE SCHEMA ARCHIVE;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

-- =============================================================================
-- TABLE REGISTRY: Defines all source-to-target mappings
-- =============================================================================

CREATE TABLE IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE.TABLE_REGISTRY (
    REGISTRY_ID             NUMBER AUTOINCREMENT,
    SOURCE_DATABASE         VARCHAR(256) NOT NULL,
    SOURCE_SCHEMA           VARCHAR(256) NOT NULL,
    SOURCE_VIEW             VARCHAR(256) NOT NULL,
    TARGET_DATABASE         VARCHAR(256) NOT NULL,
    TARGET_SCHEMA           VARCHAR(256) NOT NULL,
    TARGET_TABLE            VARCHAR(256) NOT NULL,
    PRIMARY_KEY_COLUMNS     VARCHAR(4096) NOT NULL,
    IS_ACTIVE               BOOLEAN DEFAULT TRUE,
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_LOADED_AT"            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_SOURCE_SYSTEM"        VARCHAR(100) DEFAULT 'TEMPORAL_ARCHIVE',
    "_SOURCE_TABLE"         VARCHAR(100) DEFAULT 'TABLE_REGISTRY',
    "_ROW_HASH"             VARCHAR(64),
    "_IS_CURRENT"           BOOLEAN DEFAULT TRUE,
    "_VALID_FROM"           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_VALID_TO"             VARCHAR(50) DEFAULT '9999-12-31 23:59:59'
)
COMMENT = 'Registry of tables to archive via SCD Type 2. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- POPULATE TABLE REGISTRY
-- =============================================================================

MERGE INTO TEMPORAL_ARCHIVE.ARCHIVE.TABLE_REGISTRY AS target
USING (
    SELECT * FROM (VALUES
        ('SNOWFLAKE', 'ACCOUNT_USAGE', 'QUERY_HISTORY', 'TEMPORAL_ARCHIVE', 'ACCOUNT_USAGE', 'QUERY_HISTORY_ARCHIVE', 'QUERY_ID'),
        ('SNOWFLAKE', 'ACCOUNT_USAGE', 'WAREHOUSE_METERING_HISTORY', 'TEMPORAL_ARCHIVE', 'ACCOUNT_USAGE', 'WAREHOUSE_METERING_HISTORY_ARCHIVE', 'START_TIME,WAREHOUSE_ID'),
        ('SNOWFLAKE', 'ACCOUNT_USAGE', 'STORAGE_USAGE', 'TEMPORAL_ARCHIVE', 'ACCOUNT_USAGE', 'STORAGE_USAGE_ARCHIVE', 'USAGE_DATE'),
        ('SNOWFLAKE', 'ACCOUNT_USAGE', 'LOGIN_HISTORY', 'TEMPORAL_ARCHIVE', 'ACCOUNT_USAGE', 'LOGIN_HISTORY_ARCHIVE', 'EVENT_ID'),
        ('SNOWFLAKE', 'ACCOUNT_USAGE', 'USERS', 'TEMPORAL_ARCHIVE', 'ACCOUNT_USAGE', 'USERS_ARCHIVE', 'USER_ID'),
        ('SNOWFLAKE', 'ACCOUNT_USAGE', 'ROLES', 'TEMPORAL_ARCHIVE', 'ACCOUNT_USAGE', 'ROLES_ARCHIVE', 'ROLE_ID'),
        ('SNOWFLAKE', 'ACCOUNT_USAGE', 'DATABASES', 'TEMPORAL_ARCHIVE', 'ACCOUNT_USAGE', 'DATABASES_ARCHIVE', 'DATABASE_ID'),
        ('SNOWFLAKE', 'ACCOUNT_USAGE', 'TABLES', 'TEMPORAL_ARCHIVE', 'ACCOUNT_USAGE', 'TABLES_ARCHIVE', 'TABLE_ID'),
        ('SNOWFLAKE', 'ORGANIZATION_USAGE', 'USAGE_IN_CURRENCY_DAILY', 'TEMPORAL_ARCHIVE', 'ORGANIZATION_USAGE', 'USAGE_IN_CURRENCY_DAILY_ARCHIVE', 'USAGE_DATE,ACCOUNT_LOCATOR,USAGE_TYPE'),
        ('SNOWFLAKE', 'ORGANIZATION_USAGE', 'CONTRACT_ITEMS', 'TEMPORAL_ARCHIVE', 'ORGANIZATION_USAGE', 'CONTRACT_ITEMS_ARCHIVE', 'CONTRACT_NUMBER,CONTRACT_ITEM_NUMBER')
    ) AS t(SOURCE_DATABASE, SOURCE_SCHEMA, SOURCE_VIEW, TARGET_DATABASE, TARGET_SCHEMA, TARGET_TABLE, PRIMARY_KEY_COLUMNS)
) AS source
ON target.SOURCE_DATABASE = source.SOURCE_DATABASE
   AND target.SOURCE_SCHEMA = source.SOURCE_SCHEMA
   AND target.SOURCE_VIEW = source.SOURCE_VIEW
WHEN NOT MATCHED THEN
    INSERT (SOURCE_DATABASE, SOURCE_SCHEMA, SOURCE_VIEW, TARGET_DATABASE, TARGET_SCHEMA, TARGET_TABLE, PRIMARY_KEY_COLUMNS)
    VALUES (source.SOURCE_DATABASE, source.SOURCE_SCHEMA, source.SOURCE_VIEW, source.TARGET_DATABASE, source.TARGET_SCHEMA, source.TARGET_TABLE, source.PRIMARY_KEY_COLUMNS);


-- =============================================================================
-- PROCEDURE 1: GET_SOURCE_COLUMNS
-- =============================================================================

CREATE OR REPLACE PROCEDURE TEMPORAL_ARCHIVE.ARCHIVE.GET_SOURCE_COLUMNS(
    p_source_database VARCHAR,
    p_source_schema VARCHAR,
    p_source_view VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    column_list VARCHAR DEFAULT '';
    v_sql VARCHAR;
    res RESULTSET;
    cur CURSOR FOR res;
BEGIN
    v_sql := 'SELECT COLUMN_NAME FROM ' || p_source_database || '.INFORMATION_SCHEMA.COLUMNS ' ||
             'WHERE TABLE_SCHEMA = ''' || p_source_schema || ''' ' ||
             'AND TABLE_NAME = ''' || p_source_view || ''' ' ||
             'AND COLUMN_NAME NOT IN (''_LOADED_AT'', ''_SOURCE_SYSTEM'', ''_SOURCE_TABLE'', ''_ROW_HASH'', ' ||
             '''_IS_CURRENT'', ''_VALID_FROM'', ''_VALID_TO'') ' ||
             'ORDER BY ORDINAL_POSITION';
    
    res := (EXECUTE IMMEDIATE :v_sql);
    OPEN cur;
    
    FOR rec IN cur DO
        IF (column_list != '') THEN
            column_list := column_list || ', ';
        END IF;
        column_list := column_list || '"' || rec.COLUMN_NAME || '"';
    END FOR;
    
    RETURN column_list;
END;
$$;

-- =============================================================================
-- PROCEDURE 2: GET_HASH_EXPRESSION
-- =============================================================================

CREATE OR REPLACE PROCEDURE TEMPORAL_ARCHIVE.ARCHIVE.GET_HASH_EXPRESSION(
    p_column_list VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    hash_expr VARCHAR;
    coalesce_parts VARCHAR DEFAULT '';
    columns ARRAY;
    col VARCHAR;
    i INTEGER;
BEGIN
    columns := SPLIT(REPLACE(REPLACE(p_column_list, '"', ''), ' ', ''), ',');
    
    FOR i IN 0 TO ARRAY_SIZE(columns) - 1 DO
        col := columns[i]::VARCHAR;
        IF (coalesce_parts != '') THEN
            coalesce_parts := coalesce_parts || ', ';
        END IF;
        coalesce_parts := coalesce_parts || 'COALESCE("' || col || '"::VARCHAR, '''')';
    END FOR;
    
    hash_expr := 'SHA2(CONCAT_WS(''|'', ' || coalesce_parts || '), 256)';
    RETURN hash_expr;
END;
$$;

-- =============================================================================
-- PROCEDURE 3: LOAD_TABLE_SCD
-- =============================================================================

CREATE OR REPLACE PROCEDURE TEMPORAL_ARCHIVE.ARCHIVE.LOAD_TABLE_SCD(
    p_source_database VARCHAR,
    p_source_schema VARCHAR,
    p_source_view VARCHAR,
    p_target_database VARCHAR,
    p_target_schema VARCHAR,
    p_target_table VARCHAR,
    p_primary_key_columns VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    source_fqn VARCHAR;
    target_fqn VARCHAR;
    source_columns VARCHAR;
    hash_expr VARCHAR;
    pk_columns ARRAY;
    join_condition VARCHAR DEFAULT '';
    pk_match_condition VARCHAR DEFAULT '';
    merge_sql VARCHAR;
    insert_sql VARCHAR;
    rows_updated INTEGER DEFAULT 0;
    rows_inserted INTEGER DEFAULT 0;
    i INTEGER;
    pk VARCHAR;
BEGIN
    source_fqn := p_source_database || '.' || p_source_schema || '.' || p_source_view;
    target_fqn := p_target_database || '.' || p_target_schema || '.' || p_target_table;
    
    CALL TEMPORAL_ARCHIVE.ARCHIVE.GET_SOURCE_COLUMNS(p_source_database, p_source_schema, p_source_view)
        INTO source_columns;
    
    CALL TEMPORAL_ARCHIVE.ARCHIVE.GET_HASH_EXPRESSION(source_columns) INTO hash_expr;
    
    pk_columns := SPLIT(REPLACE(p_primary_key_columns, ' ', ''), ',');
    
    FOR i IN 0 TO ARRAY_SIZE(pk_columns) - 1 DO
        pk := pk_columns[i]::VARCHAR;
        IF (join_condition != '') THEN
            join_condition := join_condition || ' AND ';
            pk_match_condition := pk_match_condition || ' AND ';
        END IF;
        join_condition := join_condition || 'target."' || pk || '" = source."' || pk || '"';
        pk_match_condition := pk_match_condition || 'tgt."' || pk || '" = src."' || pk || '"';
    END FOR;
    
    merge_sql := '
        MERGE INTO ' || target_fqn || ' AS target
        USING (
            SELECT 
                ' || source_columns || ',
                ' || hash_expr || ' AS _ROW_HASH_NEW,
                CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS _LOAD_TS
            FROM ' || source_fqn || '
        ) AS source
        ON ' || join_condition || ' AND target."_IS_CURRENT" = TRUE
        WHEN MATCHED AND target."_ROW_HASH" != source._ROW_HASH_NEW THEN
            UPDATE SET
                "_IS_CURRENT" = FALSE,
                "_VALID_TO" = source._LOAD_TS::VARCHAR
    ';
    
    EXECUTE IMMEDIATE merge_sql;
    rows_updated := SQLROWCOUNT;
    
    insert_sql := '
        INSERT INTO ' || target_fqn || ' (
            ' || source_columns || ',
            "_LOADED_AT",
            "_SOURCE_SYSTEM",
            "_SOURCE_TABLE",
            "_ROW_HASH",
            "_IS_CURRENT",
            "_VALID_FROM",
            "_VALID_TO"
        )
        SELECT 
            ' || source_columns || ',
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
            ''' || p_source_database || '_' || p_source_schema || ''',
            ''' || p_source_view || ''',
            ' || hash_expr || ',
            TRUE,
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
            ''9999-12-31 23:59:59''
        FROM ' || source_fqn || ' src
        WHERE NOT EXISTS (
            SELECT 1 FROM ' || target_fqn || ' tgt
            WHERE ' || pk_match_condition || '
              AND tgt."_IS_CURRENT" = TRUE
              AND tgt."_ROW_HASH" = ' || hash_expr || '
        )
    ';
    
    EXECUTE IMMEDIATE insert_sql;
    rows_inserted := SQLROWCOUNT;
    
    RETURN OBJECT_CONSTRUCT(
        'source', source_fqn,
        'target', target_fqn,
        'rows_updated', rows_updated,
        'rows_inserted', rows_inserted,
        'status', 'success',
        'timestamp', CURRENT_TIMESTAMP()::VARCHAR
    );
    
EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT(
            'source', source_fqn,
            'target', target_fqn,
            'status', 'error',
            'error', SQLERRM,
            'timestamp', CURRENT_TIMESTAMP()::VARCHAR
        );
END;
$$;

-- =============================================================================
-- PROCEDURE 4: RUN_SCD_LOAD (Main procedure - called by Tasks and Streamlit)
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
BEGIN
    start_time := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    
    FOR rec IN (
        SELECT 
            SOURCE_DATABASE,
            SOURCE_SCHEMA,
            SOURCE_VIEW,
            TARGET_DATABASE,
            TARGET_SCHEMA,
            TARGET_TABLE,
            PRIMARY_KEY_COLUMNS
        FROM TEMPORAL_ARCHIVE.ARCHIVE.TABLE_REGISTRY
        WHERE IS_ACTIVE = TRUE
    )
    DO
        CALL TEMPORAL_ARCHIVE.ARCHIVE.LOAD_TABLE_SCD(
            rec.SOURCE_DATABASE,
            rec.SOURCE_SCHEMA,
            rec.SOURCE_VIEW,
            rec.TARGET_DATABASE,
            rec.TARGET_SCHEMA,
            rec.TARGET_TABLE,
            rec.PRIMARY_KEY_COLUMNS
        ) INTO table_result;
        
        results := ARRAY_APPEND(results, table_result);
        
        IF (table_result:status = 'success') THEN
            total_updated := total_updated + table_result:rows_updated::INTEGER;
            total_inserted := total_inserted + table_result:rows_inserted::INTEGER;
        ELSE
            error_count := error_count + 1;
        END IF;
    END FOR;
    
    end_time := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    
    INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG (
        SOURCE_TABLE, TARGET_TABLE, ROWS_UPDATED, ROWS_INSERTED, 
        STATUS, DURATION_SECONDS, "_ROW_HASH"
    )
    VALUES (
        'ALL_TABLES',
        'ALL_TABLES',
        total_updated,
        total_inserted,
        CASE WHEN error_count = 0 THEN 'SUCCESS' ELSE 'PARTIAL_FAILURE' END,
        TIMESTAMPDIFF('SECOND', start_time, end_time),
        SHA2('ALL_TABLES' || total_updated || total_inserted, 256)
    );
    
    RETURN OBJECT_CONSTRUCT(
        'start_time', start_time::VARCHAR,
        'end_time', end_time::VARCHAR,
        'duration_seconds', TIMESTAMPDIFF('SECOND', start_time, end_time),
        'tables_processed', ARRAY_SIZE(results),
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
    COMMENT = 'Morning SCD load at 6 AM.'
AS
    CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();

CREATE OR REPLACE TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING
    WAREHOUSE = TEMPORAL_ARCHIVE_WH
    SCHEDULE = 'USING CRON 0 18 * * * America/New_York'
    COMMENT = 'Evening SCD load at 6 PM.'
AS
    CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();

ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_MORNING RESUME;

ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING RESUME;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

SHOW TASKS IN SCHEMA TEMPORAL_ARCHIVE.ARCHIVE;

SELECT 'SCD load setup complete. Next: Run 03_semantic_layer.sql' AS STATUS;
