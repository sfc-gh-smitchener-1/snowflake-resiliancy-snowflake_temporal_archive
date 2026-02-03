/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - SCD TYPE 2 LOAD
================================================================================

Creates the SCD procedures and scheduled Tasks.
Views are dynamically discovered from SNOWFLAKE.ACCOUNT_USAGE and 
SNOWFLAKE.ORGANIZATION_USAGE at runtime - no hardcoded registry needed.

Run this script in a Snowflake Worksheet after 01_initial_setup.sql.

Reference: https://docs.snowflake.com/en/user-guide/backups
================================================================================
*/

USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE SCHEMA ARCHIVE;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

-- =============================================================================
-- PRIMARY KEY MAPPING TABLE
-- Maps source views to their primary key columns for SCD Type 2 processing.
-- Only views with known PKs will be processed; others are logged and skipped.
-- =============================================================================

CREATE TABLE IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE.VIEW_PRIMARY_KEYS (
    SOURCE_SCHEMA           VARCHAR(256) NOT NULL,
    SOURCE_VIEW             VARCHAR(256) NOT NULL,
    PRIMARY_KEY_COLUMNS     VARCHAR(4096) NOT NULL,
    IS_ACTIVE               BOOLEAN DEFAULT TRUE,
    CREATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (SOURCE_SCHEMA, SOURCE_VIEW)
)
COMMENT = 'Primary key mappings for dynamic view discovery. Add entries here to include new views.';

-- =============================================================================
-- SEED PRIMARY KEY MAPPINGS
-- Add known primary keys for ACCOUNT_USAGE and ORGANIZATION_USAGE views.
-- New views will be discovered automatically but need PK mapping to be processed.
-- =============================================================================

MERGE INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_PRIMARY_KEYS AS target
USING (
    SELECT * FROM (VALUES
        -- ACCOUNT_USAGE views
        ('ACCOUNT_USAGE', 'ACCESS_HISTORY', 'QUERY_ID'),
        ('ACCOUNT_USAGE', 'AGGREGATE_QUERY_HISTORY', 'QUERY_PARAMETERIZED_HASH,INTERVAL_START_TIME,WAREHOUSE_NAME'),
        ('ACCOUNT_USAGE', 'AGGREGATE_SPENDING_HISTORY', 'USAGE_TYPE,START_TIME'),
        ('ACCOUNT_USAGE', 'AUTOMATIC_CLUSTERING_HISTORY', 'START_TIME,TABLE_ID'),
        ('ACCOUNT_USAGE', 'CLASS_INSTANCES', 'INSTANCE_ID'),
        ('ACCOUNT_USAGE', 'CLASSES', 'CLASS_ID'),
        ('ACCOUNT_USAGE', 'COLUMNS', 'COLUMN_ID'),
        ('ACCOUNT_USAGE', 'COPY_HISTORY', 'FILE_NAME,STAGE_LOCATION,TABLE_ID,LAST_LOAD_TIME'),
        ('ACCOUNT_USAGE', 'DATABASE_REPLICATION_USAGE_HISTORY', 'START_TIME,DATABASE_NAME'),
        ('ACCOUNT_USAGE', 'DATABASE_STORAGE_USAGE_HISTORY', 'USAGE_DATE,DATABASE_ID'),
        ('ACCOUNT_USAGE', 'DATABASES', 'DATABASE_ID'),
        ('ACCOUNT_USAGE', 'DATA_TRANSFER_HISTORY', 'START_TIME,SOURCE_CLOUD,SOURCE_REGION,TARGET_CLOUD,TARGET_REGION,TRANSFER_TYPE'),
        ('ACCOUNT_USAGE', 'EVENT_USAGE_HISTORY', 'EVENT_TIMESTAMP,EVENT_ID'),
        ('ACCOUNT_USAGE', 'FILE_FORMATS', 'FILE_FORMAT_ID'),
        ('ACCOUNT_USAGE', 'FUNCTIONS', 'FUNCTION_ID'),
        ('ACCOUNT_USAGE', 'GRANTS_TO_ROLES', 'CREATED_ON,PRIVILEGE,GRANTED_ON,NAME,GRANTED_TO,GRANTEE_NAME'),
        ('ACCOUNT_USAGE', 'GRANTS_TO_USERS', 'CREATED_ON,ROLE,GRANTED_TO,GRANTEE_NAME'),
        ('ACCOUNT_USAGE', 'HYBRID_TABLE_USAGE_HISTORY', 'START_TIME,TABLE_ID'),
        ('ACCOUNT_USAGE', 'LOAD_HISTORY', 'TABLE_ID,FILE_NAME,LAST_LOAD_TIME'),
        ('ACCOUNT_USAGE', 'LOCK_WAIT_HISTORY', 'QUERY_ID'),
        ('ACCOUNT_USAGE', 'LOGIN_HISTORY', 'EVENT_ID'),
        ('ACCOUNT_USAGE', 'MASKING_POLICIES', 'POLICY_ID'),
        ('ACCOUNT_USAGE', 'MATERIALIZED_VIEW_REFRESH_HISTORY', 'START_TIME,TABLE_ID'),
        ('ACCOUNT_USAGE', 'METERING_DAILY_HISTORY', 'USAGE_DATE,SERVICE_TYPE'),
        ('ACCOUNT_USAGE', 'METERING_HISTORY', 'START_TIME,SERVICE_TYPE'),
        ('ACCOUNT_USAGE', 'OBJECT_DEPENDENCIES', 'REFERENCING_OBJECT_ID,REFERENCED_OBJECT_ID'),
        ('ACCOUNT_USAGE', 'PASSWORD_POLICIES', 'PASSWORD_POLICY_ID'),
        ('ACCOUNT_USAGE', 'PIPES', 'PIPE_ID'),
        ('ACCOUNT_USAGE', 'PIPE_USAGE_HISTORY', 'START_TIME,PIPE_ID'),
        ('ACCOUNT_USAGE', 'POLICY_REFERENCES', 'POLICY_ID,REF_ENTITY_DOMAIN,REF_ENTITY_NAME,REF_COLUMN_NAME'),
        ('ACCOUNT_USAGE', 'PROCEDURES', 'PROCEDURE_ID'),
        ('ACCOUNT_USAGE', 'QUERY_ACCELERATION_HISTORY', 'START_TIME,QUERY_ID'),
        ('ACCOUNT_USAGE', 'QUERY_HISTORY', 'QUERY_ID'),
        ('ACCOUNT_USAGE', 'REFERENTIAL_CONSTRAINTS', 'CONSTRAINT_ID'),
        ('ACCOUNT_USAGE', 'REPLICATION_GROUP_REFRESH_HISTORY', 'PHASE_NAME,START_TIME,REPLICATION_GROUP_NAME'),
        ('ACCOUNT_USAGE', 'REPLICATION_GROUP_USAGE_HISTORY', 'START_TIME,REPLICATION_GROUP_NAME'),
        ('ACCOUNT_USAGE', 'REPLICATION_USAGE_HISTORY', 'START_TIME,DATABASE_NAME'),
        ('ACCOUNT_USAGE', 'ROLES', 'ROLE_ID'),
        ('ACCOUNT_USAGE', 'ROW_ACCESS_POLICIES', 'POLICY_ID'),
        ('ACCOUNT_USAGE', 'SCHEMATA', 'SCHEMA_ID'),
        ('ACCOUNT_USAGE', 'SEARCH_OPTIMIZATION_HISTORY', 'START_TIME,TABLE_ID'),
        ('ACCOUNT_USAGE', 'SEQUENCES', 'SEQUENCE_ID'),
        ('ACCOUNT_USAGE', 'SERVERLESS_TASK_HISTORY', 'START_TIME,TASK_ID'),
        ('ACCOUNT_USAGE', 'SERVICES', 'SERVICE_ID'),
        ('ACCOUNT_USAGE', 'SESSION_POLICIES', 'SESSION_POLICY_ID'),
        ('ACCOUNT_USAGE', 'SESSIONS', 'SESSION_ID'),
        ('ACCOUNT_USAGE', 'SNOWPARK_CONTAINER_SERVICES_HISTORY', 'START_TIME,COMPUTE_POOL_NAME'),
        ('ACCOUNT_USAGE', 'SNOWPIPE_STREAMING_CLIENT_HISTORY', 'START_TIME,PIPE_NAME,CLIENT_NAME'),
        ('ACCOUNT_USAGE', 'SNOWPIPE_STREAMING_FILE_MIGRATION_HISTORY', 'START_TIME,PIPE_NAME'),
        ('ACCOUNT_USAGE', 'STAGE_STORAGE_USAGE_HISTORY', 'USAGE_DATE,STAGE_ID'),
        ('ACCOUNT_USAGE', 'STAGES', 'STAGE_ID'),
        ('ACCOUNT_USAGE', 'STORAGE_USAGE', 'USAGE_DATE'),
        ('ACCOUNT_USAGE', 'TABLE_CONSTRAINTS', 'CONSTRAINT_ID'),
        ('ACCOUNT_USAGE', 'TABLE_STORAGE_METRICS', 'ID'),
        ('ACCOUNT_USAGE', 'TABLES', 'TABLE_ID'),
        ('ACCOUNT_USAGE', 'TAGS', 'TAG_ID'),
        ('ACCOUNT_USAGE', 'TAG_REFERENCES', 'TAG_ID,OBJECT_ID,COLUMN_NAME'),
        ('ACCOUNT_USAGE', 'TASK_HISTORY', 'QUERY_ID'),
        ('ACCOUNT_USAGE', 'TASK_VERSIONS', 'TASK_ID,TASK_GRAPH_VERSION'),
        ('ACCOUNT_USAGE', 'USERS', 'USER_ID'),
        ('ACCOUNT_USAGE', 'VIEWS', 'TABLE_ID'),
        ('ACCOUNT_USAGE', 'WAREHOUSE_EVENTS_HISTORY', 'TIMESTAMP,WAREHOUSE_ID,EVENT_NAME'),
        ('ACCOUNT_USAGE', 'WAREHOUSE_LOAD_HISTORY', 'START_TIME,WAREHOUSE_ID'),
        ('ACCOUNT_USAGE', 'WAREHOUSE_METERING_HISTORY', 'START_TIME,WAREHOUSE_ID'),
        -- ORGANIZATION_USAGE views
        ('ORGANIZATION_USAGE', 'CONTRACT_ITEMS', 'CONTRACT_NUMBER,CONTRACT_ITEM_NUMBER'),
        ('ORGANIZATION_USAGE', 'LISTING_AUTO_FULFILLMENT_DATABASE_STORAGE_DAILY', 'USAGE_DATE,LISTING_GLOBAL_NAME,DATABASE_NAME'),
        ('ORGANIZATION_USAGE', 'LISTING_AUTO_FULFILLMENT_REFRESH_DAILY', 'USAGE_DATE,LISTING_GLOBAL_NAME,DATABASE_NAME'),
        ('ORGANIZATION_USAGE', 'LISTING_EVENTS_DAILY', 'EVENT_DATE,LISTING_GLOBAL_NAME,LISTING_DISPLAY_NAME,EVENT_TYPE,CONSUMER_ACCOUNT_LOCATOR,CONSUMER_REGION'),
        ('ORGANIZATION_USAGE', 'LISTING_TELEMETRY_DAILY', 'USAGE_DATE,LISTING_GLOBAL_NAME,QUERY_TYPE,DATABASE_NAME,CONSUMER_ACCOUNT_LOCATOR'),
        ('ORGANIZATION_USAGE', 'MARKETPLACE_DISBURSEMENT_REPORT', 'USAGE_MONTH,DATA_PRODUCT_NAME,CHARGE_TYPE,CURRENCY,CONSUMER_ACCOUNT_LOCATOR'),
        ('ORGANIZATION_USAGE', 'MARKETPLACE_PAID_USAGE_DAILY', 'USAGE_DATE,LISTING_GLOBAL_NAME,CONSUMER_ACCOUNT_LOCATOR,CHARGE_TYPE'),
        ('ORGANIZATION_USAGE', 'MARKETPLACE_PURCHASE_EVENTS', 'EVENT_TIMESTAMP,EVENT_ID'),
        ('ORGANIZATION_USAGE', 'METERING_DAILY_HISTORY', 'USAGE_DATE,ACCOUNT_LOCATOR,SERVICE_TYPE'),
        ('ORGANIZATION_USAGE', 'RATE_SHEET_DAILY', 'DATE,USAGE_TYPE,CURRENCY,ACCOUNT_LOCATOR'),
        ('ORGANIZATION_USAGE', 'REMAINING_BALANCE_DAILY', 'DATE,CONTRACT_NUMBER,CURRENCY'),
        ('ORGANIZATION_USAGE', 'STORAGE_DAILY_HISTORY', 'USAGE_DATE,ACCOUNT_LOCATOR'),
        ('ORGANIZATION_USAGE', 'USAGE_IN_CURRENCY_DAILY', 'USAGE_DATE,ACCOUNT_LOCATOR,USAGE_TYPE')
    ) AS t(SOURCE_SCHEMA, SOURCE_VIEW, PRIMARY_KEY_COLUMNS)
) AS source
ON target.SOURCE_SCHEMA = source.SOURCE_SCHEMA
   AND target.SOURCE_VIEW = source.SOURCE_VIEW
WHEN NOT MATCHED THEN
    INSERT (SOURCE_SCHEMA, SOURCE_VIEW, PRIMARY_KEY_COLUMNS)
    VALUES (source.SOURCE_SCHEMA, source.SOURCE_VIEW, source.PRIMARY_KEY_COLUMNS)
WHEN MATCHED AND target.PRIMARY_KEY_COLUMNS != source.PRIMARY_KEY_COLUMNS THEN
    UPDATE SET PRIMARY_KEY_COLUMNS = source.PRIMARY_KEY_COLUMNS, UPDATED_AT = CURRENT_TIMESTAMP();


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
-- PROCEDURE 3: CREATE_TARGET_TABLE
-- Dynamically creates the target archive table if it doesn't exist
-- =============================================================================

CREATE OR REPLACE PROCEDURE TEMPORAL_ARCHIVE.ARCHIVE.CREATE_TARGET_TABLE(
    p_source_database VARCHAR,
    p_source_schema VARCHAR,
    p_source_view VARCHAR,
    p_target_database VARCHAR,
    p_target_schema VARCHAR,
    p_target_table VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    target_fqn VARCHAR;
    source_fqn VARCHAR;
    create_sql VARCHAR;
    table_exists INTEGER;
    check_sql VARCHAR;
    res RESULTSET;
BEGIN
    target_fqn := p_target_database || '.' || p_target_schema || '.' || p_target_table;
    source_fqn := p_source_database || '.' || p_source_schema || '.' || p_source_view;
    
    -- Check if table exists
    check_sql := 'SELECT COUNT(*) FROM ' || p_target_database || '.INFORMATION_SCHEMA.TABLES ' ||
                 'WHERE TABLE_SCHEMA = ''' || p_target_schema || ''' ' ||
                 'AND TABLE_NAME = ''' || p_target_table || '''';
    
    res := (EXECUTE IMMEDIATE :check_sql);
    
    FOR rec IN res DO
        table_exists := rec."COUNT(*)";
    END FOR;
    
    IF (table_exists = 0) THEN
        -- Create schema if not exists
        EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS ' || p_target_database || '.' || p_target_schema;
        
        -- Create table from source with SCD columns
        create_sql := 'CREATE TABLE ' || target_fqn || ' AS 
            SELECT 
                src.*,
                CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_LOADED_AT",
                ''' || p_source_database || '_' || p_source_schema || ''' AS "_SOURCE_SYSTEM",
                ''' || p_source_view || ''' AS "_SOURCE_TABLE",
                '''' AS "_ROW_HASH",
                TRUE AS "_IS_CURRENT",
                CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_VALID_FROM",
                ''9999-12-31 23:59:59'' AS "_VALID_TO"
            FROM ' || source_fqn || ' src
            WHERE 1=0';  -- Empty table, just get structure
        
        EXECUTE IMMEDIATE create_sql;
        RETURN 'CREATED';
    END IF;
    
    RETURN 'EXISTS';
END;
$$;

-- =============================================================================
-- PROCEDURE 4: LOAD_TABLE_SCD
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
    table_status VARCHAR;
BEGIN
    source_fqn := p_source_database || '.' || p_source_schema || '.' || p_source_view;
    target_fqn := p_target_database || '.' || p_target_schema || '.' || p_target_table;
    
    -- Create target table if not exists
    CALL TEMPORAL_ARCHIVE.ARCHIVE.CREATE_TARGET_TABLE(
        p_source_database, p_source_schema, p_source_view,
        p_target_database, p_target_schema, p_target_table
    ) INTO table_status;
    
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
        'table_status', table_status,
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
-- PROCEDURE 5: RUN_SCD_LOAD (Main procedure - DYNAMIC VIEW DISCOVERY)
-- Discovers all views from SNOWFLAKE.ACCOUNT_USAGE and ORGANIZATION_USAGE
-- at runtime and processes those with known primary keys.
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
    skipped_views ARRAY DEFAULT ARRAY_CONSTRUCT();
    table_result VARIANT;
    total_updated INTEGER DEFAULT 0;
    total_inserted INTEGER DEFAULT 0;
    error_count INTEGER DEFAULT 0;
    views_processed INTEGER DEFAULT 0;
    views_skipped INTEGER DEFAULT 0;
    v_target_table VARCHAR;
    v_pk_columns VARCHAR;
    v_source_schema VARCHAR;
    v_source_view VARCHAR;
    v_is_active BOOLEAN;
    v_has_pk BOOLEAN;
BEGIN
    start_time := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    
    -- ==========================================================================
    -- PHASE 1: Process views that HAVE primary key mappings
    -- Query from the PK mapping table directly (it already has what we need)
    -- ==========================================================================
    
    FOR rec IN (
        SELECT 
            pk.SOURCE_SCHEMA,
            pk.SOURCE_VIEW,
            pk.PRIMARY_KEY_COLUMNS,
            pk.IS_ACTIVE
        FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_PRIMARY_KEYS pk
        WHERE pk.SOURCE_SCHEMA IN ('ACCOUNT_USAGE', 'ORGANIZATION_USAGE')
          AND EXISTS (
              SELECT 1 FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS v
              WHERE v.TABLE_SCHEMA = pk.SOURCE_SCHEMA
                AND v.TABLE_NAME = pk.SOURCE_VIEW
          )
        ORDER BY pk.SOURCE_SCHEMA, pk.SOURCE_VIEW
    )
    DO
        v_source_schema := rec.SOURCE_SCHEMA;
        v_source_view := rec.SOURCE_VIEW;
        v_pk_columns := rec.PRIMARY_KEY_COLUMNS;
        v_is_active := rec.IS_ACTIVE;
        
        -- Skip inactive views
        IF (v_is_active = FALSE) THEN
            skipped_views := ARRAY_APPEND(skipped_views, OBJECT_CONSTRUCT(
                'schema', v_source_schema,
                'view', v_source_view,
                'reason', 'Marked as inactive'
            ));
            views_skipped := views_skipped + 1;
        ELSE
            -- Construct target table name
            v_target_table := v_source_view || '_ARCHIVE';
            
            -- Call the SCD load procedure
            CALL TEMPORAL_ARCHIVE.ARCHIVE.LOAD_TABLE_SCD(
                'SNOWFLAKE',
                v_source_schema,
                v_source_view,
                'TEMPORAL_ARCHIVE',
                v_source_schema,
                v_target_table,
                v_pk_columns
            ) INTO table_result;
            
            results := ARRAY_APPEND(results, table_result);
            views_processed := views_processed + 1;
            
            IF (table_result:status = 'success') THEN
                total_updated := total_updated + table_result:rows_updated::INTEGER;
                total_inserted := total_inserted + table_result:rows_inserted::INTEGER;
            ELSE
                error_count := error_count + 1;
            END IF;
        END IF;
    END FOR;
    
    -- ==========================================================================
    -- PHASE 2: Log views that DON'T have primary key mappings
    -- Query INFORMATION_SCHEMA but use TABLE_SCHEMA and TABLE_NAME directly
    -- ==========================================================================
    
    FOR rec IN (
        SELECT 
            v.TABLE_SCHEMA,
            v.TABLE_NAME
        FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS v
        WHERE v.TABLE_SCHEMA IN ('ACCOUNT_USAGE', 'ORGANIZATION_USAGE')
          AND NOT EXISTS (
              SELECT 1 FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_PRIMARY_KEYS pk
              WHERE pk.SOURCE_SCHEMA = v.TABLE_SCHEMA
                AND pk.SOURCE_VIEW = v.TABLE_NAME
          )
        ORDER BY v.TABLE_SCHEMA, v.TABLE_NAME
    )
    DO
        skipped_views := ARRAY_APPEND(skipped_views, OBJECT_CONSTRUCT(
            'schema', rec.TABLE_SCHEMA,
            'view', rec.TABLE_NAME,
            'reason', 'No primary key mapping defined'
        ));
        views_skipped := views_skipped + 1;
    END FOR;
    
    end_time := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    
    -- Log the run
    INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG (
        SOURCE_TABLE, TARGET_TABLE, ROWS_UPDATED, ROWS_INSERTED, 
        STATUS, DURATION_SECONDS, "_ROW_HASH"
    )
    VALUES (
        'DYNAMIC_DISCOVERY',
        'ALL_TABLES',
        total_updated,
        total_inserted,
        CASE WHEN error_count = 0 THEN 'SUCCESS' ELSE 'PARTIAL_FAILURE' END,
        TIMESTAMPDIFF('SECOND', start_time, end_time),
        SHA2('DYNAMIC' || views_processed || total_updated || total_inserted, 256)
    );
    
    RETURN OBJECT_CONSTRUCT(
        'start_time', start_time::VARCHAR,
        'end_time', end_time::VARCHAR,
        'duration_seconds', TIMESTAMPDIFF('SECOND', start_time, end_time),
        'views_discovered', views_processed + views_skipped,
        'views_processed', views_processed,
        'views_skipped', views_skipped,
        'total_updated', total_updated,
        'total_inserted', total_inserted,
        'error_count', error_count,
        'table_results', results,
        'skipped_views', skipped_views
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

-- Show how many views are available vs mapped
SELECT 
    'Views in SNOWFLAKE schemas' AS METRIC,
    (SELECT COUNT(*) FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS 
     WHERE TABLE_SCHEMA IN ('ACCOUNT_USAGE', 'ORGANIZATION_USAGE')) AS COUNT
UNION ALL
SELECT 
    'Views with PK mapping',
    (SELECT COUNT(*) FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_PRIMARY_KEYS WHERE IS_ACTIVE = TRUE);

SELECT 'SCD load setup complete. Next: Run 03_semantic_layer.sql' AS STATUS;
