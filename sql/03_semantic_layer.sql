-- ============================================================================
-- SNOWFLAKE TEMPORAL ARCHIVE - SEMANTIC LAYER
-- ============================================================================
-- 
-- Native Snowflake Semantic Views for Cortex Analyst
-- Run this script in a Snowflake Worksheet after 02_scd_load.sql.
--
-- Reference: https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view
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
    COMMENT = 'Native Snowflake Semantic Views for Cortex Analyst';


-- =============================================================================
-- SEMANTIC VIEW: SERVERLESS_COST_ANALYTICS
-- Dynamic Tables, Serverless Tasks, Pipes, Auto-Clustering costs
-- This is the view for understanding serverless compute costs
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.SERVERLESS_COST_ANALYTICS
    
    TABLES (
        DYNAMIC_TABLE_REFRESH AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DYNAMIC_TABLE_REFRESH_HISTORY_ARCHIVE
            PRIMARY KEY (ID, REFRESH_START_TIME)
            WITH SYNONYMS ('dynamic tables', 'dt refresh', 'dynamic table runs'),
            
        SERVERLESS_TASK AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY_ARCHIVE
            PRIMARY KEY (TASK_ID, START_TIME)
            WITH SYNONYMS ('serverless tasks', 'task credits', 'task runs'),
            
        METERING_DAILY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.METERING_DAILY_HISTORY_ARCHIVE
            PRIMARY KEY (SERVICE_TYPE, USAGE_DATE)
            WITH SYNONYMS ('daily metering', 'daily credits', 'service costs'),
            
        AUTO_CLUSTERING AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY_ARCHIVE
            PRIMARY KEY (TABLE_ID, START_TIME)
            WITH SYNONYMS ('clustering', 'auto cluster', 'reclustering'),
            
        PIPE_USAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY_ARCHIVE
            PRIMARY KEY (PIPE_ID, START_TIME)
            WITH SYNONYMS ('pipes', 'snowpipe', 'pipe ingestion')
    )
    
    FACTS (
        -- Serverless Task Credits
        SERVERLESS_TASK.task_credits AS SERVERLESS_TASK.CREDITS_USED
            WITH SYNONYMS ('task credits', 'serverless credits')
            COMMENT = 'Credits consumed by serverless task execution',
            
        -- Auto-clustering Credits  
        AUTO_CLUSTERING.clustering_credits AS AUTO_CLUSTERING.CREDITS_USED
            WITH SYNONYMS ('clustering credits', 'recluster credits')
            COMMENT = 'Credits consumed by automatic clustering',
        AUTO_CLUSTERING.bytes_reclustered AS AUTO_CLUSTERING.NUM_BYTES_RECLUSTERED
            WITH SYNONYMS ('reclustered bytes')
            COMMENT = 'Bytes reorganized during reclustering',
        AUTO_CLUSTERING.rows_reclustered AS AUTO_CLUSTERING.NUM_ROWS_RECLUSTERED
            WITH SYNONYMS ('reclustered rows')
            COMMENT = 'Rows reorganized during reclustering',
            
        -- Pipe Credits
        PIPE_USAGE.pipe_credits AS PIPE_USAGE.CREDITS_USED
            WITH SYNONYMS ('pipe credits', 'ingestion credits')
            COMMENT = 'Credits consumed by Snowpipe',
        PIPE_USAGE.bytes_ingested AS PIPE_USAGE.BYTES_INSERTED
            WITH SYNONYMS ('bytes loaded', 'ingested bytes')
            COMMENT = 'Bytes inserted via Snowpipe',
            
        -- Daily Metering
        METERING_DAILY.daily_credits AS METERING_DAILY.CREDITS_USED
            WITH SYNONYMS ('daily credits used')
            COMMENT = 'Total daily credits by service type',
        METERING_DAILY.daily_compute_credits AS METERING_DAILY.CREDITS_USED_COMPUTE
            WITH SYNONYMS ('compute credits')
            COMMENT = 'Daily compute credits by service type',
        METERING_DAILY.daily_cloud_credits AS METERING_DAILY.CREDITS_USED_CLOUD_SERVICES
            WITH SYNONYMS ('cloud service credits')
            COMMENT = 'Daily cloud service credits by service type',
        METERING_DAILY.daily_billed AS METERING_DAILY.CREDITS_BILLED
            WITH SYNONYMS ('billed credits')
            COMMENT = 'Actual billed credits after adjustments'
    )
    
    DIMENSIONS (
        -- Dynamic Table Dimensions
        DYNAMIC_TABLE_REFRESH.dt_name AS DYNAMIC_TABLE_REFRESH.NAME
            WITH SYNONYMS ('dynamic table name', 'dt name')
            COMMENT = 'Name of the dynamic table',
        DYNAMIC_TABLE_REFRESH.dt_database AS DYNAMIC_TABLE_REFRESH.DATABASE_NAME
            WITH SYNONYMS ('database')
            COMMENT = 'Database containing the dynamic table',
        DYNAMIC_TABLE_REFRESH.dt_schema AS DYNAMIC_TABLE_REFRESH.SCHEMA_NAME
            WITH SYNONYMS ('schema')
            COMMENT = 'Schema containing the dynamic table',
        DYNAMIC_TABLE_REFRESH.dt_qualified_name AS DYNAMIC_TABLE_REFRESH.QUALIFIED_NAME
            WITH SYNONYMS ('full name', 'fully qualified')
            COMMENT = 'Fully qualified name of the dynamic table',
        DYNAMIC_TABLE_REFRESH.dt_state AS DYNAMIC_TABLE_REFRESH.STATE
            WITH SYNONYMS ('refresh state', 'status')
            COMMENT = 'State of the refresh: SUCCEEDED, FAILED, UPSTREAM_FAILED',
        DYNAMIC_TABLE_REFRESH.dt_refresh_action AS DYNAMIC_TABLE_REFRESH.REFRESH_ACTION
            WITH SYNONYMS ('action', 'refresh type')
            COMMENT = 'Type of refresh action: INCREMENTAL, FULL, NO_DATA',
        DYNAMIC_TABLE_REFRESH.dt_refresh_trigger AS DYNAMIC_TABLE_REFRESH.REFRESH_TRIGGER
            WITH SYNONYMS ('trigger', 'refresh trigger')
            COMMENT = 'What triggered the refresh: SCHEDULED, MANUAL, INITIAL',
        DYNAMIC_TABLE_REFRESH.dt_refresh_start AS DYNAMIC_TABLE_REFRESH.REFRESH_START_TIME
            WITH SYNONYMS ('refresh start', 'start time')
            COMMENT = 'When the dynamic table refresh started',
        DYNAMIC_TABLE_REFRESH.dt_refresh_end AS DYNAMIC_TABLE_REFRESH.REFRESH_END_TIME
            WITH SYNONYMS ('refresh end', 'end time')
            COMMENT = 'When the dynamic table refresh ended',
        DYNAMIC_TABLE_REFRESH.dt_target_lag AS DYNAMIC_TABLE_REFRESH.TARGET_LAG_SEC
            WITH SYNONYMS ('target lag', 'lag seconds', 'lag')
            COMMENT = 'Target lag in seconds for the dynamic table',
        DYNAMIC_TABLE_REFRESH.dt_query_id AS DYNAMIC_TABLE_REFRESH.QUERY_ID
            WITH SYNONYMS ('query id')
            COMMENT = 'Query ID of the refresh operation',
            
        -- Serverless Task Dimensions  
        SERVERLESS_TASK.task_name AS SERVERLESS_TASK.TASK_NAME
            WITH SYNONYMS ('task', 'serverless task name')
            COMMENT = 'Name of the serverless task',
        SERVERLESS_TASK.task_database AS SERVERLESS_TASK.DATABASE_NAME
            WITH SYNONYMS ('task database')
            COMMENT = 'Database containing the task',
        SERVERLESS_TASK.task_schema AS SERVERLESS_TASK.SCHEMA_NAME
            WITH SYNONYMS ('task schema')
            COMMENT = 'Schema containing the task',
        SERVERLESS_TASK.task_start AS SERVERLESS_TASK.START_TIME
            WITH SYNONYMS ('task start', 'execution start')
            COMMENT = 'When the task started',
        SERVERLESS_TASK.task_end AS SERVERLESS_TASK.END_TIME
            WITH SYNONYMS ('task end', 'execution end')
            COMMENT = 'When the task ended',
            
        -- Auto-Clustering Dimensions
        AUTO_CLUSTERING.cluster_table AS AUTO_CLUSTERING.TABLE_NAME
            WITH SYNONYMS ('clustered table')
            COMMENT = 'Name of the table being clustered',
        AUTO_CLUSTERING.cluster_database AS AUTO_CLUSTERING.DATABASE_NAME
            WITH SYNONYMS ('cluster database')
            COMMENT = 'Database of the clustered table',
        AUTO_CLUSTERING.cluster_schema AS AUTO_CLUSTERING.SCHEMA_NAME
            WITH SYNONYMS ('cluster schema')
            COMMENT = 'Schema of the clustered table',
        AUTO_CLUSTERING.cluster_start AS AUTO_CLUSTERING.START_TIME
            WITH SYNONYMS ('clustering start')
            COMMENT = 'When clustering started',
            
        -- Pipe Dimensions
        PIPE_USAGE.pipe_name AS PIPE_USAGE.PIPE_NAME
            WITH SYNONYMS ('pipe', 'snowpipe name')
            COMMENT = 'Name of the Snowpipe',
        PIPE_USAGE.pipe_start AS PIPE_USAGE.START_TIME
            WITH SYNONYMS ('pipe start', 'ingestion start')
            COMMENT = 'Start of pipe metering period',
            
        -- Daily Metering Dimensions
        METERING_DAILY.service_type AS METERING_DAILY.SERVICE_TYPE
            WITH SYNONYMS ('service', 'feature', 'product')
            COMMENT = 'Type of Snowflake service: SERVERLESS_TASK, AUTO_CLUSTERING, PIPE, MATERIALIZED_VIEW, etc.',
        METERING_DAILY.usage_date AS METERING_DAILY.USAGE_DATE
            WITH SYNONYMS ('date', 'metering date')
            COMMENT = 'Date of the metering record'
    )
    
    METRICS (
        -- Serverless Task Metrics
        SERVERLESS_TASK.total_task_credits AS SUM(SERVERLESS_TASK.task_credits)
            WITH SYNONYMS ('total serverless credits', 'task cost')
            COMMENT = 'Total credits used by serverless tasks',
        SERVERLESS_TASK.task_execution_count AS COUNT(DISTINCT SERVERLESS_TASK.TASK_ID || SERVERLESS_TASK.START_TIME)
            WITH SYNONYMS ('task runs', 'executions')
            COMMENT = 'Number of serverless task executions',
            
        -- Auto-Clustering Metrics
        AUTO_CLUSTERING.total_clustering_credits AS SUM(AUTO_CLUSTERING.clustering_credits)
            WITH SYNONYMS ('clustering cost')
            COMMENT = 'Total credits used for auto-clustering',
        AUTO_CLUSTERING.total_bytes_clustered AS SUM(AUTO_CLUSTERING.bytes_reclustered)
            WITH SYNONYMS ('bytes clustered')
            COMMENT = 'Total bytes reclustered',
            
        -- Pipe Metrics  
        PIPE_USAGE.total_pipe_credits AS SUM(PIPE_USAGE.pipe_credits)
            WITH SYNONYMS ('pipe cost', 'ingestion cost')
            COMMENT = 'Total credits used by Snowpipe',
        PIPE_USAGE.total_bytes_piped AS SUM(PIPE_USAGE.bytes_ingested)
            WITH SYNONYMS ('total ingested')
            COMMENT = 'Total bytes ingested via Snowpipe',
            
        -- Daily Metrics
        METERING_DAILY.total_daily_credits AS SUM(METERING_DAILY.daily_credits)
            WITH SYNONYMS ('total service credits')
            COMMENT = 'Total credits across services',
        METERING_DAILY.total_daily_billed AS SUM(METERING_DAILY.daily_billed)
            WITH SYNONYMS ('total billed')
            COMMENT = 'Total billed credits',
            
        -- Dynamic Table Metrics
        DYNAMIC_TABLE_REFRESH.dt_refresh_count AS COUNT(DISTINCT DYNAMIC_TABLE_REFRESH.ID || DYNAMIC_TABLE_REFRESH.REFRESH_START_TIME)
            WITH SYNONYMS ('refresh count', 'dt runs')
            COMMENT = 'Number of dynamic table refreshes',
        DYNAMIC_TABLE_REFRESH.dt_success_count AS SUM(CASE WHEN DYNAMIC_TABLE_REFRESH.dt_state = 'SUCCEEDED' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('successful refreshes')
            COMMENT = 'Number of successful dynamic table refreshes',
        DYNAMIC_TABLE_REFRESH.dt_failure_count AS SUM(CASE WHEN DYNAMIC_TABLE_REFRESH.dt_state IN ('FAILED', 'UPSTREAM_FAILED') THEN 1 ELSE 0 END)
            WITH SYNONYMS ('failed refreshes')
            COMMENT = 'Number of failed dynamic table refreshes'
    )
    
    COMMENT = 'Serverless compute cost analytics including Dynamic Tables, Tasks, Pipes, and Auto-Clustering'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. SERVICE_TYPE values include: SERVERLESS_TASK, AUTO_CLUSTERING, PIPE, MATERIALIZED_VIEW, AI_SERVICES, SEARCH_OPTIMIZATION, SNOWPIPE_STREAMING. Dynamic table STATE values: SUCCEEDED, FAILED, UPSTREAM_FAILED. REFRESH_ACTION values: INCREMENTAL, FULL, NO_DATA. TARGET_LAG_SEC indicates how fresh the dynamic table should be (e.g., 900 = 15 minutes, 3600 = 1 hour). Use REFRESH_START_TIME or START_TIME for time-based filtering. To find which dynamic tables run frequently, look at those with low TARGET_LAG_SEC values and high refresh counts.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Dynamic table costs and refresh patterns, Which dynamic tables are running frequently, Serverless task credit consumption, Auto-clustering costs by table, Snowpipe ingestion costs, Daily service-level cost breakdown, Comparing costs across serverless features.';


-- =============================================================================
-- SEMANTIC VIEW: WAREHOUSE_COST_ANALYTICS  
-- Traditional warehouse compute costs with detailed breakdown
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.WAREHOUSE_COST_ANALYTICS
    
    TABLES (
        WAREHOUSE_METERING AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
            PRIMARY KEY (START_TIME, WAREHOUSE_ID)
            WITH SYNONYMS ('warehouse usage', 'credit consumption', 'compute costs', 'warehouse credits'),
            
        QUERY_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
            PRIMARY KEY (QUERY_ID)
            WITH SYNONYMS ('queries', 'sql executions', 'query runs', 'query cost')
    )
    
    FACTS (
        WAREHOUSE_METERING.credits_used AS WAREHOUSE_METERING.CREDITS_USED
            WITH SYNONYMS ('credits', 'compute credits', 'cost')
            COMMENT = 'Total credits consumed by the warehouse',
        WAREHOUSE_METERING.credits_compute AS WAREHOUSE_METERING.CREDITS_USED_COMPUTE
            WITH SYNONYMS ('compute credits')
            COMMENT = 'Credits for compute resources',
        WAREHOUSE_METERING.credits_cloud AS WAREHOUSE_METERING.CREDITS_USED_CLOUD_SERVICES
            WITH SYNONYMS ('cloud credits', 'service credits')
            COMMENT = 'Credits for cloud services',
        QUERY_HISTORY.query_duration AS QUERY_HISTORY.TOTAL_ELAPSED_TIME
            WITH SYNONYMS ('duration', 'elapsed time', 'execution time', 'runtime')
            COMMENT = 'Total query execution time in milliseconds',
        QUERY_HISTORY.bytes_scanned AS QUERY_HISTORY.BYTES_SCANNED
            WITH SYNONYMS ('bytes read', 'data scanned')
            COMMENT = 'Bytes scanned during query execution',
        QUERY_HISTORY.rows_produced AS QUERY_HISTORY.ROWS_PRODUCED
            WITH SYNONYMS ('rows returned', 'result rows')
            COMMENT = 'Number of rows returned by the query',
        QUERY_HISTORY.partitions_scanned AS QUERY_HISTORY.PARTITIONS_SCANNED
            WITH SYNONYMS ('partitions read')
            COMMENT = 'Number of partitions scanned',
        QUERY_HISTORY.partitions_total AS QUERY_HISTORY.PARTITIONS_TOTAL
            WITH SYNONYMS ('total partitions')
            COMMENT = 'Total partitions in scanned tables',
        QUERY_HISTORY.bytes_spilled_local AS QUERY_HISTORY.BYTES_SPILLED_TO_LOCAL_STORAGE
            WITH SYNONYMS ('local spill')
            COMMENT = 'Bytes spilled to local storage',
        QUERY_HISTORY.bytes_spilled_remote AS QUERY_HISTORY.BYTES_SPILLED_TO_REMOTE_STORAGE
            WITH SYNONYMS ('remote spill')
            COMMENT = 'Bytes spilled to remote storage',
        QUERY_HISTORY.compilation_time AS QUERY_HISTORY.COMPILATION_TIME
            WITH SYNONYMS ('compile time')
            COMMENT = 'Time spent compiling the query',
        QUERY_HISTORY.execution_time AS QUERY_HISTORY.EXECUTION_TIME
            WITH SYNONYMS ('exec time')
            COMMENT = 'Time spent executing the query',
        QUERY_HISTORY.queued_time AS QUERY_HISTORY.QUEUED_PROVISIONING_TIME
            WITH SYNONYMS ('queue time', 'wait time')
            COMMENT = 'Time spent waiting for warehouse resources'
    )
    
    DIMENSIONS (
        -- Warehouse Dimensions
        WAREHOUSE_METERING.warehouse_name AS WAREHOUSE_METERING.WAREHOUSE_NAME
            WITH SYNONYMS ('warehouse', 'compute cluster', 'wh')
            COMMENT = 'Name of the virtual warehouse',
        WAREHOUSE_METERING.metering_start AS WAREHOUSE_METERING.START_TIME
            WITH SYNONYMS ('metering start', 'usage start', 'start time')
            COMMENT = 'Start time of the metering period',
        WAREHOUSE_METERING.metering_end AS WAREHOUSE_METERING.END_TIME
            WITH SYNONYMS ('metering end', 'usage end', 'end time')
            COMMENT = 'End time of the metering period',
            
        -- Query Dimensions
        QUERY_HISTORY.query_id AS QUERY_HISTORY.QUERY_ID
            WITH SYNONYMS ('query identifier')
            COMMENT = 'Unique query identifier',
        QUERY_HISTORY.query_user AS QUERY_HISTORY.USER_NAME
            WITH SYNONYMS ('user', 'query user', 'executor', 'who ran')
            COMMENT = 'User who executed the query',
        QUERY_HISTORY.query_role AS QUERY_HISTORY.ROLE_NAME
            WITH SYNONYMS ('role', 'execution role')
            COMMENT = 'Role used to execute the query',
        QUERY_HISTORY.query_type AS QUERY_HISTORY.QUERY_TYPE
            WITH SYNONYMS ('query type', 'statement type', 'sql type')
            COMMENT = 'Type of SQL statement: SELECT, INSERT, UPDATE, DELETE, etc.',
        QUERY_HISTORY.query_database AS QUERY_HISTORY.DATABASE_NAME
            WITH SYNONYMS ('database', 'db')
            COMMENT = 'Database context for the query',
        QUERY_HISTORY.query_schema AS QUERY_HISTORY.SCHEMA_NAME
            WITH SYNONYMS ('schema')
            COMMENT = 'Schema context for the query',
        QUERY_HISTORY.query_warehouse AS QUERY_HISTORY.WAREHOUSE_NAME
            WITH SYNONYMS ('query warehouse')
            COMMENT = 'Warehouse used for the query',
        QUERY_HISTORY.warehouse_size AS QUERY_HISTORY.WAREHOUSE_SIZE
            WITH SYNONYMS ('size', 'warehouse size', 'wh size')
            COMMENT = 'Size of the warehouse: X-Small, Small, Medium, Large, X-Large, etc.',
        QUERY_HISTORY.warehouse_type AS QUERY_HISTORY.WAREHOUSE_TYPE
            WITH SYNONYMS ('wh type')
            COMMENT = 'Type of warehouse: STANDARD or SNOWPARK-OPTIMIZED',
        QUERY_HISTORY.execution_status AS QUERY_HISTORY.EXECUTION_STATUS
            WITH SYNONYMS ('status', 'result status', 'query status')
            COMMENT = 'Query execution status: SUCCESS, FAIL, INCIDENT',
        QUERY_HISTORY.error_code AS QUERY_HISTORY.ERROR_CODE
            WITH SYNONYMS ('error')
            COMMENT = 'Error code if query failed',
        QUERY_HISTORY.query_start AS QUERY_HISTORY.START_TIME
            WITH SYNONYMS ('query start')
            COMMENT = 'When the query started',
        QUERY_HISTORY.query_end AS QUERY_HISTORY.END_TIME
            WITH SYNONYMS ('query end')
            COMMENT = 'When the query ended',
        QUERY_HISTORY.query_tag AS QUERY_HISTORY.QUERY_TAG
            WITH SYNONYMS ('tag', 'label')
            COMMENT = 'User-defined query tag for cost attribution'
    )
    
    METRICS (
        -- Credit Metrics
        WAREHOUSE_METERING.total_credits AS SUM(WAREHOUSE_METERING.credits_used)
            WITH SYNONYMS ('total cost', 'total credits used', 'warehouse cost')
            COMMENT = 'Sum of all credits consumed',
        WAREHOUSE_METERING.total_compute_credits AS SUM(WAREHOUSE_METERING.credits_compute)
            WITH SYNONYMS ('total compute')
            COMMENT = 'Sum of compute credits',
        WAREHOUSE_METERING.total_cloud_credits AS SUM(WAREHOUSE_METERING.credits_cloud)
            WITH SYNONYMS ('total cloud services')
            COMMENT = 'Sum of cloud service credits',
        WAREHOUSE_METERING.avg_hourly_credits AS AVG(WAREHOUSE_METERING.credits_used)
            WITH SYNONYMS ('average hourly cost')
            COMMENT = 'Average credits per metering period',
            
        -- Query Metrics
        QUERY_HISTORY.total_queries AS COUNT(QUERY_HISTORY.query_id)
            WITH SYNONYMS ('query count', 'number of queries')
            COMMENT = 'Total number of queries executed',
        QUERY_HISTORY.avg_query_duration AS AVG(QUERY_HISTORY.query_duration)
            WITH SYNONYMS ('average duration', 'mean execution time')
            COMMENT = 'Average query execution time in milliseconds',
        QUERY_HISTORY.total_bytes_scanned AS SUM(QUERY_HISTORY.bytes_scanned)
            WITH SYNONYMS ('total data scanned', 'bytes read')
            COMMENT = 'Total bytes scanned across all queries',
        QUERY_HISTORY.avg_bytes_scanned AS AVG(QUERY_HISTORY.bytes_scanned)
            WITH SYNONYMS ('average scan')
            COMMENT = 'Average bytes scanned per query',
        QUERY_HISTORY.failed_queries AS SUM(CASE WHEN QUERY_HISTORY.execution_status != 'SUCCESS' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('failures', 'errors')
            COMMENT = 'Number of failed queries',
        QUERY_HISTORY.total_spill AS SUM(QUERY_HISTORY.bytes_spilled_local + QUERY_HISTORY.bytes_spilled_remote)
            WITH SYNONYMS ('total spillage')
            COMMENT = 'Total bytes spilled (indicates need for larger warehouse)'
    )
    
    COMMENT = 'Warehouse compute cost analytics with query-level detail'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. Use START_TIME for time-based filtering on warehouse metering or query history. Credits are the unit of cost in Snowflake. WAREHOUSE_SIZE values: X-Small, Small, Medium, Large, X-Large, 2X-Large, etc. EXECUTION_STATUS values: SUCCESS, FAIL, INCIDENT. High bytes_spilled indicates queries that may benefit from a larger warehouse. QUERY_TAG can be used for cost attribution to teams or projects.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Warehouse credit consumption and costs, Query execution patterns and performance, Cost attribution by user, role, or query tag, Warehouse sizing recommendations based on spill, Query performance analysis, Which users or roles are consuming the most credits.';


-- =============================================================================
-- SEMANTIC VIEW: SECURITY_ANALYTICS
-- Login history and user activity for security auditing
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.SECURITY_ANALYTICS
    
    TABLES (
        LOGIN_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
            PRIMARY KEY (EVENT_ID)
            WITH SYNONYMS ('logins', 'authentication events', 'sign-ins', 'access attempts'),
            
        USERS AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
            PRIMARY KEY (USER_ID)
            UNIQUE (NAME)
            WITH SYNONYMS ('user accounts', 'user list', 'principals')
    )
    
    RELATIONSHIPS (
        LOGIN_HISTORY (USER_NAME) REFERENCES USERS (NAME)
    )
    
    FACTS (
        LOGIN_HISTORY.event_id AS LOGIN_HISTORY.EVENT_ID
            COMMENT = 'Unique identifier for the login event'
    )
    
    DIMENSIONS (
        LOGIN_HISTORY.login_user AS LOGIN_HISTORY.USER_NAME
            WITH SYNONYMS ('user', 'login user', 'who logged in')
            COMMENT = 'Username attempting login',
        LOGIN_HISTORY.login_time AS LOGIN_HISTORY.EVENT_TIMESTAMP
            WITH SYNONYMS ('login time', 'event time', 'when')
            COMMENT = 'Timestamp of the login attempt',
        LOGIN_HISTORY.client_ip AS LOGIN_HISTORY.CLIENT_IP
            WITH SYNONYMS ('ip address', 'source ip', 'ip')
            COMMENT = 'IP address of the client',
        LOGIN_HISTORY.client_type AS LOGIN_HISTORY.REPORTED_CLIENT_TYPE
            WITH SYNONYMS ('client type', 'application', 'client')
            COMMENT = 'Type of client application: SNOWFLAKE_UI, JDBC, ODBC, PYTHON, etc.',
        LOGIN_HISTORY.auth_factor AS LOGIN_HISTORY.FIRST_AUTHENTICATION_FACTOR
            WITH SYNONYMS ('auth factor', 'primary auth', 'authentication method')
            COMMENT = 'Primary authentication method: PASSWORD, OAUTH, KEYPAIR, etc.',
        LOGIN_HISTORY.second_auth_factor AS LOGIN_HISTORY.SECOND_AUTHENTICATION_FACTOR
            WITH SYNONYMS ('mfa method', 'second factor')
            COMMENT = 'Second authentication factor if MFA is used',
        LOGIN_HISTORY.login_success AS LOGIN_HISTORY.IS_SUCCESS
            WITH SYNONYMS ('success', 'login success', 'successful')
            COMMENT = 'Whether login was successful: YES or NO',
        LOGIN_HISTORY.error_code AS LOGIN_HISTORY.ERROR_CODE
            WITH SYNONYMS ('error', 'failure code', 'error code')
            COMMENT = 'Error code if login failed',
        LOGIN_HISTORY.error_message AS LOGIN_HISTORY.ERROR_MESSAGE
            WITH SYNONYMS ('error message', 'failure reason')
            COMMENT = 'Error message if login failed',
        LOGIN_HISTORY.connection_type AS LOGIN_HISTORY.CONNECTION
            WITH SYNONYMS ('connection')
            COMMENT = 'Connection name used',
        USERS.user_email AS USERS.EMAIL
            WITH SYNONYMS ('email address', 'user email', 'email')
            COMMENT = 'User email address',
        USERS.default_role AS USERS.DEFAULT_ROLE
            WITH SYNONYMS ('default role', 'primary role')
            COMMENT = 'Default role assigned to user',
        USERS.user_disabled AS USERS.DISABLED
            WITH SYNONYMS ('is disabled', 'account disabled', 'disabled')
            COMMENT = 'Whether user account is disabled',
        USERS.has_mfa AS USERS.HAS_MFA
            WITH SYNONYMS ('mfa enabled', 'multi-factor', 'has mfa')
            COMMENT = 'Whether MFA is enabled for user',
        USERS.user_created AS USERS.CREATED_ON
            WITH SYNONYMS ('created', 'account created')
            COMMENT = 'When the user account was created'
    )
    
    METRICS (
        LOGIN_HISTORY.total_logins AS COUNT(LOGIN_HISTORY.event_id)
            WITH SYNONYMS ('login count', 'total attempts', 'login attempts')
            COMMENT = 'Total number of login attempts',
        LOGIN_HISTORY.successful_logins AS SUM(CASE WHEN LOGIN_HISTORY.login_success = 'YES' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('successes', 'good logins')
            COMMENT = 'Number of successful login attempts',
        LOGIN_HISTORY.failed_logins AS SUM(CASE WHEN LOGIN_HISTORY.login_success = 'NO' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('failed count', 'bad logins', 'failures')
            COMMENT = 'Number of failed login attempts',
        LOGIN_HISTORY.unique_users AS COUNT(DISTINCT LOGIN_HISTORY.login_user)
            WITH SYNONYMS ('distinct users', 'user count', 'unique logins')
            COMMENT = 'Number of unique users attempting login',
        LOGIN_HISTORY.unique_ips AS COUNT(DISTINCT LOGIN_HISTORY.client_ip)
            WITH SYNONYMS ('ip count', 'distinct ips')
            COMMENT = 'Number of unique IP addresses'
    )
    
    COMMENT = 'Security analytics for login monitoring and access auditing'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. IS_SUCCESS contains YES or NO as string values. Use EVENT_TIMESTAMP for time-based filtering on logins. REPORTED_CLIENT_TYPE values: SNOWFLAKE_UI, JDBC_DRIVER, ODBC_DRIVER, PYTHON_DRIVER, etc. FIRST_AUTHENTICATION_FACTOR values: PASSWORD, OAUTH, KEYPAIR_USER, etc. Look for multiple failed logins from the same IP to detect potential attacks.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Login attempts and authentication events, Failed login patterns and security risks, User account status and MFA adoption, Login patterns by IP address or client type, Detecting potential brute force attacks.';


-- =============================================================================
-- SEMANTIC VIEW: STORAGE_ANALYTICS
-- Database and table storage for capacity planning
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.STORAGE_ANALYTICS
    
    TABLES (
        STORAGE_USAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.STORAGE_USAGE_ARCHIVE
            PRIMARY KEY (USAGE_DATE)
            WITH SYNONYMS ('storage', 'disk usage', 'data storage', 'account storage'),
            
        DATABASE_STORAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY_ARCHIVE
            PRIMARY KEY (USAGE_DATE, DATABASE_ID)
            WITH SYNONYMS ('database storage', 'db storage', 'database size'),
            
        TABLE_STORAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS_ARCHIVE
            PRIMARY KEY (ID, CATALOG_DROPPED)
            WITH SYNONYMS ('table storage', 'table size', 'table metrics')
    )
    
    FACTS (
        STORAGE_USAGE.storage_bytes AS STORAGE_USAGE.STORAGE_BYTES
            WITH SYNONYMS ('storage bytes', 'total bytes', 'account bytes')
            COMMENT = 'Total account storage in bytes',
        STORAGE_USAGE.stage_bytes AS STORAGE_USAGE.STAGE_BYTES
            WITH SYNONYMS ('stage bytes', 'staging storage')
            COMMENT = 'Stage storage in bytes',
        STORAGE_USAGE.failsafe_bytes AS STORAGE_USAGE.FAILSAFE_BYTES
            WITH SYNONYMS ('failsafe bytes', 'backup storage')
            COMMENT = 'Failsafe storage in bytes',
        DATABASE_STORAGE.db_average_bytes AS DATABASE_STORAGE.AVERAGE_DATABASE_BYTES
            WITH SYNONYMS ('database size', 'average database bytes', 'db bytes')
            COMMENT = 'Average database size in bytes',
        DATABASE_STORAGE.db_failsafe_bytes AS DATABASE_STORAGE.AVERAGE_FAILSAFE_BYTES
            WITH SYNONYMS ('database failsafe')
            COMMENT = 'Database failsafe storage in bytes',
        TABLE_STORAGE.table_bytes AS TABLE_STORAGE.ACTIVE_BYTES
            WITH SYNONYMS ('table bytes', 'active bytes')
            COMMENT = 'Active storage for the table',
        TABLE_STORAGE.time_travel_bytes AS TABLE_STORAGE.TIME_TRAVEL_BYTES
            WITH SYNONYMS ('time travel storage')
            COMMENT = 'Time travel storage in bytes',
        TABLE_STORAGE.table_failsafe_bytes AS TABLE_STORAGE.FAILSAFE_BYTES
            WITH SYNONYMS ('table failsafe')
            COMMENT = 'Failsafe storage for the table',
        TABLE_STORAGE.retained_bytes AS TABLE_STORAGE.RETAINED_FOR_CLONE_BYTES
            WITH SYNONYMS ('clone retained')
            COMMENT = 'Bytes retained for clones'
    )
    
    DIMENSIONS (
        STORAGE_USAGE.storage_date AS STORAGE_USAGE.USAGE_DATE
            WITH SYNONYMS ('date', 'storage date', 'usage date')
            COMMENT = 'Date of storage measurement',
        DATABASE_STORAGE.database_name AS DATABASE_STORAGE.DATABASE_NAME
            WITH SYNONYMS ('database', 'db name', 'db')
            COMMENT = 'Name of the database',
        DATABASE_STORAGE.db_usage_date AS DATABASE_STORAGE.USAGE_DATE
            WITH SYNONYMS ('db date')
            COMMENT = 'Date of database storage measurement',
        TABLE_STORAGE.table_name AS TABLE_STORAGE.TABLE_NAME
            WITH SYNONYMS ('table', 'table name')
            COMMENT = 'Name of the table',
        TABLE_STORAGE.table_schema AS TABLE_STORAGE.TABLE_SCHEMA
            WITH SYNONYMS ('schema', 'table schema')
            COMMENT = 'Schema containing the table',
        TABLE_STORAGE.table_catalog AS TABLE_STORAGE.TABLE_CATALOG
            WITH SYNONYMS ('catalog', 'table database')
            COMMENT = 'Database containing the table',
        TABLE_STORAGE.is_transient AS TABLE_STORAGE.IS_TRANSIENT
            WITH SYNONYMS ('transient')
            COMMENT = 'Whether the table is transient',
        TABLE_STORAGE.table_created AS TABLE_STORAGE.TABLE_CREATED
            WITH SYNONYMS ('created')
            COMMENT = 'When the table was created'
    )
    
    METRICS (
        STORAGE_USAGE.total_storage_bytes AS SUM(STORAGE_USAGE.storage_bytes)
            WITH SYNONYMS ('total storage', 'total bytes')
            COMMENT = 'Total storage across all dates',
        STORAGE_USAGE.total_storage_tb AS SUM(STORAGE_USAGE.storage_bytes) / POWER(1024, 4)
            WITH SYNONYMS ('storage terabytes', 'tb used', 'terabytes')
            COMMENT = 'Total storage in terabytes',
        STORAGE_USAGE.total_storage_gb AS SUM(STORAGE_USAGE.storage_bytes) / POWER(1024, 3)
            WITH SYNONYMS ('storage gigabytes', 'gb used', 'gigabytes')
            COMMENT = 'Total storage in gigabytes',
        STORAGE_USAGE.avg_daily_storage AS AVG(STORAGE_USAGE.storage_bytes)
            WITH SYNONYMS ('average storage')
            COMMENT = 'Average daily storage usage',
        DATABASE_STORAGE.total_db_storage AS SUM(DATABASE_STORAGE.db_average_bytes)
            WITH SYNONYMS ('total database storage')
            COMMENT = 'Total storage across databases',
        TABLE_STORAGE.total_table_storage AS SUM(TABLE_STORAGE.table_bytes)
            WITH SYNONYMS ('total table storage')
            COMMENT = 'Total storage across tables'
    )
    
    COMMENT = 'Storage analytics for capacity planning and optimization'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. Storage is measured in bytes - divide by POWER(1024,3) for GB or POWER(1024,4) for TB. Use USAGE_DATE for time-based trending. For table-level analysis, join on TABLE_CATALOG = DATABASE_NAME. ACTIVE_BYTES is the current table size, TIME_TRAVEL_BYTES is historical data for recovery.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Storage consumption trends, Database and table size and growth, Capacity planning and forecasting, Time travel and failsafe storage costs, Identifying large tables for optimization.';


-- =============================================================================
-- SEMANTIC VIEW: GOVERNANCE_ANALYTICS
-- User and role management for governance
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.GOVERNANCE_ANALYTICS
    
    TABLES (
        USERS AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
            PRIMARY KEY (USER_ID)
            UNIQUE (NAME)
            WITH SYNONYMS ('users', 'user accounts', 'principals'),
            
        ROLES AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ROLES_ARCHIVE
            PRIMARY KEY (ROLE_ID)
            UNIQUE (NAME)
            WITH SYNONYMS ('roles', 'security roles'),
            
        GRANTS_TO_USERS AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.GRANTS_TO_USERS_ARCHIVE
            PRIMARY KEY (CREATED_ON, ROLE, GRANTEE_NAME)
            WITH SYNONYMS ('user grants', 'role assignments', 'user roles')
    )
    
    RELATIONSHIPS (
        GRANTS_TO_USERS (GRANTEE_NAME) REFERENCES USERS (NAME),
        GRANTS_TO_USERS (ROLE) REFERENCES ROLES (NAME)
    )
    
    DIMENSIONS (
        USERS.user_name AS USERS.NAME
            WITH SYNONYMS ('user', 'username', 'user name')
            COMMENT = 'User account name',
        USERS.login_name AS USERS.LOGIN_NAME
            WITH SYNONYMS ('login', 'login id')
            COMMENT = 'Login identifier',
        USERS.user_email AS USERS.EMAIL
            WITH SYNONYMS ('email', 'user email')
            COMMENT = 'User email address',
        USERS.default_warehouse AS USERS.DEFAULT_WAREHOUSE
            WITH SYNONYMS ('warehouse', 'default compute')
            COMMENT = 'Default warehouse for user',
        USERS.default_role AS USERS.DEFAULT_ROLE
            WITH SYNONYMS ('default role', 'primary role')
            COMMENT = 'Default role for user',
        USERS.user_created AS USERS.CREATED_ON
            WITH SYNONYMS ('user created', 'account created', 'created')
            COMMENT = 'When user was created',
        USERS.user_disabled AS USERS.DISABLED
            WITH SYNONYMS ('is disabled', 'inactive', 'disabled')
            COMMENT = 'Whether user is disabled',
        USERS.has_mfa AS USERS.HAS_MFA
            WITH SYNONYMS ('mfa', 'multi-factor auth', 'has mfa')
            COMMENT = 'Whether MFA is enabled',
        USERS.last_success_login AS USERS.LAST_SUCCESS_LOGIN
            WITH SYNONYMS ('last login', 'last active')
            COMMENT = 'Last successful login time',
        ROLES.role_name AS ROLES.NAME
            WITH SYNONYMS ('role', 'security role', 'role name')
            COMMENT = 'Role name',
        ROLES.role_owner AS ROLES.OWNER
            WITH SYNONYMS ('role owner', 'owner')
            COMMENT = 'Owner of the role',
        ROLES.role_created AS ROLES.CREATED_ON
            WITH SYNONYMS ('role created')
            COMMENT = 'When role was created',
        GRANTS_TO_USERS.granted_role AS GRANTS_TO_USERS.ROLE
            WITH SYNONYMS ('assigned role', 'granted')
            COMMENT = 'Role granted to user',
        GRANTS_TO_USERS.grantee AS GRANTS_TO_USERS.GRANTEE_NAME
            WITH SYNONYMS ('grantee', 'recipient')
            COMMENT = 'User receiving the grant',
        GRANTS_TO_USERS.grant_date AS GRANTS_TO_USERS.CREATED_ON
            WITH SYNONYMS ('grant date', 'when granted')
            COMMENT = 'When the role was granted'
    )
    
    METRICS (
        USERS.total_users AS COUNT(DISTINCT USERS.USER_ID)
            WITH SYNONYMS ('user count', 'number of users')
            COMMENT = 'Total number of users',
        USERS.active_users AS SUM(CASE WHEN USERS.user_disabled = 'false' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('active count', 'enabled users')
            COMMENT = 'Number of active (non-disabled) users',
        USERS.mfa_users AS SUM(CASE WHEN USERS.has_mfa = TRUE THEN 1 ELSE 0 END)
            WITH SYNONYMS ('mfa count', 'mfa enabled count')
            COMMENT = 'Number of users with MFA enabled',
        ROLES.total_roles AS COUNT(DISTINCT ROLES.ROLE_ID)
            WITH SYNONYMS ('role count', 'number of roles')
            COMMENT = 'Total number of roles',
        GRANTS_TO_USERS.total_grants AS COUNT(DISTINCT GRANTS_TO_USERS.granted_role || GRANTS_TO_USERS.grantee)
            WITH SYNONYMS ('grant count')
            COMMENT = 'Total number of role grants'
    )
    
    COMMENT = 'User and role governance analytics'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. DISABLED is stored as a string value. HAS_MFA is a boolean indicating multi-factor authentication status. Use LAST_SUCCESS_LOGIN to find inactive users. Join GRANTS_TO_USERS to see which roles are assigned to which users.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: User account management and status, Role assignments and hierarchy, Security posture and MFA adoption, Inactive user identification, Who has access to what roles.';


-- =============================================================================
-- SEMANTIC VIEW: TASK_ANALYTICS
-- Task execution history for monitoring scheduled jobs
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.TASK_ANALYTICS
    
    TABLES (
        TASK_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TASK_HISTORY_ARCHIVE
            PRIMARY KEY (QUERY_ID)
            WITH SYNONYMS ('tasks', 'scheduled tasks', 'task runs', 'task executions')
    )
    
    FACTS (
        TASK_HISTORY.run_id AS TASK_HISTORY.RUN_ID
            COMMENT = 'Unique run identifier'
    )
    
    DIMENSIONS (
        TASK_HISTORY.task_name AS TASK_HISTORY.NAME
            WITH SYNONYMS ('task', 'task name', 'job')
            COMMENT = 'Name of the task',
        TASK_HISTORY.task_database AS TASK_HISTORY.DATABASE_NAME
            WITH SYNONYMS ('database', 'db')
            COMMENT = 'Database containing the task',
        TASK_HISTORY.task_schema AS TASK_HISTORY.SCHEMA_NAME
            WITH SYNONYMS ('schema')
            COMMENT = 'Schema containing the task',
        TASK_HISTORY.task_state AS TASK_HISTORY.STATE
            WITH SYNONYMS ('state', 'status', 'result')
            COMMENT = 'Execution state: SUCCEEDED, FAILED, CANCELLED, SKIPPED',
        TASK_HISTORY.scheduled_time AS TASK_HISTORY.SCHEDULED_TIME
            WITH SYNONYMS ('scheduled', 'scheduled at')
            COMMENT = 'When the task was scheduled to run',
        TASK_HISTORY.completed_time AS TASK_HISTORY.COMPLETED_TIME
            WITH SYNONYMS ('completed', 'finished', 'completed at')
            COMMENT = 'When the task completed',
        TASK_HISTORY.query_start AS TASK_HISTORY.QUERY_START_TIME
            WITH SYNONYMS ('started', 'query start')
            COMMENT = 'When the query started executing',
        TASK_HISTORY.error_code AS TASK_HISTORY.ERROR_CODE
            WITH SYNONYMS ('error')
            COMMENT = 'Error code if task failed',
        TASK_HISTORY.error_message AS TASK_HISTORY.ERROR_MESSAGE
            WITH SYNONYMS ('error message', 'failure reason')
            COMMENT = 'Error message if task failed',
        TASK_HISTORY.query_id AS TASK_HISTORY.QUERY_ID
            WITH SYNONYMS ('query')
            COMMENT = 'Query ID of the task execution',
        TASK_HISTORY.scheduled_from AS TASK_HISTORY.SCHEDULED_FROM
            WITH SYNONYMS ('trigger source')
            COMMENT = 'What triggered the task: EXECUTE TASK, SCHEDULE',
        TASK_HISTORY.root_task_id AS TASK_HISTORY.ROOT_TASK_ID
            WITH SYNONYMS ('root task', 'parent')
            COMMENT = 'Root task ID in a task graph',
        TASK_HISTORY.attempt_number AS TASK_HISTORY.ATTEMPT_NUMBER
            WITH SYNONYMS ('attempt', 'retry')
            COMMENT = 'Attempt number for retried tasks'
    )
    
    METRICS (
        TASK_HISTORY.total_runs AS COUNT(TASK_HISTORY.QUERY_ID)
            WITH SYNONYMS ('run count', 'executions')
            COMMENT = 'Total number of task runs',
        TASK_HISTORY.successful_runs AS SUM(CASE WHEN TASK_HISTORY.task_state = 'SUCCEEDED' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('successes')
            COMMENT = 'Number of successful task runs',
        TASK_HISTORY.failed_runs AS SUM(CASE WHEN TASK_HISTORY.task_state = 'FAILED' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('failures')
            COMMENT = 'Number of failed task runs',
        TASK_HISTORY.skipped_runs AS SUM(CASE WHEN TASK_HISTORY.task_state = 'SKIPPED' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('skips')
            COMMENT = 'Number of skipped task runs'
    )
    
    COMMENT = 'Task execution analytics for monitoring scheduled jobs'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. STATE values: SUCCEEDED, FAILED, CANCELLED, SKIPPED. Use SCHEDULED_TIME or COMPLETED_TIME for time-based filtering. Tasks with non-null ROOT_TASK_ID are part of a task graph. High ATTEMPT_NUMBER indicates retry patterns.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Task execution success and failure rates, Which tasks are failing frequently, Task scheduling patterns, Task graph dependencies and root tasks, Error patterns in scheduled jobs.';


-- =============================================================================
-- SEMANTIC VIEW: BCDR_ANALYTICS
-- Business Continuity and Disaster Recovery analytics
-- RPO/RTO monitoring, storage inventory, data churn, and DR object identification
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.BCDR_ANALYTICS
    
    TABLES (
        -- Storage baseline for recovery planning
        STORAGE_USAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.STORAGE_USAGE_ARCHIVE
            PRIMARY KEY (USAGE_DATE)
            WITH SYNONYMS ('account storage', 'storage baseline', 'storage inventory'),
            
        -- Database-level storage for churn analysis
        DATABASE_STORAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY_ARCHIVE
            PRIMARY KEY (USAGE_DATE, DATABASE_ID)
            WITH SYNONYMS ('database storage', 'db storage', 'churn analysis'),
            
        -- Table-level metrics for identifying high-priority DR objects
        TABLE_STORAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS_ARCHIVE
            PRIMARY KEY (ID, CATALOG_DROPPED)
            WITH SYNONYMS ('table storage', 'table metrics', 'hot tables', 'DR objects'),
            
        -- Replication usage for RPO monitoring
        REPLICATION_USAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASE_REPLICATION_USAGE_HISTORY_ARCHIVE
            PRIMARY KEY (DATABASE_ID, START_TIME)
            WITH SYNONYMS ('replication', 'database replication', 'sync'),
            
        -- Replication groups configuration
        REPLICATION_GROUPS AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.REPLICATION_GROUPS_ARCHIVE
            PRIMARY KEY (NAME)
            WITH SYNONYMS ('failover groups', 'replication groups', 'DR groups')
    )
    
    FACTS (
        -- Account Storage Facts
        STORAGE_USAGE.active_storage_bytes AS STORAGE_USAGE.STORAGE_BYTES
            WITH SYNONYMS ('active bytes', 'database bytes', 'production data')
            COMMENT = 'Active database storage in bytes (production data)',
        STORAGE_USAGE.stage_storage_bytes AS STORAGE_USAGE.STAGE_BYTES
            WITH SYNONYMS ('stage bytes', 'staging data')
            COMMENT = 'Stage storage in bytes',
        STORAGE_USAGE.failsafe_storage_bytes AS STORAGE_USAGE.FAILSAFE_BYTES
            WITH SYNONYMS ('failsafe bytes', 'disaster recovery data', 'DR storage')
            COMMENT = 'Fail-safe storage in bytes (7-day emergency DR)',
            
        -- Database Storage Facts
        DATABASE_STORAGE.db_active_bytes AS DATABASE_STORAGE.AVERAGE_DATABASE_BYTES
            WITH SYNONYMS ('database size', 'db bytes', 'active db storage')
            COMMENT = 'Average database size including time travel',
        DATABASE_STORAGE.db_failsafe_bytes AS DATABASE_STORAGE.AVERAGE_FAILSAFE_BYTES
            WITH SYNONYMS ('db failsafe', 'churn indicator', 'data churn')
            COMMENT = 'Database fail-safe bytes - indicates data churn/RTO',
            
        -- Table Storage Facts (for identifying hot tables)
        TABLE_STORAGE.table_active_bytes AS TABLE_STORAGE.ACTIVE_BYTES
            WITH SYNONYMS ('table size', 'active table bytes')
            COMMENT = 'Active storage for the table',
        TABLE_STORAGE.table_time_travel_bytes AS TABLE_STORAGE.TIME_TRAVEL_BYTES
            WITH SYNONYMS ('time travel bytes', 'short term recovery')
            COMMENT = 'Time travel storage - short-term recovery capacity',
        TABLE_STORAGE.table_failsafe_bytes AS TABLE_STORAGE.FAILSAFE_BYTES
            WITH SYNONYMS ('table failsafe', 'table churn', 'disaster churn')
            COMMENT = 'Table fail-safe bytes - high values indicate hot/churning tables',
        TABLE_STORAGE.table_clone_bytes AS TABLE_STORAGE.RETAINED_FOR_CLONE_BYTES
            WITH SYNONYMS ('clone bytes', 'clone storage')
            COMMENT = 'Bytes retained for clones',
            
        -- Replication Facts (RPO indicators)
        REPLICATION_USAGE.replication_credits AS REPLICATION_USAGE.CREDITS_USED
            WITH SYNONYMS ('replication cost', 'sync cost')
            COMMENT = 'Credits consumed by replication',
        REPLICATION_USAGE.bytes_replicated AS REPLICATION_USAGE.BYTES_TRANSFERRED
            WITH SYNONYMS ('bytes transferred', 'replicated data')
            COMMENT = 'Bytes transferred during replication'
    )
    
    DIMENSIONS (
        -- Storage Date Dimensions
        STORAGE_USAGE.storage_date AS STORAGE_USAGE.USAGE_DATE
            WITH SYNONYMS ('date', 'usage date', 'storage date')
            COMMENT = 'Date of storage measurement',
        DATABASE_STORAGE.db_storage_date AS DATABASE_STORAGE.USAGE_DATE
            WITH SYNONYMS ('db date')
            COMMENT = 'Date of database storage measurement',
            
        -- Database Dimensions
        DATABASE_STORAGE.database_name AS DATABASE_STORAGE.DATABASE_NAME
            WITH SYNONYMS ('database', 'db', 'db name')
            COMMENT = 'Name of the database',
            
        -- Table Dimensions (for DR object identification)
        TABLE_STORAGE.table_name AS TABLE_STORAGE.TABLE_NAME
            WITH SYNONYMS ('table', 'object', 'dr object')
            COMMENT = 'Name of the table',
        TABLE_STORAGE.table_schema AS TABLE_STORAGE.TABLE_SCHEMA
            WITH SYNONYMS ('schema')
            COMMENT = 'Schema containing the table',
        TABLE_STORAGE.table_catalog AS TABLE_STORAGE.TABLE_CATALOG
            WITH SYNONYMS ('catalog', 'table database')
            COMMENT = 'Database containing the table',
        TABLE_STORAGE.is_transient AS TABLE_STORAGE.IS_TRANSIENT
            WITH SYNONYMS ('transient', 'no failsafe')
            COMMENT = 'Transient tables have no fail-safe protection',
        TABLE_STORAGE.table_deleted AS TABLE_STORAGE.DELETED
            WITH SYNONYMS ('deleted', 'dropped')
            COMMENT = 'Whether the table is deleted',
        TABLE_STORAGE.table_created AS TABLE_STORAGE.TABLE_CREATED
            WITH SYNONYMS ('created', 'table created')
            COMMENT = 'When the table was created',
            
        -- Replication Dimensions
        REPLICATION_USAGE.replicated_database AS REPLICATION_USAGE.DATABASE_NAME
            WITH SYNONYMS ('replicated db', 'synced database')
            COMMENT = 'Database being replicated',
        REPLICATION_USAGE.replication_start AS REPLICATION_USAGE.START_TIME
            WITH SYNONYMS ('replication start', 'sync start')
            COMMENT = 'Start time of replication operation',
        REPLICATION_USAGE.replication_end AS REPLICATION_USAGE.END_TIME
            WITH SYNONYMS ('replication end', 'sync end')
            COMMENT = 'End time of replication operation',
            
        -- Replication Group Dimensions
        REPLICATION_GROUPS.group_name AS REPLICATION_GROUPS.NAME
            WITH SYNONYMS ('failover group', 'replication group', 'dr group')
            COMMENT = 'Name of the replication/failover group',
        REPLICATION_GROUPS.group_type AS REPLICATION_GROUPS.TYPE
            WITH SYNONYMS ('group type')
            COMMENT = 'Type of replication group: FAILOVER or REPLICATION',
        REPLICATION_GROUPS.replication_schedule AS REPLICATION_GROUPS.REPLICATION_SCHEDULE
            WITH SYNONYMS ('schedule', 'sync schedule', 'rpo schedule')
            COMMENT = 'Replication schedule (determines RPO)',
        REPLICATION_GROUPS.object_types AS REPLICATION_GROUPS.OBJECT_TYPES
            WITH SYNONYMS ('replicated objects', 'dr objects')
            COMMENT = 'Object types included in replication'
    )
    
    METRICS (
        -- Storage Summary Metrics (in TB for readability)
        STORAGE_USAGE.total_storage_tb AS SUM(STORAGE_USAGE.active_storage_bytes) / POWER(1024, 4)
            WITH SYNONYMS ('total storage terabytes', 'active tb')
            COMMENT = 'Total active storage in terabytes',
        STORAGE_USAGE.total_failsafe_tb AS SUM(STORAGE_USAGE.failsafe_storage_bytes) / POWER(1024, 4)
            WITH SYNONYMS ('failsafe terabytes', 'dr storage tb')
            COMMENT = 'Total fail-safe storage in terabytes',
        STORAGE_USAGE.total_billed_tb AS SUM(STORAGE_USAGE.active_storage_bytes + STORAGE_USAGE.failsafe_storage_bytes + STORAGE_USAGE.stage_storage_bytes) / POWER(1024, 4)
            WITH SYNONYMS ('billed storage', 'total billed')
            COMMENT = 'Total billed storage in terabytes',
            
        -- Database Churn Metrics (RTO indicators)
        DATABASE_STORAGE.total_db_storage AS SUM(DATABASE_STORAGE.db_active_bytes)
            WITH SYNONYMS ('database storage sum')
            COMMENT = 'Sum of database storage',
        DATABASE_STORAGE.total_db_churn AS SUM(DATABASE_STORAGE.db_failsafe_bytes)
            WITH SYNONYMS ('total churn', 'failsafe sum')
            COMMENT = 'Sum of fail-safe storage indicating data churn',
        DATABASE_STORAGE.avg_db_storage_tb AS AVG(DATABASE_STORAGE.db_active_bytes) / POWER(1024, 4)
            WITH SYNONYMS ('average database size')
            COMMENT = 'Average database storage in TB',
        DATABASE_STORAGE.avg_db_churn_tb AS AVG(DATABASE_STORAGE.db_failsafe_bytes) / POWER(1024, 4)
            WITH SYNONYMS ('average churn')
            COMMENT = 'Average fail-safe/churn in TB',
            
        -- Table Metrics (DR object prioritization)
        TABLE_STORAGE.table_count AS COUNT(DISTINCT TABLE_STORAGE.ID)
            WITH SYNONYMS ('number of tables', 'table count')
            COMMENT = 'Number of tables',
        TABLE_STORAGE.hot_table_count AS SUM(CASE WHEN TABLE_STORAGE.table_failsafe_bytes > 0 THEN 1 ELSE 0 END)
            WITH SYNONYMS ('churning tables', 'hot tables')
            COMMENT = 'Tables with fail-safe data (active churn)',
        TABLE_STORAGE.total_table_size_gb AS SUM(TABLE_STORAGE.table_active_bytes) / POWER(1024, 3)
            WITH SYNONYMS ('total table size')
            COMMENT = 'Total table storage in GB',
        TABLE_STORAGE.total_time_travel_gb AS SUM(TABLE_STORAGE.table_time_travel_bytes) / POWER(1024, 3)
            WITH SYNONYMS ('total time travel')
            COMMENT = 'Total time travel storage in GB',
        TABLE_STORAGE.total_table_failsafe_gb AS SUM(TABLE_STORAGE.table_failsafe_bytes) / POWER(1024, 3)
            WITH SYNONYMS ('total table churn', 'disaster churn gb')
            COMMENT = 'Total table fail-safe storage in GB (indicates churn)',
            
        -- Replication Metrics
        REPLICATION_USAGE.total_replication_credits AS SUM(REPLICATION_USAGE.replication_credits)
            WITH SYNONYMS ('replication cost', 'sync credits')
            COMMENT = 'Total credits used for replication',
        REPLICATION_USAGE.total_bytes_replicated AS SUM(REPLICATION_USAGE.bytes_replicated)
            WITH SYNONYMS ('total replicated', 'synced bytes')
            COMMENT = 'Total bytes transferred via replication',
        REPLICATION_USAGE.replication_count AS COUNT(DISTINCT REPLICATION_USAGE.replication_start)
            WITH SYNONYMS ('sync count', 'replication events')
            COMMENT = 'Number of replication events'
    )
    
    COMMENT = 'Business Continuity and Disaster Recovery analytics for RPO/RTO monitoring, storage inventory, data churn analysis, and high-priority DR object identification'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. Use USAGE_DATE for time-based storage trending. For churn analysis (RTO proxy), compare AVERAGE_FAILSAFE_BYTES to AVERAGE_DATABASE_BYTES - high ratios indicate high data churn requiring more recovery time. High FAILSAFE_BYTES on tables indicates "hot" tables that change frequently and are expensive to replicate. REPLICATION_SCHEDULE determines RPO - more frequent schedules = lower RPO. TIME_TRAVEL_BYTES supports Tier 3 recovery (up to 90 days). FAILSAFE_BYTES supports Tier 4 emergency recovery (7 days after time travel expires). IS_TRANSIENT = true means no fail-safe protection. Calculate churn percentage as (failsafe_bytes / active_bytes) * 100.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Storage inventory and baseline for DR planning, Recovery Point Objective (RPO) via replication lag, Recovery Time Objective (RTO) via data churn analysis, Identifying high-priority DR objects (hot tables), Business Impact Analysis data for tiering, Storage growth trends for capacity planning, Comparing active vs failsafe vs time travel storage, Which tables have the highest churn, Replication costs and frequency.';


-- =============================================================================
-- SEMANTIC VIEW: COST_ANALYTICS
-- General cost analytics combining warehouse metering with query history
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.COST_ANALYTICS
    
    TABLES (
        METERING_DAILY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.METERING_DAILY_HISTORY_ARCHIVE
            PRIMARY KEY (SERVICE_TYPE, USAGE_DATE)
            WITH SYNONYMS ('daily metering', 'daily costs', 'credit consumption'),
            
        WAREHOUSE_METERING AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
            PRIMARY KEY (START_TIME, WAREHOUSE_ID)
            WITH SYNONYMS ('warehouse usage', 'compute costs')
    )
    
    FACTS (
        -- Daily Metering Facts
        METERING_DAILY.total_credits AS METERING_DAILY.CREDITS_USED
            WITH SYNONYMS ('credits used', 'total cost')
            COMMENT = 'Total credits consumed',
        METERING_DAILY.compute_credits AS METERING_DAILY.CREDITS_USED_COMPUTE
            WITH SYNONYMS ('compute credits')
            COMMENT = 'Credits for compute resources',
        METERING_DAILY.cloud_credits AS METERING_DAILY.CREDITS_USED_CLOUD_SERVICES
            WITH SYNONYMS ('cloud credits', 'service credits')
            COMMENT = 'Credits for cloud services',
        METERING_DAILY.billed_credits AS METERING_DAILY.CREDITS_BILLED
            WITH SYNONYMS ('billed', 'actual cost')
            COMMENT = 'Actual billed credits after adjustments',
            
        -- Warehouse Metering Facts
        WAREHOUSE_METERING.warehouse_credits AS WAREHOUSE_METERING.CREDITS_USED
            WITH SYNONYMS ('warehouse cost')
            COMMENT = 'Credits consumed by warehouse'
    )
    
    DIMENSIONS (
        -- Daily Metering Dimensions
        METERING_DAILY.service_type AS METERING_DAILY.SERVICE_TYPE
            WITH SYNONYMS ('service', 'feature', 'product', 'cost category')
            COMMENT = 'Type of Snowflake service: WAREHOUSE_METERING, AUTO_CLUSTERING, MATERIALIZED_VIEW, etc.',
        METERING_DAILY.usage_date AS METERING_DAILY.USAGE_DATE
            WITH SYNONYMS ('date', 'day')
            COMMENT = 'Date of the usage record',
            
        -- Warehouse Dimensions
        WAREHOUSE_METERING.warehouse_name AS WAREHOUSE_METERING.WAREHOUSE_NAME
            WITH SYNONYMS ('warehouse', 'compute cluster', 'wh')
            COMMENT = 'Name of the virtual warehouse',
        WAREHOUSE_METERING.metering_start AS WAREHOUSE_METERING.START_TIME
            WITH SYNONYMS ('start time', 'period start')
            COMMENT = 'Start of metering period'
    )
    
    METRICS (
        -- Daily Aggregations
        METERING_DAILY.total_daily_credits AS SUM(METERING_DAILY.total_credits)
            WITH SYNONYMS ('daily total', 'total spend')
            COMMENT = 'Sum of all credits for the period',
        METERING_DAILY.total_compute AS SUM(METERING_DAILY.compute_credits)
            WITH SYNONYMS ('compute total')
            COMMENT = 'Sum of compute credits',
        METERING_DAILY.total_billed AS SUM(METERING_DAILY.billed_credits)
            WITH SYNONYMS ('billed total')
            COMMENT = 'Sum of billed credits',
        METERING_DAILY.avg_daily_credits AS AVG(METERING_DAILY.total_credits)
            WITH SYNONYMS ('average daily', 'avg cost')
            COMMENT = 'Average daily credits',
            
        -- Warehouse Aggregations
        WAREHOUSE_METERING.total_warehouse_credits AS SUM(WAREHOUSE_METERING.warehouse_credits)
            WITH SYNONYMS ('warehouse total', 'compute cost')
            COMMENT = 'Sum of warehouse credits',
        WAREHOUSE_METERING.avg_warehouse_credits AS AVG(WAREHOUSE_METERING.warehouse_credits)
            WITH SYNONYMS ('avg warehouse')
            COMMENT = 'Average warehouse credits per period'
    )
    
    COMMENT = 'General cost analytics combining daily metering with warehouse usage'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. SERVICE_TYPE values include: WAREHOUSE_METERING, AUTO_CLUSTERING, MATERIALIZED_VIEW, PIPE, REPLICATION, QUERY_ACCELERATION, SERVERLESS_TASK, SEARCH_OPTIMIZATION. Use USAGE_DATE for daily trend analysis. Credits are the unit of cost - multiply by your contract rate for dollar amounts. For month-over-month comparisons, group by DATE_TRUNC(month, USAGE_DATE).'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Overall credit consumption and trends, Cost breakdown by service type, Daily/weekly/monthly cost analysis, Comparing costs across different Snowflake features, General cost overview before drilling into specifics.';


-- =============================================================================
-- SEMANTIC VIEW: QUERY_PERFORMANCE_ANALYTICS
-- Detailed query analysis with table-level access patterns and performance alerting
-- Joins QUERY_HISTORY with ACCESS_HISTORY for complete user/table attribution
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.QUERY_PERFORMANCE_ANALYTICS
    
    TABLES (
        QUERY_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
            PRIMARY KEY (QUERY_ID)
            WITH SYNONYMS ('queries', 'sql executions', 'query runs', 'query performance', 'slow queries'),
            
        ACCESS_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ACCESS_HISTORY_ARCHIVE
            PRIMARY KEY (QUERY_ID)
            WITH SYNONYMS ('table access', 'data access', 'object access', 'who accessed what', 'data lineage')
    )
    
    RELATIONSHIPS (
        ACCESS_HISTORY (QUERY_ID) REFERENCES QUERY_HISTORY (QUERY_ID)
    )
    
    FACTS (
        -- Duration Metrics (all in milliseconds)
        QUERY_HISTORY.total_elapsed_time AS QUERY_HISTORY.TOTAL_ELAPSED_TIME
            WITH SYNONYMS ('duration', 'elapsed time', 'total time', 'runtime')
            COMMENT = 'Total query execution time in milliseconds',
        QUERY_HISTORY.execution_time AS QUERY_HISTORY.EXECUTION_TIME
            WITH SYNONYMS ('exec time', 'processing time')
            COMMENT = 'Time spent executing the query in milliseconds',
        QUERY_HISTORY.compilation_time AS QUERY_HISTORY.COMPILATION_TIME
            WITH SYNONYMS ('compile time', 'parse time')
            COMMENT = 'Time spent compiling/parsing the query in milliseconds',
        QUERY_HISTORY.queued_provisioning_time AS QUERY_HISTORY.QUEUED_PROVISIONING_TIME
            WITH SYNONYMS ('provisioning wait', 'startup time')
            COMMENT = 'Time waiting for warehouse to provision',
        QUERY_HISTORY.queued_overload_time AS QUERY_HISTORY.QUEUED_OVERLOAD_TIME
            WITH SYNONYMS ('queue time', 'overload wait', 'contention time')
            COMMENT = 'Time waiting due to warehouse overload - indicates capacity issues',
        QUERY_HISTORY.queued_repair_time AS QUERY_HISTORY.QUEUED_REPAIR_TIME
            WITH SYNONYMS ('repair wait')
            COMMENT = 'Time waiting for warehouse repair',
        QUERY_HISTORY.transaction_blocked_time AS QUERY_HISTORY.TRANSACTION_BLOCKED_TIME
            WITH SYNONYMS ('blocked time', 'lock wait')
            COMMENT = 'Time blocked by other transactions',
            
        -- I/O Metrics
        QUERY_HISTORY.bytes_scanned AS QUERY_HISTORY.BYTES_SCANNED
            WITH SYNONYMS ('bytes read', 'data scanned', 'scan size')
            COMMENT = 'Bytes scanned from storage',
        QUERY_HISTORY.bytes_written AS QUERY_HISTORY.BYTES_WRITTEN
            WITH SYNONYMS ('bytes output', 'data written')
            COMMENT = 'Bytes written to storage',
        QUERY_HISTORY.bytes_written_to_result AS QUERY_HISTORY.BYTES_WRITTEN_TO_RESULT
            WITH SYNONYMS ('result size')
            COMMENT = 'Bytes written to query result',
        QUERY_HISTORY.rows_produced AS QUERY_HISTORY.ROWS_PRODUCED
            WITH SYNONYMS ('rows returned', 'result rows', 'output rows')
            COMMENT = 'Number of rows returned by the query',
        QUERY_HISTORY.rows_inserted AS QUERY_HISTORY.ROWS_INSERTED
            WITH SYNONYMS ('inserts')
            COMMENT = 'Number of rows inserted',
        QUERY_HISTORY.rows_updated AS QUERY_HISTORY.ROWS_UPDATED
            WITH SYNONYMS ('updates')
            COMMENT = 'Number of rows updated',
        QUERY_HISTORY.rows_deleted AS QUERY_HISTORY.ROWS_DELETED
            WITH SYNONYMS ('deletes')
            COMMENT = 'Number of rows deleted',
            
        -- Partition Pruning Metrics (critical for performance)
        QUERY_HISTORY.partitions_scanned AS QUERY_HISTORY.PARTITIONS_SCANNED
            WITH SYNONYMS ('partitions read', 'scanned partitions')
            COMMENT = 'Number of partitions scanned - lower is better',
        QUERY_HISTORY.partitions_total AS QUERY_HISTORY.PARTITIONS_TOTAL
            WITH SYNONYMS ('total partitions', 'partition count')
            COMMENT = 'Total partitions in scanned tables',
            
        -- Cache Metrics
        QUERY_HISTORY.cache_hit_ratio AS QUERY_HISTORY.PERCENTAGE_SCANNED_FROM_CACHE
            WITH SYNONYMS ('cache hit', 'cache percentage', 'cache ratio')
            COMMENT = 'Percentage of data read from cache (0-1, higher is better)',
            
        -- Spill Metrics (indicates memory pressure)
        QUERY_HISTORY.bytes_spilled_local AS QUERY_HISTORY.BYTES_SPILLED_TO_LOCAL_STORAGE
            WITH SYNONYMS ('local spill', 'local spillage')
            COMMENT = 'Bytes spilled to local SSD - indicates memory pressure',
        QUERY_HISTORY.bytes_spilled_remote AS QUERY_HISTORY.BYTES_SPILLED_TO_REMOTE_STORAGE
            WITH SYNONYMS ('remote spill', 'remote spillage')
            COMMENT = 'Bytes spilled to remote storage - severe memory pressure, consider larger warehouse',
            
        -- Network Metrics
        QUERY_HISTORY.bytes_sent_over_network AS QUERY_HISTORY.BYTES_SENT_OVER_THE_NETWORK
            WITH SYNONYMS ('network bytes', 'data transfer')
            COMMENT = 'Bytes sent over network',
            
        -- Cost Metrics
        QUERY_HISTORY.credits_used_cloud_services AS QUERY_HISTORY.CREDITS_USED_CLOUD_SERVICES
            WITH SYNONYMS ('cloud credits', 'service credits', 'query cost')
            COMMENT = 'Cloud service credits consumed by this query',
            
        -- Load Metrics
        QUERY_HISTORY.query_load_percent AS QUERY_HISTORY.QUERY_LOAD_PERCENT
            WITH SYNONYMS ('load percent', 'warehouse load')
            COMMENT = 'Percentage of warehouse resources used by query',
            
        -- Query Acceleration Metrics
        QUERY_HISTORY.acceleration_bytes_scanned AS QUERY_HISTORY.QUERY_ACCELERATION_BYTES_SCANNED
            WITH SYNONYMS ('accelerated bytes')
            COMMENT = 'Bytes scanned via query acceleration service',
        QUERY_HISTORY.acceleration_partitions_scanned AS QUERY_HISTORY.QUERY_ACCELERATION_PARTITIONS_SCANNED
            WITH SYNONYMS ('accelerated partitions')
            COMMENT = 'Partitions scanned via query acceleration',
            
        -- External Function Metrics
        QUERY_HISTORY.external_function_invocations AS QUERY_HISTORY.EXTERNAL_FUNCTION_TOTAL_INVOCATIONS
            WITH SYNONYMS ('external calls', 'function calls')
            COMMENT = 'Number of external function invocations',
        QUERY_HISTORY.external_function_sent_rows AS QUERY_HISTORY.EXTERNAL_FUNCTION_TOTAL_SENT_ROWS
            WITH SYNONYMS ('rows sent external')
            COMMENT = 'Rows sent to external functions',
        QUERY_HISTORY.external_function_received_rows AS QUERY_HISTORY.EXTERNAL_FUNCTION_TOTAL_RECEIVED_ROWS
            WITH SYNONYMS ('rows received external')
            COMMENT = 'Rows received from external functions'
    )
    
    DIMENSIONS (
        -- Query Identifiers
        QUERY_HISTORY.query_id AS QUERY_HISTORY.QUERY_ID
            WITH SYNONYMS ('query identifier', 'id')
            COMMENT = 'Unique query identifier',
        QUERY_HISTORY.query_hash AS QUERY_HISTORY.QUERY_HASH
            WITH SYNONYMS ('sql hash', 'query fingerprint')
            COMMENT = 'Hash of the query text for identifying similar queries',
        QUERY_HISTORY.query_parameterized_hash AS QUERY_HISTORY.QUERY_PARAMETERIZED_HASH
            WITH SYNONYMS ('parameterized hash', 'normalized hash')
            COMMENT = 'Hash ignoring literal values - groups queries with different parameters',
            
        -- User Context
        QUERY_HISTORY.user_name AS QUERY_HISTORY.USER_NAME
            WITH SYNONYMS ('user', 'who ran', 'executor', 'query user')
            COMMENT = 'User who executed the query',
        QUERY_HISTORY.role_name AS QUERY_HISTORY.ROLE_NAME
            WITH SYNONYMS ('role', 'execution role')
            COMMENT = 'Role used to execute the query',
        QUERY_HISTORY.role_type AS QUERY_HISTORY.ROLE_TYPE
            WITH SYNONYMS ('role type')
            COMMENT = 'Type of role: ROLE or DATABASE_ROLE',
        QUERY_HISTORY.user_type AS QUERY_HISTORY.USER_TYPE
            WITH SYNONYMS ('user type', 'principal type')
            COMMENT = 'Type of user: USER, SERVICE, APPLICATION',
            
        -- Warehouse Context
        QUERY_HISTORY.warehouse_name AS QUERY_HISTORY.WAREHOUSE_NAME
            WITH SYNONYMS ('warehouse', 'compute', 'wh')
            COMMENT = 'Virtual warehouse used for the query',
        QUERY_HISTORY.warehouse_size AS QUERY_HISTORY.WAREHOUSE_SIZE
            WITH SYNONYMS ('size', 'wh size')
            COMMENT = 'Size of the warehouse: X-Small, Small, Medium, Large, X-Large, etc.',
        QUERY_HISTORY.warehouse_type AS QUERY_HISTORY.WAREHOUSE_TYPE
            WITH SYNONYMS ('wh type')
            COMMENT = 'Type: STANDARD or SNOWPARK-OPTIMIZED',
        QUERY_HISTORY.cluster_number AS QUERY_HISTORY.CLUSTER_NUMBER
            WITH SYNONYMS ('cluster', 'multi-cluster')
            COMMENT = 'Cluster number for multi-cluster warehouses',
            
        -- Database/Schema Context
        QUERY_HISTORY.database_name AS QUERY_HISTORY.DATABASE_NAME
            WITH SYNONYMS ('database', 'db')
            COMMENT = 'Database context for the query',
        QUERY_HISTORY.schema_name AS QUERY_HISTORY.SCHEMA_NAME
            WITH SYNONYMS ('schema')
            COMMENT = 'Schema context for the query',
            
        -- Query Metadata
        QUERY_HISTORY.query_type AS QUERY_HISTORY.QUERY_TYPE
            WITH SYNONYMS ('statement type', 'sql type', 'operation')
            COMMENT = 'Type of SQL: SELECT, INSERT, UPDATE, DELETE, CREATE, etc.',
        QUERY_HISTORY.query_tag AS QUERY_HISTORY.QUERY_TAG
            WITH SYNONYMS ('tag', 'label', 'cost center')
            COMMENT = 'User-defined query tag for cost attribution and tracking',
        QUERY_HISTORY.execution_status AS QUERY_HISTORY.EXECUTION_STATUS
            WITH SYNONYMS ('status', 'result', 'outcome')
            COMMENT = 'Query status: SUCCESS, FAIL, INCIDENT',
        QUERY_HISTORY.error_code AS QUERY_HISTORY.ERROR_CODE
            WITH SYNONYMS ('error', 'error number')
            COMMENT = 'Error code if query failed',
        QUERY_HISTORY.error_message AS QUERY_HISTORY.ERROR_MESSAGE
            WITH SYNONYMS ('error text', 'failure reason')
            COMMENT = 'Error message if query failed',
            
        -- Time Dimensions
        QUERY_HISTORY.start_time AS QUERY_HISTORY.START_TIME
            WITH SYNONYMS ('query start', 'started', 'begin time')
            COMMENT = 'When the query started',
        QUERY_HISTORY.end_time AS QUERY_HISTORY.END_TIME
            WITH SYNONYMS ('query end', 'finished', 'completed')
            COMMENT = 'When the query ended',
            
        -- Client Context
        QUERY_HISTORY.is_client_generated AS QUERY_HISTORY.IS_CLIENT_GENERATED_STATEMENT
            WITH SYNONYMS ('client generated', 'auto generated')
            COMMENT = 'Whether query was generated by a client driver',
        QUERY_HISTORY.session_id AS QUERY_HISTORY.SESSION_ID
            WITH SYNONYMS ('session')
            COMMENT = 'Session ID for the query',
        QUERY_HISTORY.release_version AS QUERY_HISTORY.RELEASE_VERSION
            WITH SYNONYMS ('snowflake version', 'release')
            COMMENT = 'Snowflake release version',
            
        -- Retry Information
        QUERY_HISTORY.query_retry_time AS QUERY_HISTORY.QUERY_RETRY_TIME
            WITH SYNONYMS ('retry time')
            COMMENT = 'Time spent in query retries',
        QUERY_HISTORY.query_retry_cause AS QUERY_HISTORY.QUERY_RETRY_CAUSE
            WITH SYNONYMS ('retry reason')
            COMMENT = 'Reason for query retry',
            
        -- Access History Dimensions (for table-level attribution)
        ACCESS_HISTORY.query_start_time AS ACCESS_HISTORY.QUERY_START_TIME
            WITH SYNONYMS ('access time')
            COMMENT = 'When the data access occurred',
        ACCESS_HISTORY.access_user AS ACCESS_HISTORY.USER_NAME
            WITH SYNONYMS ('accessing user')
            COMMENT = 'User who accessed the data',
        ACCESS_HISTORY.direct_objects_accessed AS ACCESS_HISTORY.DIRECT_OBJECTS_ACCESSED
            WITH SYNONYMS ('tables accessed', 'objects read', 'direct access', 'what tables')
            COMMENT = 'Array of tables/views directly referenced in the query - flatten with LATERAL FLATTEN',
        ACCESS_HISTORY.base_objects_accessed AS ACCESS_HISTORY.BASE_OBJECTS_ACCESSED
            WITH SYNONYMS ('base tables', 'underlying tables', 'source tables')
            COMMENT = 'Array of base tables accessed (through views) - flatten with LATERAL FLATTEN',
        ACCESS_HISTORY.objects_modified AS ACCESS_HISTORY.OBJECTS_MODIFIED
            WITH SYNONYMS ('tables modified', 'objects written', 'data changes')
            COMMENT = 'Array of tables/objects modified by the query - flatten with LATERAL FLATTEN',
        ACCESS_HISTORY.policies_referenced AS ACCESS_HISTORY.POLICIES_REFERENCED
            WITH SYNONYMS ('masking policies', 'row access policies', 'security policies')
            COMMENT = 'Array of data protection policies applied during query execution',
        ACCESS_HISTORY.parent_query_id AS ACCESS_HISTORY.PARENT_QUERY_ID
            WITH SYNONYMS ('parent query')
            COMMENT = 'Parent query ID if this is a child query',
        ACCESS_HISTORY.root_query_id AS ACCESS_HISTORY.ROOT_QUERY_ID
            WITH SYNONYMS ('root query', 'original query')
            COMMENT = 'Root query ID in a query hierarchy'
    )
    
    METRICS (
        -- Query Count Metrics
        QUERY_HISTORY.total_queries AS COUNT(QUERY_HISTORY.query_id)
            WITH SYNONYMS ('query count', 'number of queries', 'executions')
            COMMENT = 'Total number of queries',
        QUERY_HISTORY.successful_queries AS SUM(CASE WHEN QUERY_HISTORY.execution_status = 'SUCCESS' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('successes', 'successful count')
            COMMENT = 'Number of successful queries',
        QUERY_HISTORY.failed_queries AS SUM(CASE WHEN QUERY_HISTORY.execution_status != 'SUCCESS' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('failures', 'failed count', 'errors')
            COMMENT = 'Number of failed queries',
        QUERY_HISTORY.unique_query_patterns AS COUNT(DISTINCT QUERY_HISTORY.query_parameterized_hash)
            WITH SYNONYMS ('unique queries', 'distinct patterns')
            COMMENT = 'Number of unique query patterns (by parameterized hash)',
            
        -- Duration Metrics
        QUERY_HISTORY.avg_duration_ms AS AVG(QUERY_HISTORY.total_elapsed_time)
            WITH SYNONYMS ('average duration', 'mean time', 'avg runtime')
            COMMENT = 'Average query duration in milliseconds',
        QUERY_HISTORY.max_duration_ms AS MAX(QUERY_HISTORY.total_elapsed_time)
            WITH SYNONYMS ('max duration', 'longest query', 'slowest')
            COMMENT = 'Maximum query duration in milliseconds',
        QUERY_HISTORY.total_duration_ms AS SUM(QUERY_HISTORY.total_elapsed_time)
            WITH SYNONYMS ('total time', 'cumulative duration')
            COMMENT = 'Sum of all query durations',
        QUERY_HISTORY.p95_duration_approx AS APPROX_PERCENTILE(QUERY_HISTORY.total_elapsed_time, 0.95)
            WITH SYNONYMS ('95th percentile', 'p95 duration')
            COMMENT = 'Approximate 95th percentile query duration',
            
        -- Long Running Query Detection (>5 minutes)
        QUERY_HISTORY.long_running_count AS SUM(CASE WHEN QUERY_HISTORY.total_elapsed_time > 300000 THEN 1 ELSE 0 END)
            WITH SYNONYMS ('slow queries', 'long queries')
            COMMENT = 'Queries running longer than 5 minutes (300000ms)',
            
        -- I/O Metrics
        QUERY_HISTORY.total_bytes_scanned AS SUM(QUERY_HISTORY.bytes_scanned)
            WITH SYNONYMS ('total scanned', 'data read')
            COMMENT = 'Total bytes scanned across all queries',
        QUERY_HISTORY.avg_bytes_scanned AS AVG(QUERY_HISTORY.bytes_scanned)
            WITH SYNONYMS ('average scan')
            COMMENT = 'Average bytes scanned per query',
        QUERY_HISTORY.total_rows_produced AS SUM(QUERY_HISTORY.rows_produced)
            WITH SYNONYMS ('total rows')
            COMMENT = 'Total rows returned across all queries',
            
        -- Partition Scan Metrics (for clustering efficiency)
        QUERY_HISTORY.avg_partition_scan_pct AS AVG(QUERY_HISTORY.partitions_scanned / NULLIF(QUERY_HISTORY.partitions_total, 0) * 100)
            WITH SYNONYMS ('average scan percentage', 'avg partition pct')
            COMMENT = 'Average percentage of partitions scanned - high values indicate poor clustering',
        QUERY_HISTORY.high_scan_pct_count AS SUM(CASE WHEN QUERY_HISTORY.partitions_scanned / NULLIF(QUERY_HISTORY.partitions_total, 0) > 0.9 THEN 1 ELSE 0 END)
            WITH SYNONYMS ('full scan queries', 'high scan count')
            COMMENT = 'Queries scanning >90% of partitions - candidates for clustering optimization',
            
        -- Cache Metrics
        QUERY_HISTORY.avg_cache_hit_ratio AS AVG(QUERY_HISTORY.cache_hit_ratio)
            WITH SYNONYMS ('average cache hit', 'cache efficiency')
            COMMENT = 'Average cache hit ratio across queries',
        QUERY_HISTORY.low_cache_hit_count AS SUM(CASE WHEN QUERY_HISTORY.cache_hit_ratio < 0.2 THEN 1 ELSE 0 END)
            WITH SYNONYMS ('cache misses', 'low cache queries')
            COMMENT = 'Queries with <20% cache hit - cold queries or large scans',
            
        -- Spill Metrics (memory pressure indicators)
        QUERY_HISTORY.total_spill_bytes AS SUM(QUERY_HISTORY.bytes_spilled_local + QUERY_HISTORY.bytes_spilled_remote)
            WITH SYNONYMS ('total spillage', 'spill total')
            COMMENT = 'Total bytes spilled across all queries',
        QUERY_HISTORY.queries_with_remote_spill AS SUM(CASE WHEN QUERY_HISTORY.bytes_spilled_remote > 0 THEN 1 ELSE 0 END)
            WITH SYNONYMS ('remote spill count', 'severe spill')
            COMMENT = 'Queries with remote spillage - consider warehouse upsizing',
        QUERY_HISTORY.queries_with_any_spill AS SUM(CASE WHEN QUERY_HISTORY.bytes_spilled_local + QUERY_HISTORY.bytes_spilled_remote > 0 THEN 1 ELSE 0 END)
            WITH SYNONYMS ('spill count', 'memory pressure queries')
            COMMENT = 'Queries with any spillage',
            
        -- Queue Time Metrics (capacity indicators)
        QUERY_HISTORY.total_queue_time AS SUM(QUERY_HISTORY.queued_overload_time + QUERY_HISTORY.queued_provisioning_time)
            WITH SYNONYMS ('total wait time', 'queue total')
            COMMENT = 'Total time queries spent waiting',
        QUERY_HISTORY.avg_queue_time AS AVG(QUERY_HISTORY.queued_overload_time + QUERY_HISTORY.queued_provisioning_time)
            WITH SYNONYMS ('average wait', 'avg queue')
            COMMENT = 'Average queue time per query',
        QUERY_HISTORY.queries_with_high_queue AS SUM(CASE WHEN QUERY_HISTORY.queued_overload_time > 30000 THEN 1 ELSE 0 END)
            WITH SYNONYMS ('queued queries', 'contention count')
            COMMENT = 'Queries with >30s queue time - indicates capacity constraints',
            
        -- Cost Metrics
        QUERY_HISTORY.total_cloud_credits AS SUM(QUERY_HISTORY.credits_used_cloud_services)
            WITH SYNONYMS ('total cloud cost', 'service credits total')
            COMMENT = 'Total cloud service credits consumed',
            
        -- User/Role Distribution
        QUERY_HISTORY.unique_users AS COUNT(DISTINCT QUERY_HISTORY.user_name)
            WITH SYNONYMS ('user count', 'distinct users')
            COMMENT = 'Number of unique users running queries',
        QUERY_HISTORY.unique_roles AS COUNT(DISTINCT QUERY_HISTORY.role_name)
            WITH SYNONYMS ('role count', 'distinct roles')
            COMMENT = 'Number of unique roles used'
    )
    
    COMMENT = 'Comprehensive query performance analytics with table-level access patterns, user attribution, and alerting metrics for identifying long-running queries, high scan percentages, memory pressure, and capacity constraints'
    
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. Use START_TIME for time-based filtering. 

ALERTING THRESHOLDS:
- Long-running queries: TOTAL_ELAPSED_TIME > 300000 (5 minutes in ms)
- High scan percentage: PARTITIONS_SCANNED / NULLIF(PARTITIONS_TOTAL, 0) > 0.9 indicates poor clustering
- Memory pressure: BYTES_SPILLED_TO_REMOTE_STORAGE > 0 suggests warehouse upsizing
- Queue contention: QUEUED_OVERLOAD_TIME > 30000 (30 seconds) indicates capacity issues
- Low cache hits: PERCENTAGE_SCANNED_FROM_CACHE < 0.2 may indicate cold queries

TABLE-LEVEL ACCESS (requires LATERAL FLATTEN):
- To find which tables a user accessed: LATERAL FLATTEN(INPUT => DIRECT_OBJECTS_ACCESSED) f, then f.VALUE:objectName::STRING
- To find base tables through views: LATERAL FLATTEN(INPUT => BASE_OBJECTS_ACCESSED)
- To find modified tables: LATERAL FLATTEN(INPUT => OBJECTS_MODIFIED)
- To find applied policies: LATERAL FLATTEN(INPUT => POLICIES_REFERENCED)

QUERY GROUPING:
- Use QUERY_PARAMETERIZED_HASH to group similar queries with different parameter values
- Use QUERY_HASH for exact query text matching

EXECUTION_STATUS values: SUCCESS, FAIL, INCIDENT
WAREHOUSE_SIZE values: X-Small, Small, Medium, Large, X-Large, 2X-Large, etc.
QUERY_TYPE values: SELECT, INSERT, UPDATE, DELETE, CREATE_TABLE, etc.'

    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about:
- Query performance analysis and duration trends
- Long-running query identification and alerting
- High partition scan percentage queries (clustering opportunities)
- Memory pressure analysis (spill detection for warehouse sizing)
- Queue time analysis (capacity planning)
- Cache hit ratio analysis
- Which users accessed which tables (user/table attribution)
- What data did a specific user query
- Table access patterns and frequency
- Data lineage - what objects were modified by queries
- Policy-protected data access auditing
- Cost attribution by user, role, or query tag
- Failed query analysis and error patterns
- Identifying expensive query patterns by parameterized hash
- Warehouse utilization and load analysis';


-- =============================================================================
-- SEMANTIC VIEW: ORGANIZATION_ANALYTICS
-- Cross-account organization-level cost, contract, balance, and storage analytics
-- Requires ORGADMIN role for source data population
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.ORGANIZATION_ANALYTICS
    
    TABLES (
        USAGE_CURRENCY AS TEMPORAL_ARCHIVE.ORGANIZATION_USAGE.USAGE_IN_CURRENCY_DAILY_ARCHIVE
            PRIMARY KEY (ACCOUNT_NAME, USAGE_DATE, SERVICE_LEVEL, USAGE_TYPE)
            WITH SYNONYMS ('org costs', 'currency costs', 'dollar costs', 'org spend', 'account costs'),
            
        REMAINING_BALANCE AS TEMPORAL_ARCHIVE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY_ARCHIVE
            PRIMARY KEY (CONTRACT_NUMBER, DATE)
            WITH SYNONYMS ('balance', 'remaining credits', 'contract balance', 'capacity remaining'),
            
        METERING_DAILY AS TEMPORAL_ARCHIVE.ORGANIZATION_USAGE.METERING_DAILY_HISTORY_ARCHIVE
            PRIMARY KEY (ACCOUNT_NAME, SERVICE_TYPE, USAGE_DATE)
            WITH SYNONYMS ('org metering', 'org credits', 'account credits', 'cross-account credits'),
            
        WAREHOUSE_METERING AS TEMPORAL_ARCHIVE.ORGANIZATION_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
            PRIMARY KEY (ACCOUNT_NAME, WAREHOUSE_ID, START_TIME)
            WITH SYNONYMS ('org warehouse costs', 'account warehouse usage', 'cross-account warehouses'),
            
        ACCOUNTS AS TEMPORAL_ARCHIVE.ORGANIZATION_USAGE.ACCOUNTS_ARCHIVE
            PRIMARY KEY (ACCOUNT_NAME)
            WITH SYNONYMS ('org accounts', 'account list', 'account inventory', 'snowflake accounts')
    )
    
    RELATIONSHIPS (
        USAGE_CURRENCY (ACCOUNT_NAME) REFERENCES ACCOUNTS (ACCOUNT_NAME),
        METERING_DAILY (ACCOUNT_NAME) REFERENCES ACCOUNTS (ACCOUNT_NAME),
        WAREHOUSE_METERING (ACCOUNT_NAME) REFERENCES ACCOUNTS (ACCOUNT_NAME)
    )
    
    FACTS (
        -- Currency Cost Facts (actual dollar amounts)
        USAGE_CURRENCY.usage_amount AS USAGE_CURRENCY.USAGE
            WITH SYNONYMS ('credits used', 'usage credits')
            COMMENT = 'Credits consumed for the service',
        USAGE_CURRENCY.currency_amount AS USAGE_CURRENCY.USAGE_IN_CURRENCY
            WITH SYNONYMS ('dollar amount', 'cost in currency', 'actual cost', 'spend')
            COMMENT = 'Cost in actual currency (e.g., USD) — the real dollar spend',
            
        -- Contract Balance Facts
        REMAINING_BALANCE.free_usage AS REMAINING_BALANCE.FREE_USAGE_BALANCE
            WITH SYNONYMS ('free credits', 'trial balance')
            COMMENT = 'Remaining free usage balance',
        REMAINING_BALANCE.capacity_balance AS REMAINING_BALANCE.CAPACITY_BALANCE
            WITH SYNONYMS ('prepaid balance', 'capacity remaining', 'committed balance')
            COMMENT = 'Remaining prepaid capacity balance — tracks burn rate of committed spend',
        REMAINING_BALANCE.on_demand_balance AS REMAINING_BALANCE.ON_DEMAND_CONSUMPTION_BALANCE
            WITH SYNONYMS ('on demand balance', 'overage balance')
            COMMENT = 'On-demand consumption balance — tracks overage beyond capacity',
        REMAINING_BALANCE.rollover AS REMAINING_BALANCE.ROLLOVER_BALANCE
            WITH SYNONYMS ('rollover credits', 'carried over')
            COMMENT = 'Credits rolled over from previous contract period',
            
        -- Credit Metering Facts (per account)
        METERING_DAILY.credits_used AS METERING_DAILY.CREDITS_USED
            WITH SYNONYMS ('account credits', 'total credits')
            COMMENT = 'Total credits consumed by this account and service type',
        METERING_DAILY.credits_compute AS METERING_DAILY.CREDITS_USED_COMPUTE
            WITH SYNONYMS ('compute credits')
            COMMENT = 'Compute credits consumed',
        METERING_DAILY.credits_cloud AS METERING_DAILY.CREDITS_USED_CLOUD_SERVICES
            WITH SYNONYMS ('cloud service credits')
            COMMENT = 'Cloud service credits consumed',
        METERING_DAILY.credits_billed AS METERING_DAILY.CREDITS_BILLED
            WITH SYNONYMS ('billed credits', 'net billed')
            COMMENT = 'Actual billed credits after adjustments',
            
        -- Warehouse Metering Facts (per account per warehouse)
        WAREHOUSE_METERING.wh_credits AS WAREHOUSE_METERING.CREDITS_USED
            WITH SYNONYMS ('warehouse credits')
            COMMENT = 'Credits consumed by this warehouse in this account',
        WAREHOUSE_METERING.wh_compute_credits AS WAREHOUSE_METERING.CREDITS_USED_COMPUTE
            WITH SYNONYMS ('warehouse compute')
            COMMENT = 'Compute credits for this warehouse',
        WAREHOUSE_METERING.wh_cloud_credits AS WAREHOUSE_METERING.CREDITS_USED_CLOUD_SERVICES
            WITH SYNONYMS ('warehouse cloud credits')
            COMMENT = 'Cloud service credits for this warehouse'
    )
    
    DIMENSIONS (
        -- Account Dimensions (from ACCOUNTS table)
        ACCOUNTS.account_name AS ACCOUNTS.ACCOUNT_NAME
            WITH SYNONYMS ('account', 'snowflake account', 'acct')
            COMMENT = 'Snowflake account name',
        ACCOUNTS.account_locator AS ACCOUNTS.ACCOUNT_LOCATOR
            WITH SYNONYMS ('locator', 'account id')
            COMMENT = 'Account locator identifier',
        ACCOUNTS.region AS ACCOUNTS.REGION
            WITH SYNONYMS ('account region', 'cloud region', 'deployment region')
            COMMENT = 'Cloud region where the account is deployed',
        ACCOUNTS.region_group AS ACCOUNTS.REGION_GROUP
            WITH SYNONYMS ('region group')
            COMMENT = 'Region group (e.g., PUBLIC)',
        ACCOUNTS.edition AS ACCOUNTS.EDITION
            WITH SYNONYMS ('account edition', 'tier', 'plan')
            COMMENT = 'Snowflake edition: STANDARD, ENTERPRISE, BUSINESS_CRITICAL',
        ACCOUNTS.is_org_admin AS ACCOUNTS.IS_ORG_ADMIN
            WITH SYNONYMS ('org admin', 'admin account')
            COMMENT = 'Whether this account has ORGADMIN privileges',
        ACCOUNTS.is_locked AS ACCOUNTS.IS_LOCKED
            WITH SYNONYMS ('locked', 'suspended account')
            COMMENT = 'Whether the account is locked/suspended',
        ACCOUNTS.account_created AS ACCOUNTS.CREATED_ON
            WITH SYNONYMS ('account created', 'provisioned')
            COMMENT = 'When the account was created',
        ACCOUNTS.account_url AS ACCOUNTS.ACCOUNT_URL
            WITH SYNONYMS ('url', 'account link')
            COMMENT = 'URL for the account',
            
        -- Usage Currency Dimensions
        USAGE_CURRENCY.usage_date AS USAGE_CURRENCY.USAGE_DATE
            WITH SYNONYMS ('date', 'cost date', 'spend date')
            COMMENT = 'Date of the usage record',
        USAGE_CURRENCY.service_level AS USAGE_CURRENCY.SERVICE_LEVEL
            WITH SYNONYMS ('service level', 'edition level')
            COMMENT = 'Service level for the usage',
        USAGE_CURRENCY.usage_type AS USAGE_CURRENCY.USAGE_TYPE
            WITH SYNONYMS ('usage type', 'cost type', 'charge type')
            COMMENT = 'Type of usage: compute, storage, data transfer, etc.',
        USAGE_CURRENCY.currency AS USAGE_CURRENCY.CURRENCY
            WITH SYNONYMS ('currency code', 'denomination')
            COMMENT = 'Currency denomination (e.g., USD)',
        USAGE_CURRENCY.balance_source AS USAGE_CURRENCY.BALANCE_SOURCE
            WITH SYNONYMS ('billing source', 'payment source')
            COMMENT = 'Source of balance: capacity, free usage, overage',
        USAGE_CURRENCY.billing_type AS USAGE_CURRENCY.BILLING_TYPE
            WITH SYNONYMS ('billing type', 'pricing model')
            COMMENT = 'Billing model: usage, capacity, etc.',
        USAGE_CURRENCY.service_type AS USAGE_CURRENCY.SERVICE_TYPE
            WITH SYNONYMS ('service', 'feature')
            COMMENT = 'Snowflake service type generating the cost',
        USAGE_CURRENCY.rating_type AS USAGE_CURRENCY.RATING_TYPE
            WITH SYNONYMS ('rating type')
            COMMENT = 'How the usage is rated/priced',
            
        -- Remaining Balance Dimensions
        REMAINING_BALANCE.contract_number AS REMAINING_BALANCE.CONTRACT_NUMBER
            WITH SYNONYMS ('contract', 'contract id')
            COMMENT = 'Contract number for balance tracking',
        REMAINING_BALANCE.balance_date AS REMAINING_BALANCE.DATE
            WITH SYNONYMS ('balance date', 'snapshot date')
            COMMENT = 'Date of the balance snapshot',
        REMAINING_BALANCE.balance_currency AS REMAINING_BALANCE.CURRENCY
            WITH SYNONYMS ('balance currency')
            COMMENT = 'Currency of the balance amounts',
            
        -- Metering Daily Dimensions
        METERING_DAILY.metering_account AS METERING_DAILY.ACCOUNT_NAME
            WITH SYNONYMS ('metered account')
            COMMENT = 'Account being metered',
        METERING_DAILY.metering_service AS METERING_DAILY.SERVICE_TYPE
            WITH SYNONYMS ('metered service', 'service category')
            COMMENT = 'Service type: WAREHOUSE_METERING, AUTO_CLUSTERING, SERVERLESS_TASK, etc.',
        METERING_DAILY.metering_date AS METERING_DAILY.USAGE_DATE
            WITH SYNONYMS ('metering date')
            COMMENT = 'Date of the metering record',
        METERING_DAILY.metering_region AS METERING_DAILY.REGION
            WITH SYNONYMS ('metering region')
            COMMENT = 'Region of the metered account',
            
        -- Warehouse Metering Dimensions
        WAREHOUSE_METERING.wh_account AS WAREHOUSE_METERING.ACCOUNT_NAME
            WITH SYNONYMS ('warehouse account')
            COMMENT = 'Account owning the warehouse',
        WAREHOUSE_METERING.wh_name AS WAREHOUSE_METERING.WAREHOUSE_NAME
            WITH SYNONYMS ('warehouse', 'wh', 'compute cluster')
            COMMENT = 'Name of the virtual warehouse',
        WAREHOUSE_METERING.wh_start AS WAREHOUSE_METERING.START_TIME
            WITH SYNONYMS ('warehouse start', 'metering start')
            COMMENT = 'Start of the metering period',
        WAREHOUSE_METERING.wh_end AS WAREHOUSE_METERING.END_TIME
            WITH SYNONYMS ('warehouse end', 'metering end')
            COMMENT = 'End of the metering period',
        WAREHOUSE_METERING.wh_service_type AS WAREHOUSE_METERING.SERVICE_TYPE
            WITH SYNONYMS ('warehouse service type')
            COMMENT = 'Service type for warehouse metering',
        WAREHOUSE_METERING.wh_region AS WAREHOUSE_METERING.REGION
            WITH SYNONYMS ('warehouse region')
            COMMENT = 'Region of the warehouse'
    )
    
    METRICS (
        -- Currency Cost Metrics (the real dollar numbers)
        USAGE_CURRENCY.total_spend AS SUM(USAGE_CURRENCY.currency_amount)
            WITH SYNONYMS ('total cost', 'total spend', 'total dollars')
            COMMENT = 'Total spend in currency across all accounts and services',
        USAGE_CURRENCY.total_credits AS SUM(USAGE_CURRENCY.usage_amount)
            WITH SYNONYMS ('total usage credits')
            COMMENT = 'Total credits consumed across all accounts',
        USAGE_CURRENCY.avg_daily_spend AS AVG(USAGE_CURRENCY.currency_amount)
            WITH SYNONYMS ('average daily cost', 'avg spend')
            COMMENT = 'Average daily spend in currency',
            
        -- Contract Balance Metrics
        REMAINING_BALANCE.latest_capacity AS MAX(REMAINING_BALANCE.capacity_balance)
            WITH SYNONYMS ('current capacity', 'remaining prepaid')
            COMMENT = 'Latest capacity balance (use with MAX date filter)',
        REMAINING_BALANCE.latest_on_demand AS MAX(REMAINING_BALANCE.on_demand_balance)
            WITH SYNONYMS ('current overage')
            COMMENT = 'Latest on-demand balance',
            
        -- Credit Metering Metrics (per account comparison)
        METERING_DAILY.total_org_credits AS SUM(METERING_DAILY.credits_used)
            WITH SYNONYMS ('org total credits', 'organization credits')
            COMMENT = 'Total credits across all accounts in the organization',
        METERING_DAILY.total_org_billed AS SUM(METERING_DAILY.credits_billed)
            WITH SYNONYMS ('org total billed')
            COMMENT = 'Total billed credits across the organization',
        METERING_DAILY.account_count AS COUNT(DISTINCT METERING_DAILY.metering_account)
            WITH SYNONYMS ('number of accounts', 'active accounts')
            COMMENT = 'Number of accounts consuming credits',
            
        -- Warehouse Metrics (cross-account)
        WAREHOUSE_METERING.total_wh_credits AS SUM(WAREHOUSE_METERING.wh_credits)
            WITH SYNONYMS ('total warehouse cost', 'org warehouse credits')
            COMMENT = 'Total warehouse credits across all accounts',
        WAREHOUSE_METERING.warehouse_count AS COUNT(DISTINCT WAREHOUSE_METERING.wh_name)
            WITH SYNONYMS ('number of warehouses')
            COMMENT = 'Number of distinct warehouses across accounts',
        WAREHOUSE_METERING.avg_wh_credits AS AVG(WAREHOUSE_METERING.wh_credits)
            WITH SYNONYMS ('average warehouse cost')
            COMMENT = 'Average credits per warehouse metering period'
    )
    
    COMMENT = 'Organization-level analytics for cross-account cost comparison, contract balance tracking, and currency-denominated spending across all Snowflake accounts in the organization'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. Use USAGE_DATE or DATE for time-based filtering. USAGE_IN_CURRENCY is the actual dollar amount — use this for real cost analysis. CREDITS_USED is the credit consumption before currency conversion. CAPACITY_BALANCE tracks remaining prepaid credits — when it approaches zero, overage charges begin on ON_DEMAND_CONSUMPTION_BALANCE. To compare accounts, GROUP BY ACCOUNT_NAME. To see cost trends, GROUP BY DATE_TRUNC(month, USAGE_DATE). SERVICE_TYPE values include: WAREHOUSE_METERING, AUTO_CLUSTERING, SERVERLESS_TASK, MATERIALIZED_VIEW, PIPE, SEARCH_OPTIMIZATION. EDITION values: STANDARD, ENTERPRISE, BUSINESS_CRITICAL. For contract burn rate, calculate daily capacity decrease over time. The ACCOUNTS table links all cost data to account metadata (region, edition, admin status).'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Cross-account cost comparison (which accounts cost the most?), Currency-denominated spending (actual dollar amounts, not just credits), Contract balance tracking and burn rate, Capacity remaining and overage monitoring, Per-account warehouse costs, Organization-wide credit consumption trends, Account inventory and metadata (region, edition, locked status), Cost breakdown by service type across accounts, Monthly and daily spending trends across the organization.';


-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_WRITER;
GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_ADMIN;

GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_READER;


-- =============================================================================
-- VERIFICATION
-- =============================================================================

SHOW SEMANTIC VIEWS IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC;

SELECT '03_semantic_layer.sql completed - Enhanced Semantic Views created for Cortex Analyst' AS STATUS;
