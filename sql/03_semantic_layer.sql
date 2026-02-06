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
            PRIMARY KEY (START_TIME, WAREHOUSE_NAME)
            WITH SYNONYMS = ('warehouse usage', 'credit consumption', 'compute costs'),
            
        QUERY_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
            PRIMARY KEY (QUERY_ID)
            WITH SYNONYMS = ('queries', 'sql executions', 'query runs')
    )
    
    RELATIONSHIPS (
        QUERY_HISTORY(WAREHOUSE_NAME) REFERENCES WAREHOUSE_METERING(WAREHOUSE_NAME)
    )
    
    DIMENSIONS (
        WAREHOUSE_METERING.WAREHOUSE_NAME
            WITH SYNONYMS = ('warehouse', 'compute cluster')
            COMMENT = 'Name of the virtual warehouse',
        WAREHOUSE_METERING.START_TIME
            WITH SYNONYMS = ('metering start', 'usage start')
            COMMENT = 'Start time of the metering period',
        WAREHOUSE_METERING.END_TIME
            WITH SYNONYMS = ('metering end', 'usage end')
            COMMENT = 'End time of the metering period',
        QUERY_HISTORY.USER_NAME
            WITH SYNONYMS = ('user', 'query user', 'executor')
            COMMENT = 'User who executed the query',
        QUERY_HISTORY.ROLE_NAME
            WITH SYNONYMS = ('role', 'execution role')
            COMMENT = 'Role used to execute the query',
        QUERY_HISTORY.QUERY_TYPE
            WITH SYNONYMS = ('query type', 'statement type')
            COMMENT = 'Type of SQL statement',
        QUERY_HISTORY.DATABASE_NAME
            WITH SYNONYMS = ('database', 'db')
            COMMENT = 'Database context for the query',
        QUERY_HISTORY.WAREHOUSE_SIZE
            WITH SYNONYMS = ('size', 'warehouse size')
            COMMENT = 'Size of the warehouse used',
        QUERY_HISTORY.EXECUTION_STATUS
            WITH SYNONYMS = ('status', 'result status')
            COMMENT = 'Query execution status'
    )
    
    FACTS (
        WAREHOUSE_METERING.CREDITS_USED
            WITH SYNONYMS = ('credits', 'compute credits')
            COMMENT = 'Total credits consumed',
        WAREHOUSE_METERING.CREDITS_USED_COMPUTE
            WITH SYNONYMS = ('compute credits')
            COMMENT = 'Credits for compute resources',
        WAREHOUSE_METERING.CREDITS_USED_CLOUD_SERVICES
            WITH SYNONYMS = ('cloud credits', 'service credits')
            COMMENT = 'Credits for cloud services',
        QUERY_HISTORY.TOTAL_ELAPSED_TIME
            WITH SYNONYMS = ('duration', 'elapsed time', 'execution time')
            COMMENT = 'Total query execution time in milliseconds',
        QUERY_HISTORY.BYTES_SCANNED
            WITH SYNONYMS = ('bytes read', 'data scanned')
            COMMENT = 'Bytes scanned during query execution',
        QUERY_HISTORY.ROWS_PRODUCED
            WITH SYNONYMS = ('rows returned', 'result rows')
            COMMENT = 'Number of rows returned by the query'
    )
    
    METRICS (
        TOTAL_CREDITS AS SUM(WAREHOUSE_METERING.CREDITS_USED)
            WITH SYNONYMS = ('total cost', 'total credits used')
            COMMENT = 'Sum of all credits consumed',
        TOTAL_QUERIES AS COUNT(QUERY_HISTORY.QUERY_ID)
            WITH SYNONYMS = ('query count', 'number of queries')
            COMMENT = 'Total number of queries executed',
        AVG_QUERY_DURATION AS AVG(QUERY_HISTORY.TOTAL_ELAPSED_TIME)
            WITH SYNONYMS = ('average duration', 'mean execution time')
            COMMENT = 'Average query execution time',
        TOTAL_BYTES_SCANNED AS SUM(QUERY_HISTORY.BYTES_SCANNED)
            WITH SYNONYMS = ('total data scanned')
            COMMENT = 'Total bytes scanned across all queries'
    )
    
    COMMENT = 'Comprehensive cost analytics combining warehouse credits and query metrics'
    AI_SQL_GENERATION = 'Always filter with "_IS_CURRENT" = TRUE to get current records only. 
        Use START_TIME for time-based filtering on warehouse metering. 
        Credits are the unit of cost in Snowflake.
        When asked about costs, use CREDITS_USED from warehouse metering.'
    AI_QUESTION_CATEGORIZATION = 'This semantic view answers questions about:
        - Snowflake compute costs and credit consumption
        - Query execution patterns and performance
        - Warehouse utilization and efficiency
        - User and role-based cost allocation';


-- =============================================================================
-- SEMANTIC VIEW: SECURITY ANALYTICS
-- Login history and user activity for security auditing
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.SECURITY_ANALYTICS
    
    TABLES (
        LOGIN_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
            PRIMARY KEY (EVENT_ID)
            WITH SYNONYMS = ('logins', 'authentication events', 'sign-ins'),
            
        USERS AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
            PRIMARY KEY (USER_ID)
            WITH SYNONYMS = ('user accounts', 'user list')
    )
    
    RELATIONSHIPS (
        LOGIN_HISTORY(USER_NAME) REFERENCES USERS(NAME)
    )
    
    DIMENSIONS (
        LOGIN_HISTORY.USER_NAME
            WITH SYNONYMS = ('user', 'login user')
            COMMENT = 'Username attempting login',
        LOGIN_HISTORY.EVENT_TIMESTAMP
            WITH SYNONYMS = ('login time', 'event time')
            COMMENT = 'Timestamp of the login attempt',
        LOGIN_HISTORY.CLIENT_IP
            WITH SYNONYMS = ('ip address', 'source ip')
            COMMENT = 'IP address of the client',
        LOGIN_HISTORY.REPORTED_CLIENT_TYPE
            WITH SYNONYMS = ('client type', 'application')
            COMMENT = 'Type of client application used',
        LOGIN_HISTORY.FIRST_AUTHENTICATION_FACTOR
            WITH SYNONYMS = ('auth factor', 'primary auth')
            COMMENT = 'Primary authentication method',
        LOGIN_HISTORY.IS_SUCCESS
            WITH SYNONYMS = ('success', 'login success')
            COMMENT = 'Whether login was successful',
        LOGIN_HISTORY.ERROR_CODE
            WITH SYNONYMS = ('error', 'failure code')
            COMMENT = 'Error code if login failed',
        USERS.EMAIL
            WITH SYNONYMS = ('email address', 'user email')
            COMMENT = 'User email address',
        USERS.DEFAULT_ROLE
            WITH SYNONYMS = ('default role', 'primary role')
            COMMENT = 'Default role assigned to user',
        USERS.DISABLED
            WITH SYNONYMS = ('is disabled', 'account disabled')
            COMMENT = 'Whether user account is disabled',
        USERS.HAS_MFA
            WITH SYNONYMS = ('mfa enabled', 'multi-factor')
            COMMENT = 'Whether MFA is enabled for user'
    )
    
    FACTS (
        LOGIN_HISTORY.EVENT_ID
            COMMENT = 'Unique identifier for the login event'
    )
    
    METRICS (
        TOTAL_LOGINS AS COUNT(LOGIN_HISTORY.EVENT_ID)
            WITH SYNONYMS = ('login count', 'total attempts')
            COMMENT = 'Total number of login attempts',
        FAILED_LOGINS AS COUNT_IF(LOGIN_HISTORY.IS_SUCCESS = 'NO')
            WITH SYNONYMS = ('failed count', 'bad logins', 'failures')
            COMMENT = 'Number of failed login attempts',
        UNIQUE_USERS AS COUNT(DISTINCT LOGIN_HISTORY.USER_NAME)
            WITH SYNONYMS = ('distinct users', 'user count')
            COMMENT = 'Number of unique users attempting login'
    )
    
    COMMENT = 'Security analytics for login monitoring and access auditing'
    AI_SQL_GENERATION = 'Always filter with "_IS_CURRENT" = TRUE to get current records.
        IS_SUCCESS contains YES or NO as string values.
        Use EVENT_TIMESTAMP for time-based filtering on logins.
        Failed logins are security risks - highlight patterns.'
    AI_QUESTION_CATEGORIZATION = 'This semantic view answers questions about:
        - Login attempts and authentication events
        - Failed login patterns and security risks
        - User account status and MFA adoption
        - IP-based access patterns';


-- =============================================================================
-- SEMANTIC VIEW: STORAGE ANALYTICS
-- Database and table storage for capacity planning
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.STORAGE_ANALYTICS
    
    TABLES (
        STORAGE_USAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.STORAGE_USAGE_ARCHIVE
            PRIMARY KEY (USAGE_DATE)
            WITH SYNONYMS = ('storage', 'disk usage', 'data storage'),
            
        DATABASE_STORAGE AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY_ARCHIVE
            PRIMARY KEY (USAGE_DATE, DATABASE_NAME)
            WITH SYNONYMS = ('database storage', 'db storage')
    )
    
    DIMENSIONS (
        STORAGE_USAGE.USAGE_DATE
            WITH SYNONYMS = ('date', 'storage date')
            COMMENT = 'Date of storage measurement',
        DATABASE_STORAGE.DATABASE_NAME
            WITH SYNONYMS = ('database', 'db name')
            COMMENT = 'Name of the database'
    )
    
    FACTS (
        STORAGE_USAGE.AVERAGE_DATABASE_BYTES
            WITH SYNONYMS = ('database bytes', 'db storage bytes')
            COMMENT = 'Average database storage in bytes',
        STORAGE_USAGE.AVERAGE_STAGE_BYTES
            WITH SYNONYMS = ('stage bytes', 'staging storage')
            COMMENT = 'Average stage storage in bytes',
        STORAGE_USAGE.AVERAGE_FAILSAFE_BYTES
            WITH SYNONYMS = ('failsafe bytes', 'backup storage')
            COMMENT = 'Average failsafe storage in bytes',
        DATABASE_STORAGE.AVERAGE_DATABASE_BYTES AS DB_BYTES
            WITH SYNONYMS = ('database size')
            COMMENT = 'Database size in bytes',
        DATABASE_STORAGE.AVERAGE_FAILSAFE_BYTES AS DB_FAILSAFE_BYTES
            COMMENT = 'Database failsafe storage in bytes'
    )
    
    METRICS (
        TOTAL_STORAGE_BYTES AS SUM(STORAGE_USAGE.AVERAGE_DATABASE_BYTES)
            WITH SYNONYMS = ('total storage', 'total bytes')
            COMMENT = 'Total storage across all dates',
        TOTAL_STORAGE_TB AS SUM(STORAGE_USAGE.AVERAGE_DATABASE_BYTES) / POWER(1024, 4)
            WITH SYNONYMS = ('storage terabytes', 'tb used')
            COMMENT = 'Total storage in terabytes',
        AVG_DAILY_STORAGE AS AVG(STORAGE_USAGE.AVERAGE_DATABASE_BYTES)
            WITH SYNONYMS = ('average storage')
            COMMENT = 'Average daily storage usage'
    )
    
    COMMENT = 'Storage analytics for capacity planning and optimization'
    AI_SQL_GENERATION = 'Always filter with "_IS_CURRENT" = TRUE to get current records.
        Storage is measured in bytes - divide by 1024^3 for GB or 1024^4 for TB.
        Use USAGE_DATE for time-based trending.'
    AI_QUESTION_CATEGORIZATION = 'This semantic view answers questions about:
        - Storage consumption trends
        - Database size and growth
        - Capacity planning and forecasting
        - Stage and failsafe storage';


-- =============================================================================
-- SEMANTIC VIEW: GOVERNANCE ANALYTICS
-- User and role management for governance
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.GOVERNANCE_ANALYTICS
    
    TABLES (
        USERS AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
            PRIMARY KEY (USER_ID)
            WITH SYNONYMS = ('users', 'user accounts', 'principals'),
            
        ROLES AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ROLES_ARCHIVE
            PRIMARY KEY (ROLE_ID)
            WITH SYNONYMS = ('roles', 'security roles'),
            
        GRANTS_TO_USERS AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.GRANTS_TO_USERS_ARCHIVE
            PRIMARY KEY (CREATED_ON, ROLE, GRANTEE_NAME)
            WITH SYNONYMS = ('user grants', 'role assignments')
    )
    
    RELATIONSHIPS (
        GRANTS_TO_USERS(GRANTEE_NAME) REFERENCES USERS(NAME),
        GRANTS_TO_USERS(ROLE) REFERENCES ROLES(NAME)
    )
    
    DIMENSIONS (
        USERS.NAME AS USER_NAME
            WITH SYNONYMS = ('user', 'username')
            COMMENT = 'User account name',
        USERS.LOGIN_NAME
            WITH SYNONYMS = ('login', 'login id')
            COMMENT = 'Login identifier',
        USERS.EMAIL
            WITH SYNONYMS = ('email', 'user email')
            COMMENT = 'User email address',
        USERS.DEFAULT_WAREHOUSE
            WITH SYNONYMS = ('warehouse', 'default compute')
            COMMENT = 'Default warehouse for user',
        USERS.DEFAULT_ROLE
            WITH SYNONYMS = ('default role', 'primary role')
            COMMENT = 'Default role for user',
        USERS.CREATED_ON AS USER_CREATED
            WITH SYNONYMS = ('user created', 'account created')
            COMMENT = 'When user was created',
        USERS.DISABLED
            WITH SYNONYMS = ('is disabled', 'inactive')
            COMMENT = 'Whether user is disabled',
        USERS.HAS_MFA
            WITH SYNONYMS = ('mfa', 'multi-factor auth')
            COMMENT = 'Whether MFA is enabled',
        ROLES.NAME AS ROLE_NAME
            WITH SYNONYMS = ('role', 'security role')
            COMMENT = 'Role name',
        ROLES.OWNER AS ROLE_OWNER
            WITH SYNONYMS = ('role owner', 'owner')
            COMMENT = 'Owner of the role',
        ROLES.CREATED_ON AS ROLE_CREATED
            WITH SYNONYMS = ('role created')
            COMMENT = 'When role was created'
    )
    
    METRICS (
        TOTAL_USERS AS COUNT(DISTINCT USERS.USER_ID)
            WITH SYNONYMS = ('user count', 'number of users')
            COMMENT = 'Total number of users',
        ACTIVE_USERS AS COUNT_IF(USERS.DISABLED = FALSE)
            WITH SYNONYMS = ('enabled users', 'active count')
            COMMENT = 'Number of active (not disabled) users',
        DISABLED_USERS AS COUNT_IF(USERS.DISABLED = TRUE)
            WITH SYNONYMS = ('inactive users', 'disabled count')
            COMMENT = 'Number of disabled users',
        TOTAL_ROLES AS COUNT(DISTINCT ROLES.ROLE_ID)
            WITH SYNONYMS = ('role count', 'number of roles')
            COMMENT = 'Total number of roles'
    )
    
    COMMENT = 'User and role governance analytics'
    AI_SQL_GENERATION = 'Always filter with "_IS_CURRENT" = TRUE to get current records.
        DISABLED is a boolean - TRUE means user cannot log in.
        HAS_MFA is a boolean indicating multi-factor authentication status.'
    AI_QUESTION_CATEGORIZATION = 'This semantic view answers questions about:
        - User account management
        - Role assignments and hierarchy
        - Security posture and MFA adoption
        - Dormant or disabled accounts';


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
