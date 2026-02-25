/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - SCD TYPE 2 LOAD (OPTIMIZED WITH DELTA STRATEGIES)
================================================================================

Dynamically discovers ALL views from SNOWFLAKE.ACCOUNT_USAGE and 
SNOWFLAKE.ORGANIZATION_USAGE and archives them using SCD Type 2 with:
  - Surrogate key (_ARCHIVE_ID) as primary key
  - Row hash (SHA-256) for WORM compliance and change detection
  - Three load strategies to minimize redundant computation:
    * APPEND_ONLY   - Timestamp watermark delta (event/history tables)
    * SOFT_DELETE_MUTABLE - Full SCD2 with temp table optimization (catalog objects)
    * FULL_COMPARE  - Full hash comparison fallback (no natural key/timestamp)

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
    RUN_ID                  NUMBER,
    SOURCE_TABLE            VARCHAR(512),
    TARGET_TABLE            VARCHAR(512),
    ROWS_UPDATED            NUMBER,
    ROWS_INSERTED           NUMBER,
    STATUS                  VARCHAR(50),
    ERROR_MESSAGE           VARCHAR(4096),
    DURATION_SECONDS        NUMBER(10,2),
    LOAD_STRATEGY           VARCHAR(30),
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    "_ROW_HASH"             VARCHAR(64)
)
COMMENT = 'Log of SCD load executions - per-view detail rows grouped by RUN_ID';

-- Add columns if table already exists (idempotent migration)
ALTER TABLE TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG ADD COLUMN IF NOT EXISTS RUN_ID NUMBER;
ALTER TABLE TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG ADD COLUMN IF NOT EXISTS LOAD_STRATEGY VARCHAR(30);

-- =============================================================================
-- WATERMARK STATE TABLE
-- Tracks the last loaded watermark value per view for delta-based loading
-- =============================================================================

CREATE TABLE IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE.WATERMARK_STATE (
    SOURCE_SCHEMA       VARCHAR NOT NULL,
    SOURCE_VIEW         VARCHAR NOT NULL,
    LAST_WATERMARK_VALUE VARCHAR,
    LAST_LOADED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    ROWS_LOADED         INTEGER DEFAULT 0,
    PRIMARY KEY (SOURCE_SCHEMA, SOURCE_VIEW)
)
COMMENT = 'Tracks watermark values for delta-based incremental loading';

-- =============================================================================
-- VIEW REGISTRY: All known views with load strategy classification
-- =============================================================================
-- LOAD_STRATEGY values:
--   APPEND_ONLY        - Immutable event/history data. Use watermark to load only new rows.
--   SOFT_DELETE_MUTABLE - Catalog objects that can change. Full SCD2 with temp table optimization.
--   FULL_COMPARE       - No natural key or timestamp. Full hash comparison on every run.
--
-- WATERMARK_COLUMN: The column used to detect new/changed data (timestamp or date).
-- UNIQUE_KEY_COLUMN: Natural unique identifier if one exists (informational).
-- =============================================================================

CREATE OR REPLACE TABLE TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (
    SOURCE_SCHEMA       VARCHAR(100),
    SOURCE_VIEW         VARCHAR(200),
    IS_ACTIVE           BOOLEAN DEFAULT TRUE,
    LOAD_STRATEGY       VARCHAR(30) DEFAULT 'FULL_COMPARE',
    WATERMARK_COLUMN    VARCHAR(100) DEFAULT NULL,
    UNIQUE_KEY_COLUMN   VARCHAR(100) DEFAULT NULL,
    CREATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Registry of all known views to archive from SNOWFLAKE database with load strategy classification';

TRUNCATE TABLE TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY;

-- =============================================================================
-- ACCOUNT_USAGE: APPEND_ONLY views (immutable event/history data)
-- =============================================================================
INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, LOAD_STRATEGY, WATERMARK_COLUMN, UNIQUE_KEY_COLUMN) VALUES
-- Query and access history
('ACCOUNT_USAGE', 'QUERY_HISTORY', 'APPEND_ONLY', 'START_TIME', 'QUERY_ID'),
('ACCOUNT_USAGE', 'ACCESS_HISTORY', 'APPEND_ONLY', 'QUERY_START_TIME', 'QUERY_ID'),
('ACCOUNT_USAGE', 'QUERY_ATTRIBUTION_HISTORY', 'APPEND_ONLY', 'QUERY_START_TIME', 'QUERY_ID'),
('ACCOUNT_USAGE', 'EXTERNAL_ACCESS_HISTORY', 'APPEND_ONLY', 'QUERY_ID', 'QUERY_ID'),
('ACCOUNT_USAGE', 'AGGREGATE_QUERY_HISTORY', 'APPEND_ONLY', 'INTERVAL_START_TIME', NULL),
('ACCOUNT_USAGE', 'AGGREGATE_ACCESS_HISTORY', 'APPEND_ONLY', 'INTERVAL_START_TIME', NULL),
-- Login and session history
('ACCOUNT_USAGE', 'LOGIN_HISTORY', 'APPEND_ONLY', 'EVENT_TIMESTAMP', 'EVENT_ID'),
('ACCOUNT_USAGE', 'SESSIONS', 'APPEND_ONLY', 'CREATED_ON', 'SESSION_ID'),
-- Warehouse history
('ACCOUNT_USAGE', 'WAREHOUSE_EVENTS_HISTORY', 'APPEND_ONLY', 'TIMESTAMP', NULL),
('ACCOUNT_USAGE', 'WAREHOUSE_LOAD_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'WAREHOUSE_METERING_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
-- Metering and billing
('ACCOUNT_USAGE', 'METERING_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'METERING_DAILY_HISTORY', 'APPEND_ONLY', 'USAGE_DATE', NULL),
-- Task history
('ACCOUNT_USAGE', 'TASK_HISTORY', 'APPEND_ONLY', 'SCHEDULED_TIME', 'QUERY_ID'),
('ACCOUNT_USAGE', 'COMPLETE_TASK_GRAPHS', 'APPEND_ONLY', 'SCHEDULED_TIME', NULL),
('ACCOUNT_USAGE', 'SERVERLESS_TASK_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
-- Data loading history
('ACCOUNT_USAGE', 'COPY_HISTORY', 'APPEND_ONLY', 'LAST_LOAD_TIME', NULL),
('ACCOUNT_USAGE', 'LOAD_HISTORY', 'APPEND_ONLY', 'LAST_LOAD_TIME', NULL),
('ACCOUNT_USAGE', 'PIPE_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
-- Storage and usage daily
('ACCOUNT_USAGE', 'DATABASE_STORAGE_USAGE_HISTORY', 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ACCOUNT_USAGE', 'STORAGE_USAGE', 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ACCOUNT_USAGE', 'STAGE_STORAGE_USAGE_HISTORY', 'APPEND_ONLY', 'USAGE_DATE', NULL),
-- Replication history
('ACCOUNT_USAGE', 'DATABASE_REPLICATION_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'REPLICATION_GROUP_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'REPLICATION_GROUP_REFRESH_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'REPLICATION_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
-- Alert history
('ACCOUNT_USAGE', 'ALERT_HISTORY', 'APPEND_ONLY', 'SCHEDULED_TIME', NULL),
-- Clustering, search, materialized view refresh
('ACCOUNT_USAGE', 'AUTOMATIC_CLUSTERING_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'SEARCH_OPTIMIZATION_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'MATERIALIZED_VIEW_REFRESH_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
-- Data transfer
('ACCOUNT_USAGE', 'DATA_TRANSFER_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
-- Dynamic table refresh
('ACCOUNT_USAGE', 'DYNAMIC_TABLE_REFRESH_HISTORY', 'APPEND_ONLY', 'REFRESH_START_TIME', NULL),
-- Cortex and AI usage
('ACCOUNT_USAGE', 'CORTEX_FUNCTIONS_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'CORTEX_SEARCH_DAILY_USAGE_HISTORY', 'APPEND_ONLY', 'USAGE_DATE', NULL),
-- Container and streaming
('ACCOUNT_USAGE', 'EVENT_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'SNOWPARK_CONTAINER_SERVICES_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'SNOWPIPE_STREAMING_CLIENT_HISTORY', 'APPEND_ONLY', 'EVENT_TIMESTAMP', NULL),
-- Other history
('ACCOUNT_USAGE', 'HYBRID_TABLE_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'QUERY_ACCELERATION_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'LOCK_WAIT_HISTORY', 'APPEND_ONLY', 'REQUESTED_AT', NULL),
('ACCOUNT_USAGE', 'INGRESS_NETWORK_ACCESS_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'TABLE_QUERY_PRUNING_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'TABLE_PRUNING_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'TABLE_DML_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'CATALOG_LINKED_DATABASE_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL);

-- =============================================================================
-- ACCOUNT_USAGE: SOFT_DELETE_MUTABLE views (catalog objects that change)
-- =============================================================================
INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, LOAD_STRATEGY, WATERMARK_COLUMN, UNIQUE_KEY_COLUMN) VALUES
-- Core catalog objects
('ACCOUNT_USAGE', 'COLUMNS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'COLUMN_ID'),
('ACCOUNT_USAGE', 'TABLES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'TABLE_ID'),
('ACCOUNT_USAGE', 'VIEWS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'TABLE_ID'),
('ACCOUNT_USAGE', 'DATABASES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'DATABASE_ID'),
('ACCOUNT_USAGE', 'SCHEMATA', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'SCHEMA_ID'),
('ACCOUNT_USAGE', 'FUNCTIONS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'FUNCTION_ID'),
('ACCOUNT_USAGE', 'PROCEDURES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', NULL),
('ACCOUNT_USAGE', 'SEQUENCES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'SEQUENCE_ID'),
('ACCOUNT_USAGE', 'FILE_FORMATS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'FILE_FORMAT_ID'),
('ACCOUNT_USAGE', 'PIPES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'PIPE_ID'),
('ACCOUNT_USAGE', 'STAGES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'STAGE_ID'),
-- Policy objects
('ACCOUNT_USAGE', 'MASKING_POLICIES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'POLICY_ID'),
('ACCOUNT_USAGE', 'ROW_ACCESS_POLICIES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'POLICY_ID'),
('ACCOUNT_USAGE', 'PRIVACY_POLICIES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'POLICY_ID'),
('ACCOUNT_USAGE', 'PROJECTION_POLICIES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'POLICY_ID'),
('ACCOUNT_USAGE', 'AGGREGATION_POLICIES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'POLICY_ID'),
('ACCOUNT_USAGE', 'PASSWORD_POLICIES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'ID'),
('ACCOUNT_USAGE', 'SESSION_POLICIES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'ID'),
('ACCOUNT_USAGE', 'BACKUP_POLICIES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'ID'),
('ACCOUNT_USAGE', 'NETWORK_POLICIES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'ID'),
('ACCOUNT_USAGE', 'NETWORK_RULES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'ID'),
-- Security objects
('ACCOUNT_USAGE', 'TAGS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'TAG_ID'),
('ACCOUNT_USAGE', 'TABLE_CONSTRAINTS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'CONSTRAINT_ID'),
('ACCOUNT_USAGE', 'REFERENTIAL_CONSTRAINTS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'CONSTRAINT_ID'),
('ACCOUNT_USAGE', 'USERS', 'SOFT_DELETE_MUTABLE', 'DELETED_ON', 'USER_ID'),
('ACCOUNT_USAGE', 'ROLES', 'SOFT_DELETE_MUTABLE', 'DELETED_ON', 'ROLE_ID'),
-- Service objects
('ACCOUNT_USAGE', 'CLASSES', 'SOFT_DELETE_MUTABLE', 'DELETED', 'ID'),
('ACCOUNT_USAGE', 'CLASS_INSTANCES', 'SOFT_DELETE_MUTABLE', 'DELETED', 'ID'),
('ACCOUNT_USAGE', 'SERVICES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'SERVICE_ID'),
('ACCOUNT_USAGE', 'COMPUTE_POOLS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', NULL),
('ACCOUNT_USAGE', 'BACKUP_SETS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'ID'),
('ACCOUNT_USAGE', 'BACKUPS', 'SOFT_DELETE_MUTABLE', 'DELETED', 'ID'),
('ACCOUNT_USAGE', 'TASK_VERSIONS', 'SOFT_DELETE_MUTABLE', 'GRAPH_VERSION_CREATED_ON', NULL),
('ACCOUNT_USAGE', 'DATA_CLASSIFICATION_LATEST', 'SOFT_DELETE_MUTABLE', 'LAST_CLASSIFIED_ON', 'TABLE_ID');

-- =============================================================================
-- ACCOUNT_USAGE: FULL_COMPARE views (no reliable watermark or key)
-- =============================================================================
INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, LOAD_STRATEGY) VALUES
('ACCOUNT_USAGE', 'GRANTS_TO_ROLES', 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'GRANTS_TO_USERS', 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'OBJECT_DEPENDENCIES', 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'POLICY_REFERENCES', 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'TAG_REFERENCES', 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'DATA_METRIC_FUNCTION_REFERENCES', 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'TABLE_STORAGE_METRICS', 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'RESOURCE_MONITORS', 'FULL_COMPARE');

-- DEACTIVATED: These views do not exist, are secure objects not accessible under
-- DATA_ADMIN role, or have been renamed/removed by Snowflake.
-- Re-activate if Snowflake re-introduces them: UPDATE VIEW_REGISTRY SET IS_ACTIVE = TRUE WHERE ...
INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, IS_ACTIVE, LOAD_STRATEGY) VALUES
('ACCOUNT_USAGE', 'WAREHOUSES', FALSE, 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'INTEGRATIONS', FALSE, 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'STREAMS', FALSE, 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'TASKS', FALSE, 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'ALERTS', FALSE, 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'LISTINGS', FALSE, 'SOFT_DELETE_MUTABLE');

-- =============================================================================
-- ORGANIZATION_USAGE views
-- DEACTIVATED: These cross-org views return 0 rows but take 3-8 min each to
-- query. They waste ~20 min per run. Re-activate when org-level data exists.
-- To re-activate: UPDATE VIEW_REGISTRY SET IS_ACTIVE = TRUE WHERE SOURCE_SCHEMA = 'ORGANIZATION_USAGE';
-- =============================================================================
INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, IS_ACTIVE, LOAD_STRATEGY, WATERMARK_COLUMN, UNIQUE_KEY_COLUMN) VALUES
('ORGANIZATION_USAGE', 'WAREHOUSE_METERING_HISTORY', FALSE, 'APPEND_ONLY', 'START_TIME', NULL),
('ORGANIZATION_USAGE', 'STORAGE_DAILY_HISTORY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'DATA_TRANSFER_HISTORY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'METERING_DAILY_HISTORY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'RATE_SHEET_DAILY', FALSE, 'APPEND_ONLY', 'DATE', NULL),
('ORGANIZATION_USAGE', 'REMAINING_BALANCE_DAILY', FALSE, 'APPEND_ONLY', 'DATE', NULL),
('ORGANIZATION_USAGE', 'USAGE_IN_CURRENCY_DAILY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'CONTRACT_ITEMS', FALSE, 'APPEND_ONLY', 'CONTRACT_MODIFIED_DATE', NULL),
('ORGANIZATION_USAGE', 'ACCOUNTS', FALSE, 'SOFT_DELETE_MUTABLE', 'ALTERED_ON', 'ACCOUNT_NAME'),
('ORGANIZATION_USAGE', 'REPLICATION_GROUP_USAGE_HISTORY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'DATABASE_REPLICATION_USAGE_HISTORY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'AUTOMATIC_CLUSTERING_HISTORY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'MATERIALIZED_VIEW_REFRESH_HISTORY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'SEARCH_OPTIMIZATION_HISTORY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'SERVERLESS_TASK_HISTORY', FALSE, 'APPEND_ONLY', 'START_TIME', NULL),
('ORGANIZATION_USAGE', 'QUERY_ACCELERATION_HISTORY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'PIPE_USAGE_HISTORY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('ORGANIZATION_USAGE', 'MARKETPLACE_DISBURSEMENT_REPORT', FALSE, 'APPEND_ONLY', 'EVENT_DATE', NULL),
('ORGANIZATION_USAGE', 'MARKETPLACE_PAID_USAGE_DAILY', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL);

INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, IS_ACTIVE, LOAD_STRATEGY) VALUES
('ORGANIZATION_USAGE', 'REGION_GROUPS', FALSE, 'FULL_COMPARE'),
('ORGANIZATION_USAGE', 'REGIONS', FALSE, 'FULL_COMPARE');

-- =============================================================================
-- DATA_SHARING_USAGE views
-- DEACTIVATED: No data sharing activity in this account. Re-activate when needed.
-- =============================================================================
INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, IS_ACTIVE, LOAD_STRATEGY, WATERMARK_COLUMN) VALUES
('DATA_SHARING_USAGE', 'LISTING_EVENTS_DAILY', FALSE, 'APPEND_ONLY', 'EVENT_DATE'),
('DATA_SHARING_USAGE', 'LISTING_TELEMETRY_DAILY', FALSE, 'APPEND_ONLY', 'EVENT_DATE'),
('DATA_SHARING_USAGE', 'MARKETPLACE_PAID_USAGE_DAILY', FALSE, 'APPEND_ONLY', 'USAGE_DATE');

-- =============================================================================
-- READER_ACCOUNT_USAGE views
-- DEACTIVATED: No reader accounts configured. Re-activate when needed.
-- =============================================================================
INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, IS_ACTIVE, LOAD_STRATEGY, WATERMARK_COLUMN, UNIQUE_KEY_COLUMN) VALUES
('READER_ACCOUNT_USAGE', 'LOGIN_HISTORY', FALSE, 'APPEND_ONLY', 'EVENT_TIMESTAMP', 'EVENT_ID'),
('READER_ACCOUNT_USAGE', 'QUERY_HISTORY', FALSE, 'APPEND_ONLY', 'START_TIME', 'QUERY_ID'),
('READER_ACCOUNT_USAGE', 'STORAGE_USAGE', FALSE, 'APPEND_ONLY', 'USAGE_DATE', NULL),
('READER_ACCOUNT_USAGE', 'WAREHOUSE_METERING_HISTORY', FALSE, 'APPEND_ONLY', 'START_TIME', NULL);

INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, IS_ACTIVE, LOAD_STRATEGY) VALUES
('READER_ACCOUNT_USAGE', 'RESOURCE_MONITORS', FALSE, 'FULL_COMPARE');

-- =============================================================================
-- ACCOUNT_USAGE: Additional high-value views discovered in the account
-- These were not in the original registry but exist in SNOWFLAKE.ACCOUNT_USAGE.
-- =============================================================================
INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, LOAD_STRATEGY, WATERMARK_COLUMN, UNIQUE_KEY_COLUMN) VALUES
-- Cortex and AI usage (expanding coverage)
('ACCOUNT_USAGE', 'CORTEX_ANALYST_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'CORTEX_REST_API_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'CORTEX_FINE_TUNING_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'CORTEX_DOCUMENT_PROCESSING_USAGE_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
-- Backup and snapshot history
('ACCOUNT_USAGE', 'BACKUP_OPERATION_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
('ACCOUNT_USAGE', 'SNAPSHOT_OPERATION_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
-- Application usage
('ACCOUNT_USAGE', 'APPLICATION_DAILY_USAGE_HISTORY', 'APPEND_ONLY', 'USAGE_DATE', NULL),
-- Additional data loading
('ACCOUNT_USAGE', 'COPY_FILES_HISTORY', 'APPEND_ONLY', 'LAST_LOAD_TIME', NULL),
('ACCOUNT_USAGE', 'SNOWPIPE_STREAMING_CHANNEL_HISTORY', 'APPEND_ONLY', 'EVENT_TIMESTAMP', NULL),
-- Container and network
('ACCOUNT_USAGE', 'NOTEBOOKS_CONTAINER_RUNTIME_HISTORY', 'APPEND_ONLY', 'START_TIME', NULL),
-- Query insights
('ACCOUNT_USAGE', 'QUERY_INSIGHTS', 'APPEND_ONLY', 'START_TIME', NULL),
-- Serverless
('ACCOUNT_USAGE', 'SERVERLESS_ALERT_HISTORY', 'APPEND_ONLY', 'SCHEDULED_TIME', NULL);

INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, LOAD_STRATEGY, WATERMARK_COLUMN, UNIQUE_KEY_COLUMN) VALUES
-- Catalog objects (mutable)
('ACCOUNT_USAGE', 'REPLICATION_GROUPS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'REPLICATION_GROUP_ID'),
('ACCOUNT_USAGE', 'SECRETS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', NULL),
('ACCOUNT_USAGE', 'CREDENTIALS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', NULL),
('ACCOUNT_USAGE', 'SNAPSHOT_POLICIES', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', 'ID'),
('ACCOUNT_USAGE', 'CONTACTS', 'SOFT_DELETE_MUTABLE', 'LAST_ALTERED', NULL);

INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW, LOAD_STRATEGY) VALUES
-- Grant and share visibility
('ACCOUNT_USAGE', 'GRANTS_TO_SHARES', 'FULL_COMPARE'),
('ACCOUNT_USAGE', 'CALLER_GRANTS_TO_ROLES', 'FULL_COMPARE');

-- =============================================================================
-- PROCEDURE: LOAD_VIEW_ARCHIVE
-- Optimized SCD Type 2 load with 3-strategy branching
--
-- APPEND_ONLY: Only loads rows beyond the last watermark. No UPDATE needed.
--   Ideal for QUERY_HISTORY, ACCESS_HISTORY, etc. where rows never change.
--   ~99% reduction in compute for large append-only tables.
--
-- SOFT_DELETE_MUTABLE: Full SCD2 with temp table (single source scan).
--   For COLUMNS, TABLES, VIEWS, etc. that can be altered or dropped.
--
-- FULL_COMPARE: Full hash comparison fallback.
--   For GRANTS_TO_ROLES, TAG_REFERENCES, etc. with no reliable watermark.
--
-- All strategies compute SHA-256 row hash for WORM compliance.
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
    v_temp_table VARCHAR;
    v_max_id INTEGER DEFAULT 0;
    v_load_strategy VARCHAR DEFAULT 'FULL_COMPARE';
    v_watermark_column VARCHAR DEFAULT NULL;
    v_last_watermark VARCHAR DEFAULT NULL;
    v_new_watermark VARCHAR DEFAULT NULL;
BEGIN
    v_schema := p_source_schema;
    v_view := p_source_view;
    v_target_table := v_view || '_ARCHIVE';
    v_target_schema := v_schema;
    v_source_fqn := 'SNOWFLAKE.' || v_schema || '.' || v_view;
    v_target_fqn := 'TEMPORAL_ARCHIVE.' || v_target_schema || '.' || v_target_table;
    v_temp_table := 'TEMPORAL_ARCHIVE.' || v_target_schema || '.' || v_target_table || '_STG';
    
    -- Get load strategy from registry
    SELECT LOAD_STRATEGY, WATERMARK_COLUMN 
    INTO :v_load_strategy, :v_watermark_column
    FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY
    WHERE SOURCE_SCHEMA = :v_schema AND SOURCE_VIEW = :v_view AND IS_ACTIVE = TRUE;
    
    -- Validate source view exists
    SELECT COUNT(*) INTO :v_source_exists
    FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS
    WHERE TABLE_SCHEMA = :v_schema AND TABLE_NAME = :v_view;
    
    IF (v_source_exists = 0) THEN
        RETURN OBJECT_CONSTRUCT(
            'source', v_source_fqn, 'target', v_target_fqn,
            'status', 'skipped', 'reason', 'Source view does not exist or is not accessible',
            'timestamp', CURRENT_TIMESTAMP()::VARCHAR
        );
    END IF;
    
    -- Check if target table exists
    SELECT COUNT(*) INTO :v_table_exists
    FROM TEMPORAL_ARCHIVE.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = :v_target_schema AND TABLE_NAME = :v_target_table;
    
    -- =========================================================================
    -- INITIAL LOAD (same for all strategies)
    -- Creates target table with CTAS, computes hash for every row.
    -- =========================================================================
    IF (v_table_exists = 0) THEN
        EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.' || v_target_schema;
        
        -- Use CTE to compute OBJECT_CONSTRUCT(*) in SELECT clause (required by Snowflake),
        -- then hash it in the outer query and exclude the helper column
        v_create_sql := 'CREATE TABLE ' || v_target_fqn || ' AS 
            WITH src_with_hash AS (
                SELECT *, OBJECT_CONSTRUCT(*) AS _obj FROM ' || v_source_fqn || '
            )
            SELECT 
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS "_ARCHIVE_ID",
                SHA2(TO_JSON(_obj), 256) AS "_ROW_HASH",
                CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_LOADED_AT",
                ''SNOWFLAKE_' || v_schema || ''' AS "_SOURCE_SYSTEM",
                ''' || v_view || ''' AS "_SOURCE_TABLE",
                TRUE AS "_IS_CURRENT",
                CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_VALID_FROM",
                ''9999-12-31 23:59:59''::TIMESTAMP_NTZ AS "_VALID_TO",
                * EXCLUDE _obj
            FROM src_with_hash';
        
        EXECUTE IMMEDIATE v_create_sql;
        SELECT COUNT(*) INTO :v_rows_inserted FROM IDENTIFIER(:v_target_fqn);
        
        -- Set initial watermark
        IF (v_watermark_column IS NOT NULL AND v_rows_inserted > 0) THEN
            BEGIN
                LET wm_rs RESULTSET := (EXECUTE IMMEDIATE 
                    'SELECT MAX("' || v_watermark_column || '")::VARCHAR FROM ' || v_target_fqn);
                LET wm_c CURSOR FOR wm_rs;
                OPEN wm_c;
                FETCH wm_c INTO v_new_watermark;
                CLOSE wm_c;
                IF (v_new_watermark IS NOT NULL) THEN
                    INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.WATERMARK_STATE 
                        (SOURCE_SCHEMA, SOURCE_VIEW, LAST_WATERMARK_VALUE, LAST_LOADED_AT, ROWS_LOADED)
                    VALUES (:v_schema, :v_view, :v_new_watermark, CURRENT_TIMESTAMP(), :v_rows_inserted);
                END IF;
            EXCEPTION WHEN OTHER THEN NULL;
            END;
        END IF;
        
        RETURN OBJECT_CONSTRUCT(
            'source', v_source_fqn, 'target', v_target_fqn,
            'action', 'INITIAL_LOAD', 'strategy', v_load_strategy,
            'rows_inserted', v_rows_inserted, 'rows_updated', 0,
            'status', 'success', 'timestamp', CURRENT_TIMESTAMP()::VARCHAR
        );
    END IF;
    
    -- =========================================================================
    -- INCREMENTAL LOAD - branch by strategy
    -- =========================================================================
    
    -- =========================================================================
    -- SCHEMA EVOLUTION: Detect new columns added to source view since initial
    -- load. Snowflake may add columns to ACCOUNT_USAGE views over time.
    -- Add them to the archive table before proceeding with INSERT.
    -- =========================================================================
    BEGIN
        LET v_evolve_sql VARCHAR;
        LET v_col_name VARCHAR;
        LET v_col_type VARCHAR;
        LET evolve_cur CURSOR FOR 
            SELECT c.COLUMN_NAME, c.DATA_TYPE
            FROM SNOWFLAKE.INFORMATION_SCHEMA.COLUMNS c
            WHERE c.TABLE_SCHEMA = :v_schema AND c.TABLE_NAME = :v_view
              AND c.COLUMN_NAME NOT IN (
                  SELECT ac.COLUMN_NAME 
                  FROM TEMPORAL_ARCHIVE.INFORMATION_SCHEMA.COLUMNS ac
                  WHERE ac.TABLE_SCHEMA = :v_target_schema AND ac.TABLE_NAME = :v_target_table
              )
            ORDER BY c.ORDINAL_POSITION;
        OPEN evolve_cur;
        FETCH evolve_cur INTO v_col_name, v_col_type;
        WHILE (v_col_name IS NOT NULL) DO
            v_evolve_sql := 'ALTER TABLE ' || v_target_fqn || ' ADD COLUMN "' || v_col_name || '" ' || v_col_type;
            EXECUTE IMMEDIATE v_evolve_sql;
            v_col_name := NULL;
            FETCH evolve_cur INTO v_col_name, v_col_type;
        END WHILE;
        CLOSE evolve_cur;
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    
    -- Get last watermark value
    IF (v_watermark_column IS NOT NULL) THEN
        BEGIN
            SELECT LAST_WATERMARK_VALUE INTO :v_last_watermark
            FROM TEMPORAL_ARCHIVE.ARCHIVE.WATERMARK_STATE
            WHERE SOURCE_SCHEMA = :v_schema AND SOURCE_VIEW = :v_view;
        EXCEPTION WHEN OTHER THEN
            v_last_watermark := NULL;
        END;
    END IF;
    
    -- Pre-compute max archive ID (avoids correlated subquery per row in INSERT)
    LET id_rs RESULTSET := (SELECT COALESCE(MAX("_ARCHIVE_ID"), 0) AS max_id 
                            FROM IDENTIFIER(:v_target_fqn));
    LET id_c CURSOR FOR id_rs;
    OPEN id_c;
    FETCH id_c INTO v_max_id;
    CLOSE id_c;
    
    -- =======================================================================
    -- STRATEGY: APPEND_ONLY
    -- Rows are immutable once written. Only INSERT new rows beyond watermark.
    -- No UPDATE needed (rows never change, never deleted from source).
    -- Hash is still computed for WORM compliance on every new row.
    -- =======================================================================
    IF (v_load_strategy = 'APPEND_ONLY' AND v_last_watermark IS NOT NULL 
        AND v_watermark_column IS NOT NULL) THEN
        
        -- Materialize only NEW rows from source (delta beyond watermark)
        EXECUTE IMMEDIATE '
            CREATE OR REPLACE TEMPORARY TABLE ' || v_temp_table || ' AS
            WITH src_with_hash AS (
                SELECT *, OBJECT_CONSTRUCT(*) AS _obj 
                FROM ' || v_source_fqn || '
                WHERE "' || v_watermark_column || '" > ''' || v_last_watermark || '''::TIMESTAMP_NTZ
            )
            SELECT 
                * EXCLUDE _obj,
                SHA2(TO_JSON(_obj), 256) AS "_SRC_ROW_HASH"
            FROM src_with_hash';
        
        -- INSERT new rows (no UPDATE needed for append-only data)
        v_insert_sql := '
            INSERT INTO ' || v_target_fqn || '
            SELECT 
                ' || v_max_id || ' + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS "_ARCHIVE_ID",
                "_SRC_ROW_HASH" AS "_ROW_HASH",
                CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_LOADED_AT",
                ''SNOWFLAKE_' || v_schema || ''' AS "_SOURCE_SYSTEM",
                ''' || v_view || ''' AS "_SOURCE_TABLE",
                TRUE AS "_IS_CURRENT",
                CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_VALID_FROM",
                ''9999-12-31 23:59:59''::TIMESTAMP_NTZ AS "_VALID_TO",
                * EXCLUDE "_SRC_ROW_HASH"
            FROM ' || v_temp_table;
        
        EXECUTE IMMEDIATE v_insert_sql;
        v_rows_inserted := SQLROWCOUNT;
        
        -- Update watermark to highest value in this batch
        BEGIN
            LET wm_rs2 RESULTSET := (EXECUTE IMMEDIATE 
                'SELECT MAX("' || v_watermark_column || '")::VARCHAR FROM ' || v_temp_table);
            LET wm_c2 CURSOR FOR wm_rs2;
            OPEN wm_c2;
            FETCH wm_c2 INTO v_new_watermark;
            CLOSE wm_c2;
            IF (v_new_watermark IS NOT NULL) THEN
                MERGE INTO TEMPORAL_ARCHIVE.ARCHIVE.WATERMARK_STATE ws
                USING (SELECT :v_schema AS s, :v_view AS v) src 
                    ON ws.SOURCE_SCHEMA = src.s AND ws.SOURCE_VIEW = src.v
                WHEN MATCHED THEN UPDATE SET 
                    LAST_WATERMARK_VALUE = :v_new_watermark, 
                    LAST_LOADED_AT = CURRENT_TIMESTAMP(), 
                    ROWS_LOADED = :v_rows_inserted
                WHEN NOT MATCHED THEN INSERT 
                    (SOURCE_SCHEMA, SOURCE_VIEW, LAST_WATERMARK_VALUE, LAST_LOADED_AT, ROWS_LOADED) 
                    VALUES (:v_schema, :v_view, :v_new_watermark, CURRENT_TIMESTAMP(), :v_rows_inserted);
            END IF;
        EXCEPTION WHEN OTHER THEN NULL;
        END;
        
        EXECUTE IMMEDIATE 'DROP TABLE IF EXISTS ' || v_temp_table;
        
        RETURN OBJECT_CONSTRUCT(
            'source', v_source_fqn, 'target', v_target_fqn,
            'action', 'INCREMENTAL_LOAD', 'strategy', 'APPEND_ONLY',
            'rows_inserted', v_rows_inserted, 'rows_updated', 0,
            'status', 'success', 'timestamp', CURRENT_TIMESTAMP()::VARCHAR
        );
    END IF;
    
    -- =======================================================================
    -- STRATEGY: SOFT_DELETE_MUTABLE and FULL_COMPARE
    -- Both use full SCD2 logic with temp table single-scan optimization.
    -- Materialize all source hashes once, then UPDATE + INSERT.
    -- Also used as fallback when watermark is not yet set.
    -- =======================================================================
    
    -- Materialize source hashes once into temp table (single scan of source)
    EXECUTE IMMEDIATE '
        CREATE OR REPLACE TEMPORARY TABLE ' || v_temp_table || ' AS
        WITH src_with_hash AS (
            SELECT *, OBJECT_CONSTRUCT(*) AS _obj FROM ' || v_source_fqn || '
        )
        SELECT 
            * EXCLUDE _obj,
            SHA2(TO_JSON(_obj), 256) AS "_SRC_ROW_HASH"
        FROM src_with_hash';
    
    -- Step 1: Close records whose hash is no longer in source
    -- Uses NOT EXISTS instead of NOT IN for better performance
    v_update_sql := '
        UPDATE ' || v_target_fqn || ' tgt
        SET "_IS_CURRENT" = FALSE,
            "_VALID_TO" = CURRENT_TIMESTAMP()::TIMESTAMP_NTZ
        WHERE tgt."_IS_CURRENT" = TRUE
          AND NOT EXISTS (
              SELECT 1 FROM ' || v_temp_table || ' src
              WHERE src."_SRC_ROW_HASH" = tgt."_ROW_HASH"
          )';
    
    EXECUTE IMMEDIATE v_update_sql;
    v_rows_updated := SQLROWCOUNT;
    
    -- Re-fetch max ID after closures
    LET id_rs2 RESULTSET := (SELECT COALESCE(MAX("_ARCHIVE_ID"), 0) AS max_id 
                             FROM IDENTIFIER(:v_target_fqn));
    LET id_c2 CURSOR FOR id_rs2;
    OPEN id_c2;
    FETCH id_c2 INTO v_max_id;
    CLOSE id_c2;
    
    -- Step 2: Insert rows whose hash is not in current target
    v_insert_sql := '
        INSERT INTO ' || v_target_fqn || '
        SELECT 
            ' || v_max_id || ' + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS "_ARCHIVE_ID",
            "_SRC_ROW_HASH" AS "_ROW_HASH",
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_LOADED_AT",
            ''SNOWFLAKE_' || v_schema || ''' AS "_SOURCE_SYSTEM",
            ''' || v_view || ''' AS "_SOURCE_TABLE",
            TRUE AS "_IS_CURRENT",
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_VALID_FROM",
            ''9999-12-31 23:59:59''::TIMESTAMP_NTZ AS "_VALID_TO",
            * EXCLUDE "_SRC_ROW_HASH"
        FROM ' || v_temp_table || ' src
        WHERE NOT EXISTS (
            SELECT 1 FROM ' || v_target_fqn || ' tgt
            WHERE tgt."_IS_CURRENT" = TRUE
              AND tgt."_ROW_HASH" = src."_SRC_ROW_HASH"
        )';
    
    EXECUTE IMMEDIATE v_insert_sql;
    v_rows_inserted := SQLROWCOUNT;
    
    -- Update watermark if applicable
    IF (v_watermark_column IS NOT NULL) THEN
        BEGIN
            LET wm_rs3 RESULTSET := (EXECUTE IMMEDIATE 
                'SELECT MAX("' || v_watermark_column || '")::VARCHAR FROM ' || v_temp_table);
            LET wm_c3 CURSOR FOR wm_rs3;
            OPEN wm_c3;
            FETCH wm_c3 INTO v_new_watermark;
            CLOSE wm_c3;
            IF (v_new_watermark IS NOT NULL) THEN
                MERGE INTO TEMPORAL_ARCHIVE.ARCHIVE.WATERMARK_STATE ws
                USING (SELECT :v_schema AS s, :v_view AS v) src 
                    ON ws.SOURCE_SCHEMA = src.s AND ws.SOURCE_VIEW = src.v
                WHEN MATCHED THEN UPDATE SET 
                    LAST_WATERMARK_VALUE = :v_new_watermark, 
                    LAST_LOADED_AT = CURRENT_TIMESTAMP(), 
                    ROWS_LOADED = :v_rows_inserted
                WHEN NOT MATCHED THEN INSERT 
                    (SOURCE_SCHEMA, SOURCE_VIEW, LAST_WATERMARK_VALUE, LAST_LOADED_AT, ROWS_LOADED) 
                    VALUES (:v_schema, :v_view, :v_new_watermark, CURRENT_TIMESTAMP(), :v_rows_inserted);
            END IF;
        EXCEPTION WHEN OTHER THEN NULL;
        END;
    END IF;
    
    EXECUTE IMMEDIATE 'DROP TABLE IF EXISTS ' || v_temp_table;
    
    RETURN OBJECT_CONSTRUCT(
        'source', v_source_fqn, 'target', v_target_fqn,
        'action', 'INCREMENTAL_LOAD', 'strategy', COALESCE(v_load_strategy, 'FULL_COMPARE'),
        'rows_inserted', v_rows_inserted, 'rows_updated', v_rows_updated,
        'status', 'success', 'timestamp', CURRENT_TIMESTAMP()::VARCHAR
    );
    
EXCEPTION
    WHEN OTHER THEN
        -- Cleanup temp table on error
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE IF EXISTS ' || v_temp_table;
        EXCEPTION WHEN OTHER THEN NULL;
        END;
        RETURN OBJECT_CONSTRUCT(
            'source', v_source_fqn, 'target', v_target_fqn,
            'status', 'error', 'error', SQLERRM,
            'strategy', COALESCE(v_load_strategy, 'UNKNOWN'),
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
    view_start_time TIMESTAMP_NTZ;
    view_end_time TIMESTAMP_NTZ;
    results ARRAY DEFAULT ARRAY_CONSTRUCT();
    table_result VARIANT;
    total_updated INTEGER DEFAULT 0;
    total_inserted INTEGER DEFAULT 0;
    error_count INTEGER DEFAULT 0;
    success_count INTEGER DEFAULT 0;
    skipped_count INTEGER DEFAULT 0;
    views_processed INTEGER DEFAULT 0;
    v_source_schema VARCHAR;
    v_source_view VARCHAR;
    v_run_id INTEGER;
    v_view_strategy VARCHAR;
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
    
    -- Generate a run ID to group all detail rows for this execution
    SELECT COALESCE(MAX(RUN_ID), 0) + 1 INTO :v_run_id FROM TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG;
    
    -- Process all views from the registry
    OPEN cur;
    FETCH cur INTO v_source_schema, v_source_view;
    WHILE (v_source_schema IS NOT NULL) DO
        
        view_start_time := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
        
        -- Get strategy for logging
        BEGIN
            SELECT LOAD_STRATEGY INTO :v_view_strategy
            FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY
            WHERE SOURCE_SCHEMA = :v_source_schema AND SOURCE_VIEW = :v_source_view;
        EXCEPTION WHEN OTHER THEN
            v_view_strategy := 'UNKNOWN';
        END;
        
        CALL TEMPORAL_ARCHIVE.ARCHIVE.LOAD_VIEW_ARCHIVE(
            :v_source_schema,
            :v_source_view
        ) INTO table_result;
        
        view_end_time := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
        results := ARRAY_APPEND(results, table_result);
        views_processed := views_processed + 1;
        
        IF (table_result:status = 'success') THEN
            total_updated := total_updated + COALESCE(table_result:rows_updated::INTEGER, 0);
            total_inserted := total_inserted + COALESCE(table_result:rows_inserted::INTEGER, 0);
            success_count := success_count + 1;
        ELSEIF (table_result:status = 'skipped') THEN
            skipped_count := skipped_count + 1;
        ELSE
            error_count := error_count + 1;
        END IF;
        
        -- Log per-view detail row
        LET v_log_rows_upd INTEGER := COALESCE(table_result:rows_updated::INTEGER, 0);
        LET v_log_rows_ins INTEGER := COALESCE(table_result:rows_inserted::INTEGER, 0);
        LET v_log_status VARCHAR := table_result:status::VARCHAR;
        LET v_log_error VARCHAR := table_result:error::VARCHAR;
        LET v_log_duration INTEGER := TIMESTAMPDIFF('SECOND', view_start_time, view_end_time);
        LET v_log_hash VARCHAR := SHA2(table_result::VARCHAR, 256);
        
        INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG (
            RUN_ID, SOURCE_TABLE, TARGET_TABLE, ROWS_UPDATED, ROWS_INSERTED,
            STATUS, ERROR_MESSAGE, DURATION_SECONDS, LOAD_STRATEGY, "_ROW_HASH"
        )
        VALUES (
            :v_run_id,
            'SNOWFLAKE.' || :v_source_schema || '.' || :v_source_view,
            'TEMPORAL_ARCHIVE.' || :v_source_schema || '.' || :v_source_view || '_ARCHIVE',
            :v_log_rows_upd,
            :v_log_rows_ins,
            :v_log_status,
            :v_log_error,
            :v_log_duration,
            :v_view_strategy,
            :v_log_hash
        );
        
        -- Fetch next
        v_source_schema := NULL;
        FETCH cur INTO v_source_schema, v_source_view;
    END WHILE;
    CLOSE cur;
    
    end_time := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    
    -- Log summary row
    LET v_duration INTEGER := TIMESTAMPDIFF('SECOND', start_time, end_time);
    LET v_status VARCHAR := CASE WHEN error_count = 0 THEN 'SUCCESS' ELSE 'PARTIAL_FAILURE' END;
    LET v_hash VARCHAR := SHA2('DYNAMIC' || views_processed || total_updated || total_inserted, 256);
    
    INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG (
        RUN_ID, SOURCE_TABLE, TARGET_TABLE, ROWS_UPDATED, ROWS_INSERTED, 
        STATUS, DURATION_SECONDS, LOAD_STRATEGY, "_ROW_HASH"
    )
    VALUES (
        :v_run_id,
        'ALL_VIEWS',
        'ALL_ARCHIVES',
        :total_updated,
        :total_inserted,
        :v_status,
        :v_duration,
        'SUMMARY',
        :v_hash
    );
    
    RETURN OBJECT_CONSTRUCT(
        'run_id', v_run_id,
        'start_time', start_time::VARCHAR,
        'end_time', end_time::VARCHAR,
        'duration_seconds', TIMESTAMPDIFF('SECOND', start_time, end_time),
        'views_in_registry', views_processed,
        'views_processed', views_processed,
        'success_count', success_count,
        'skipped_count', skipped_count,
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

-- Show strategy distribution
SELECT 
    LOAD_STRATEGY,
    IS_ACTIVE,
    COUNT(*) AS VIEW_COUNT
FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY
GROUP BY LOAD_STRATEGY, IS_ACTIVE
ORDER BY IS_ACTIVE DESC, LOAD_STRATEGY;

-- Show views per schema
SELECT 
    SOURCE_SCHEMA,
    IS_ACTIVE,
    COUNT(*) AS VIEW_COUNT
FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY
GROUP BY SOURCE_SCHEMA, IS_ACTIVE
ORDER BY IS_ACTIVE DESC, SOURCE_SCHEMA;

SELECT 'SCD load setup complete. ' || 
    (SELECT COUNT(*) FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY) || ' total views (' ||
    (SELECT COUNT(*) FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY WHERE IS_ACTIVE = TRUE) || ' active, ' ||
    (SELECT COUNT(*) FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY WHERE IS_ACTIVE = FALSE) || ' deactivated).' AS STATUS;

-- =============================================================================
-- CLUSTERING: Optimize query performance on largest archive tables.
-- Cluster by (_IS_CURRENT, _LOADED_AT) to accelerate:
--   1. Current-state queries (WHERE _IS_CURRENT = TRUE) 
--   2. Time-range analytics (WHERE _LOADED_AT BETWEEN ...)
-- Only applied to tables >100K rows. Auto-clustering maintains the order.
-- =============================================================================

ALTER TABLE IF EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.COLUMNS_ARCHIVE 
    CLUSTER BY ("_IS_CURRENT", "_LOADED_AT");
ALTER TABLE IF EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE 
    CLUSTER BY ("_IS_CURRENT", "_LOADED_AT");
ALTER TABLE IF EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.AGGREGATE_QUERY_HISTORY_ARCHIVE 
    CLUSTER BY ("_IS_CURRENT", "_LOADED_AT");
ALTER TABLE IF EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ACCESS_HISTORY_ARCHIVE 
    CLUSTER BY ("_IS_CURRENT", "_LOADED_AT");
ALTER TABLE IF EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.AGGREGATE_ACCESS_HISTORY_ARCHIVE 
    CLUSTER BY ("_IS_CURRENT", "_LOADED_AT");
ALTER TABLE IF EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TABLES_ARCHIVE 
    CLUSTER BY ("_IS_CURRENT", "_LOADED_AT");
ALTER TABLE IF EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.VIEWS_ARCHIVE 
    CLUSTER BY ("_IS_CURRENT", "_LOADED_AT");
