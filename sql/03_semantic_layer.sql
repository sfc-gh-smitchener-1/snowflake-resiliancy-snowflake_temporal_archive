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
-- SEMANTIC VIEW: COST ANALYTICS
-- Combines warehouse metering with query history for cost analysis
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.COST_ANALYTICS
    
    TABLES (
        WAREHOUSE_METERING AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
            PRIMARY KEY (START_TIME, WAREHOUSE_ID)
            WITH SYNONYMS ('warehouse usage', 'credit consumption', 'compute costs'),
            
        QUERY_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
            PRIMARY KEY (QUERY_ID)
            WITH SYNONYMS ('queries', 'sql executions', 'query runs')
    )
    
    FACTS (
        WAREHOUSE_METERING.credits_used AS CREDITS_USED
            WITH SYNONYMS ('credits', 'compute credits')
            COMMENT = 'Total credits consumed',
        WAREHOUSE_METERING.credits_compute AS CREDITS_USED_COMPUTE
            WITH SYNONYMS ('compute credits')
            COMMENT = 'Credits for compute resources',
        WAREHOUSE_METERING.credits_cloud AS CREDITS_USED_CLOUD_SERVICES
            WITH SYNONYMS ('cloud credits', 'service credits')
            COMMENT = 'Credits for cloud services',
        QUERY_HISTORY.query_duration AS TOTAL_ELAPSED_TIME
            WITH SYNONYMS ('duration', 'elapsed time', 'execution time')
            COMMENT = 'Total query execution time in milliseconds',
        QUERY_HISTORY.bytes_scanned AS BYTES_SCANNED
            WITH SYNONYMS ('bytes read', 'data scanned')
            COMMENT = 'Bytes scanned during query execution',
        QUERY_HISTORY.rows_produced AS ROWS_PRODUCED
            WITH SYNONYMS ('rows returned', 'result rows')
            COMMENT = 'Number of rows returned by the query'
    )
    
    DIMENSIONS (
        WAREHOUSE_METERING.warehouse_name AS WAREHOUSE_NAME
            WITH SYNONYMS ('warehouse', 'compute cluster')
            COMMENT = 'Name of the virtual warehouse',
        WAREHOUSE_METERING.metering_start AS START_TIME
            WITH SYNONYMS ('metering start', 'usage start')
            COMMENT = 'Start time of the metering period',
        WAREHOUSE_METERING.metering_end AS END_TIME
            WITH SYNONYMS ('metering end', 'usage end')
            COMMENT = 'End time of the metering period',
        QUERY_HISTORY.query_user AS USER_NAME
            WITH SYNONYMS ('user', 'query user', 'executor')
            COMMENT = 'User who executed the query',
        QUERY_HISTORY.query_role AS ROLE_NAME
            WITH SYNONYMS ('role', 'execution role')
            COMMENT = 'Role used to execute the query',
        QUERY_HISTORY.query_type AS QUERY_TYPE
            WITH SYNONYMS ('query type', 'statement type')
            COMMENT = 'Type of SQL statement',
        QUERY_HISTORY.database_name AS DATABASE_NAME
            WITH SYNONYMS ('database', 'db')
            COMMENT = 'Database context for the query',
        QUERY_HISTORY.warehouse_size AS WAREHOUSE_SIZE
            WITH SYNONYMS ('size', 'warehouse size')
            COMMENT = 'Size of the warehouse used',
        QUERY_HISTORY.execution_status AS EXECUTION_STATUS
            WITH SYNONYMS ('status', 'result status')
            COMMENT = 'Query execution status'
    )
    
    METRICS (
        WAREHOUSE_METERING.total_credits AS SUM(CREDITS_USED)
            WITH SYNONYMS ('total cost', 'total credits used')
            COMMENT = 'Sum of all credits consumed',
        QUERY_HISTORY.total_queries AS COUNT(QUERY_ID)
            WITH SYNONYMS ('query count', 'number of queries')
            COMMENT = 'Total number of queries executed',
        QUERY_HISTORY.avg_query_duration AS AVG(TOTAL_ELAPSED_TIME)
            WITH SYNONYMS ('average duration', 'mean execution time')
            COMMENT = 'Average query execution time',
        QUERY_HISTORY.total_bytes_scanned AS SUM(BYTES_SCANNED)
            WITH SYNONYMS ('total data scanned')
            COMMENT = 'Total bytes scanned across all queries'
    )
    
    COMMENT = 'Comprehensive cost analytics combining warehouse credits and query metrics'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records only. Use START_TIME for time-based filtering on warehouse metering. Credits are the unit of cost in Snowflake.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Snowflake compute costs and credit consumption, Query execution patterns and performance, Warehouse utilization and efficiency.';


-- =============================================================================
-- SEMANTIC VIEW: SECURITY ANALYTICS
-- Login history and user activity for security auditing
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.SECURITY_ANALYTICS
    
    TABLES (
        LOGIN_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
            PRIMARY KEY (EVENT_ID)
            WITH SYNONYMS ('logins', 'authentication events', 'sign-ins'),
            
        USERS AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
            PRIMARY KEY (USER_ID)
            UNIQUE (NAME)
            WITH SYNONYMS ('user accounts', 'user list')
    )
    
    RELATIONSHIPS (
        LOGIN_HISTORY (USER_NAME) REFERENCES USERS (NAME)
    )
    
    FACTS (
        LOGIN_HISTORY.event_id AS EVENT_ID
            COMMENT = 'Unique identifier for the login event'
    )
    
    DIMENSIONS (
        LOGIN_HISTORY.login_user AS USER_NAME
            WITH SYNONYMS ('user', 'login user')
            COMMENT = 'Username attempting login',
        LOGIN_HISTORY.login_time AS EVENT_TIMESTAMP
            WITH SYNONYMS ('login time', 'event time')
            COMMENT = 'Timestamp of the login attempt',
        LOGIN_HISTORY.client_ip AS CLIENT_IP
            WITH SYNONYMS ('ip address', 'source ip')
            COMMENT = 'IP address of the client',
        LOGIN_HISTORY.client_type AS REPORTED_CLIENT_TYPE
            WITH SYNONYMS ('client type', 'application')
            COMMENT = 'Type of client application used',
        LOGIN_HISTORY.auth_factor AS FIRST_AUTHENTICATION_FACTOR
            WITH SYNONYMS ('auth factor', 'primary auth')
            COMMENT = 'Primary authentication method',
        LOGIN_HISTORY.login_success AS IS_SUCCESS
            WITH SYNONYMS ('success', 'login success')
            COMMENT = 'Whether login was successful',
        LOGIN_HISTORY.error_code AS ERROR_CODE
            WITH SYNONYMS ('error', 'failure code')
            COMMENT = 'Error code if login failed',
        USERS.user_email AS EMAIL
            WITH SYNONYMS ('email address', 'user email')
            COMMENT = 'User email address',
        USERS.default_role AS DEFAULT_ROLE
            WITH SYNONYMS ('default role', 'primary role')
            COMMENT = 'Default role assigned to user',
        USERS.user_disabled AS DISABLED
            WITH SYNONYMS ('is disabled', 'account disabled')
            COMMENT = 'Whether user account is disabled',
        USERS.has_mfa AS HAS_MFA
            WITH SYNONYMS ('mfa enabled', 'multi-factor')
            COMMENT = 'Whether MFA is enabled for user'
    )
    
    METRICS (
        LOGIN_HISTORY.total_logins AS COUNT(EVENT_ID)
            WITH SYNONYMS ('login count', 'total attempts')
            COMMENT = 'Total number of login attempts',
        LOGIN_HISTORY.failed_logins AS SUM(CASE WHEN IS_SUCCESS = 'NO' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('failed count', 'bad logins', 'failures')
            COMMENT = 'Number of failed login attempts',
        LOGIN_HISTORY.unique_users AS COUNT(DISTINCT USER_NAME)
            WITH SYNONYMS ('distinct users', 'user count')
            COMMENT = 'Number of unique users attempting login'
    )
    
    COMMENT = 'Security analytics for login monitoring and access auditing'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. IS_SUCCESS contains YES or NO as string values. Use EVENT_TIMESTAMP for time-based filtering on logins.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Login attempts and authentication events, Failed login patterns and security risks, User account status and MFA adoption.';


-- =============================================================================
-- SEMANTIC VIEW: STORAGE ANALYTICS
-- Database and table storage for capacity planning
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.STORAGE_ANALYTICS
    
    TABLES (
        STORAGE_USAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.STORAGE_USAGE_ARCHIVE
            PRIMARY KEY (USAGE_DATE)
            WITH SYNONYMS ('storage', 'disk usage', 'data storage'),
            
        DATABASE_STORAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY_ARCHIVE
            PRIMARY KEY (USAGE_DATE, DATABASE_ID)
            WITH SYNONYMS ('database storage', 'db storage')
    )
    
    FACTS (
        STORAGE_USAGE.database_bytes AS AVERAGE_DATABASE_BYTES
            WITH SYNONYMS ('database bytes', 'db storage bytes')
            COMMENT = 'Average database storage in bytes',
        STORAGE_USAGE.stage_bytes AS AVERAGE_STAGE_BYTES
            WITH SYNONYMS ('stage bytes', 'staging storage')
            COMMENT = 'Average stage storage in bytes',
        STORAGE_USAGE.failsafe_bytes AS AVERAGE_FAILSAFE_BYTES
            WITH SYNONYMS ('failsafe bytes', 'backup storage')
            COMMENT = 'Average failsafe storage in bytes',
        DATABASE_STORAGE.db_bytes AS AVERAGE_DATABASE_BYTES
            WITH SYNONYMS ('database size')
            COMMENT = 'Database size in bytes',
        DATABASE_STORAGE.db_failsafe_bytes AS AVERAGE_FAILSAFE_BYTES
            COMMENT = 'Database failsafe storage in bytes'
    )
    
    DIMENSIONS (
        STORAGE_USAGE.storage_date AS USAGE_DATE
            WITH SYNONYMS ('date', 'storage date')
            COMMENT = 'Date of storage measurement',
        DATABASE_STORAGE.database_name AS DATABASE_NAME
            WITH SYNONYMS ('database', 'db name')
            COMMENT = 'Name of the database'
    )
    
    METRICS (
        STORAGE_USAGE.total_storage_bytes AS SUM(AVERAGE_DATABASE_BYTES)
            WITH SYNONYMS ('total storage', 'total bytes')
            COMMENT = 'Total storage across all dates',
        STORAGE_USAGE.total_storage_tb AS SUM(AVERAGE_DATABASE_BYTES) / POWER(1024, 4)
            WITH SYNONYMS ('storage terabytes', 'tb used')
            COMMENT = 'Total storage in terabytes',
        STORAGE_USAGE.avg_daily_storage AS AVG(AVERAGE_DATABASE_BYTES)
            WITH SYNONYMS ('average storage')
            COMMENT = 'Average daily storage usage'
    )
    
    COMMENT = 'Storage analytics for capacity planning and optimization'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. Storage is measured in bytes - divide by 1024^3 for GB or 1024^4 for TB. Use USAGE_DATE for time-based trending.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: Storage consumption trends, Database size and growth, Capacity planning and forecasting.';


-- =============================================================================
-- SEMANTIC VIEW: GOVERNANCE ANALYTICS
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
            WITH SYNONYMS ('user grants', 'role assignments')
    )
    
    RELATIONSHIPS (
        GRANTS_TO_USERS (GRANTEE_NAME) REFERENCES USERS (NAME),
        GRANTS_TO_USERS (ROLE) REFERENCES ROLES (NAME)
    )
    
    DIMENSIONS (
        USERS.user_name AS NAME
            WITH SYNONYMS ('user', 'username')
            COMMENT = 'User account name',
        USERS.login_name AS LOGIN_NAME
            WITH SYNONYMS ('login', 'login id')
            COMMENT = 'Login identifier',
        USERS.user_email AS EMAIL
            WITH SYNONYMS ('email', 'user email')
            COMMENT = 'User email address',
        USERS.default_warehouse AS DEFAULT_WAREHOUSE
            WITH SYNONYMS ('warehouse', 'default compute')
            COMMENT = 'Default warehouse for user',
        USERS.default_role AS DEFAULT_ROLE
            WITH SYNONYMS ('default role', 'primary role')
            COMMENT = 'Default role for user',
        USERS.user_created AS CREATED_ON
            WITH SYNONYMS ('user created', 'account created')
            COMMENT = 'When user was created',
        USERS.user_disabled AS DISABLED
            WITH SYNONYMS ('is disabled', 'inactive')
            COMMENT = 'Whether user is disabled',
        USERS.has_mfa AS HAS_MFA
            WITH SYNONYMS ('mfa', 'multi-factor auth')
            COMMENT = 'Whether MFA is enabled',
        ROLES.role_name AS NAME
            WITH SYNONYMS ('role', 'security role')
            COMMENT = 'Role name',
        ROLES.role_owner AS OWNER
            WITH SYNONYMS ('role owner', 'owner')
            COMMENT = 'Owner of the role',
        ROLES.role_created AS CREATED_ON
            WITH SYNONYMS ('role created')
            COMMENT = 'When role was created'
    )
    
    METRICS (
        USERS.total_users AS COUNT(DISTINCT USER_ID)
            WITH SYNONYMS ('user count', 'number of users')
            COMMENT = 'Total number of users',
        USERS.active_users AS SUM(CASE WHEN DISABLED = FALSE THEN 1 ELSE 0 END)
            WITH SYNONYMS ('enabled users', 'active count')
            COMMENT = 'Number of active (not disabled) users',
        USERS.disabled_users AS SUM(CASE WHEN DISABLED = TRUE THEN 1 ELSE 0 END)
            WITH SYNONYMS ('inactive users', 'disabled count')
            COMMENT = 'Number of disabled users',
        ROLES.total_roles AS COUNT(DISTINCT ROLE_ID)
            WITH SYNONYMS ('role count', 'number of roles')
            COMMENT = 'Total number of roles'
    )
    
    COMMENT = 'User and role governance analytics'
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records. DISABLED is a boolean - TRUE means user cannot log in. HAS_MFA is a boolean indicating multi-factor authentication status.'
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about: User account management, Role assignments and hierarchy, Security posture and MFA adoption.';


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

SELECT '03_semantic_layer.sql completed - Native Semantic Views created for Cortex Analyst' AS STATUS;
