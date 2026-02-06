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
    COMMENT = 'Comprehensive cost analytics combining warehouse credits and query metrics'
    
    TABLES (
        WAREHOUSE_METERING (
            TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
            PRIMARY KEY (START_TIME, WAREHOUSE_NAME)
            SYNONYMS ('warehouse usage', 'credit consumption', 'compute costs')
        ),
        QUERY_HISTORY (
            TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
            PRIMARY KEY (QUERY_ID)
            SYNONYMS ('queries', 'sql executions', 'query runs')
        )
    )
    
    RELATIONSHIPS (
        QUERY_HISTORY(WAREHOUSE_NAME) REFERENCES WAREHOUSE_METERING(WAREHOUSE_NAME)
    )
    
    DIMENSIONS (
        -- Warehouse dimensions
        WAREHOUSE_METERING.WAREHOUSE_NAME
            SYNONYMS ('warehouse', 'compute cluster')
            COMMENT 'Name of the virtual warehouse',
        WAREHOUSE_METERING.START_TIME
            SYNONYMS ('metering start', 'usage start')
            COMMENT 'Start time of the metering period',
        WAREHOUSE_METERING.END_TIME
            SYNONYMS ('metering end', 'usage end')
            COMMENT 'End time of the metering period',
            
        -- Query dimensions
        QUERY_HISTORY.USER_NAME
            SYNONYMS ('user', 'query user', 'executor')
            COMMENT 'User who executed the query',
        QUERY_HISTORY.ROLE_NAME
            SYNONYMS ('role', 'execution role')
            COMMENT 'Role used to execute the query',
        QUERY_HISTORY.QUERY_TYPE
            SYNONYMS ('query type', 'statement type')
            COMMENT 'Type of SQL statement',
        QUERY_HISTORY.DATABASE_NAME
            SYNONYMS ('database', 'db')
            COMMENT 'Database context for the query',
        QUERY_HISTORY.WAREHOUSE_SIZE
            SYNONYMS ('size', 'warehouse size')
            COMMENT 'Size of the warehouse used',
        QUERY_HISTORY.EXECUTION_STATUS
            SYNONYMS ('status', 'result status')
            COMMENT 'Query execution status'
    )
    
    FACTS (
        WAREHOUSE_METERING.CREDITS_USED
            SYNONYMS ('credits', 'compute credits')
            COMMENT 'Total credits consumed',
        WAREHOUSE_METERING.CREDITS_USED_COMPUTE
            SYNONYMS ('compute credits')
            COMMENT 'Credits for compute resources',
        WAREHOUSE_METERING.CREDITS_USED_CLOUD_SERVICES
            SYNONYMS ('cloud credits', 'service credits')
            COMMENT 'Credits for cloud services',
        QUERY_HISTORY.TOTAL_ELAPSED_TIME
            SYNONYMS ('duration', 'elapsed time', 'execution time')
            COMMENT 'Total query execution time in milliseconds',
        QUERY_HISTORY.BYTES_SCANNED
            SYNONYMS ('bytes read', 'data scanned')
            COMMENT 'Bytes scanned during query execution',
        QUERY_HISTORY.ROWS_PRODUCED
            SYNONYMS ('rows returned', 'result rows')
            COMMENT 'Number of rows returned by the query'
    )
    
    METRICS (
        TOTAL_CREDITS AS SUM(WAREHOUSE_METERING.CREDITS_USED)
            SYNONYMS ('total cost', 'total credits used')
            COMMENT 'Sum of all credits consumed',
        TOTAL_QUERIES AS COUNT(QUERY_HISTORY.QUERY_ID)
            SYNONYMS ('query count', 'number of queries')
            COMMENT 'Total number of queries executed',
        AVG_QUERY_DURATION AS AVG(QUERY_HISTORY.TOTAL_ELAPSED_TIME)
            SYNONYMS ('average duration', 'mean execution time')
            COMMENT 'Average query execution time',
        TOTAL_BYTES_SCANNED AS SUM(QUERY_HISTORY.BYTES_SCANNED)
            SYNONYMS ('total data scanned')
            COMMENT 'Total bytes scanned across all queries'
    )
    
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records only. 
        Use START_TIME for time-based filtering on warehouse metering. 
        Credits are the unit of cost in Snowflake.
        When asked about costs, use CREDITS_USED from warehouse metering.'
        
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about:
        - Snowflake compute costs and credit consumption
        - Query execution patterns and performance
        - Warehouse utilization and efficiency
        - User and role-based cost allocation';


-- =============================================================================
-- SEMANTIC VIEW: SECURITY ANALYTICS
-- Login history and user activity for security auditing
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.SECURITY_ANALYTICS
    COMMENT = 'Security analytics for login monitoring and access auditing'
    
    TABLES (
        LOGIN_HISTORY (
            TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
            PRIMARY KEY (EVENT_ID)
            SYNONYMS ('logins', 'authentication events', 'sign-ins')
        ),
        USERS (
            TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
            PRIMARY KEY (USER_ID)
            SYNONYMS ('user accounts', 'user list')
        )
    )
    
    RELATIONSHIPS (
        LOGIN_HISTORY(USER_NAME) REFERENCES USERS(NAME)
    )
    
    DIMENSIONS (
        -- Login dimensions
        LOGIN_HISTORY.USER_NAME
            SYNONYMS ('user', 'login user')
            COMMENT 'Username attempting login',
        LOGIN_HISTORY.EVENT_TIMESTAMP
            SYNONYMS ('login time', 'event time')
            COMMENT 'Timestamp of the login attempt',
        LOGIN_HISTORY.CLIENT_IP
            SYNONYMS ('ip address', 'source ip')
            COMMENT 'IP address of the client',
        LOGIN_HISTORY.REPORTED_CLIENT_TYPE
            SYNONYMS ('client type', 'application')
            COMMENT 'Type of client application used',
        LOGIN_HISTORY.FIRST_AUTHENTICATION_FACTOR
            SYNONYMS ('auth factor', 'primary auth')
            COMMENT 'Primary authentication method',
        LOGIN_HISTORY.IS_SUCCESS
            SYNONYMS ('success', 'login success')
            COMMENT 'Whether login was successful',
        LOGIN_HISTORY.ERROR_CODE
            SYNONYMS ('error', 'failure code')
            COMMENT 'Error code if login failed',
            
        -- User dimensions
        USERS.EMAIL
            SYNONYMS ('email address', 'user email')
            COMMENT 'User email address',
        USERS.DEFAULT_ROLE
            SYNONYMS ('default role', 'primary role')
            COMMENT 'Default role assigned to user',
        USERS.DISABLED
            SYNONYMS ('is disabled', 'account disabled')
            COMMENT 'Whether user account is disabled',
        USERS.HAS_MFA
            SYNONYMS ('mfa enabled', 'multi-factor')
            COMMENT 'Whether MFA is enabled for user'
    )
    
    FACTS (
        LOGIN_HISTORY.EVENT_ID
            COMMENT 'Unique identifier for the login event'
    )
    
    METRICS (
        TOTAL_LOGINS AS COUNT(LOGIN_HISTORY.EVENT_ID)
            SYNONYMS ('login count', 'total attempts')
            COMMENT 'Total number of login attempts',
        SUCCESSFUL_LOGINS AS COUNT_IF(LOGIN_HISTORY.IS_SUCCESS = 'YES')
            SYNONYMS ('successful count', 'good logins')
            COMMENT 'Number of successful logins',
        FAILED_LOGINS AS COUNT_IF(LOGIN_HISTORY.IS_SUCCESS = 'NO')
            SYNONYMS ('failed count', 'bad logins', 'failures')
            COMMENT 'Number of failed login attempts',
        UNIQUE_USERS AS COUNT(DISTINCT LOGIN_HISTORY.USER_NAME)
            SYNONYMS ('distinct users', 'user count')
            COMMENT 'Number of unique users attempting login',
        MFA_ENABLED_USERS AS COUNT_IF(USERS.HAS_MFA = TRUE)
            SYNONYMS ('mfa count')
            COMMENT 'Number of users with MFA enabled'
    )
    
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records.
        IS_SUCCESS contains YES or NO as string values.
        Use EVENT_TIMESTAMP for time-based filtering on logins.
        Failed logins are security risks - highlight patterns.'
        
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about:
        - Login attempts and authentication events
        - Failed login patterns and security risks
        - User account status and MFA adoption
        - IP-based access patterns';


-- =============================================================================
-- SEMANTIC VIEW: STORAGE ANALYTICS
-- Database and table storage for capacity planning
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.STORAGE_ANALYTICS
    COMMENT = 'Storage analytics for capacity planning and optimization'
    
    TABLES (
        STORAGE_USAGE (
            TEMPORAL_ARCHIVE.ACCOUNT_USAGE.STORAGE_USAGE_ARCHIVE
            PRIMARY KEY (USAGE_DATE)
            SYNONYMS ('storage', 'disk usage', 'data storage')
        ),
        DATABASE_STORAGE (
            TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY_ARCHIVE
            PRIMARY KEY (USAGE_DATE, DATABASE_NAME)
            SYNONYMS ('database storage', 'db storage')
        )
    )
    
    DIMENSIONS (
        STORAGE_USAGE.USAGE_DATE
            SYNONYMS ('date', 'storage date')
            COMMENT 'Date of storage measurement',
        DATABASE_STORAGE.DATABASE_NAME
            SYNONYMS ('database', 'db name')
            COMMENT 'Name of the database'
    )
    
    FACTS (
        STORAGE_USAGE.AVERAGE_DATABASE_BYTES
            SYNONYMS ('database bytes', 'db storage bytes')
            COMMENT 'Average database storage in bytes',
        STORAGE_USAGE.AVERAGE_STAGE_BYTES
            SYNONYMS ('stage bytes', 'staging storage')
            COMMENT 'Average stage storage in bytes',
        STORAGE_USAGE.AVERAGE_FAILSAFE_BYTES
            SYNONYMS ('failsafe bytes', 'backup storage')
            COMMENT 'Average failsafe storage in bytes',
        DATABASE_STORAGE.AVERAGE_DATABASE_BYTES AS DB_BYTES
            SYNONYMS ('database size')
            COMMENT 'Database size in bytes',
        DATABASE_STORAGE.AVERAGE_FAILSAFE_BYTES AS DB_FAILSAFE_BYTES
            COMMENT 'Database failsafe storage in bytes'
    )
    
    METRICS (
        TOTAL_STORAGE_BYTES AS SUM(STORAGE_USAGE.AVERAGE_DATABASE_BYTES)
            SYNONYMS ('total storage', 'total bytes')
            COMMENT 'Total storage across all dates',
        TOTAL_STORAGE_TB AS SUM(STORAGE_USAGE.AVERAGE_DATABASE_BYTES) / POWER(1024, 4)
            SYNONYMS ('storage terabytes', 'tb used')
            COMMENT 'Total storage in terabytes',
        AVG_DAILY_STORAGE AS AVG(STORAGE_USAGE.AVERAGE_DATABASE_BYTES)
            SYNONYMS ('average storage')
            COMMENT 'Average daily storage usage'
    )
    
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records.
        Storage is measured in bytes - divide by 1024^3 for GB or 1024^4 for TB.
        Use USAGE_DATE for time-based trending.'
        
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about:
        - Storage consumption trends
        - Database size and growth
        - Capacity planning and forecasting
        - Stage and failsafe storage';


-- =============================================================================
-- SEMANTIC VIEW: USER & ROLE ANALYTICS
-- User and role management for governance
-- =============================================================================

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.GOVERNANCE_ANALYTICS
    COMMENT = 'User and role governance analytics'
    
    TABLES (
        USERS (
            TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
            PRIMARY KEY (USER_ID)
            SYNONYMS ('users', 'user accounts', 'principals')
        ),
        ROLES (
            TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ROLES_ARCHIVE
            PRIMARY KEY (ROLE_ID)
            SYNONYMS ('roles', 'security roles')
        ),
        GRANTS_TO_USERS (
            TEMPORAL_ARCHIVE.ACCOUNT_USAGE.GRANTS_TO_USERS_ARCHIVE
            PRIMARY KEY (CREATED_ON, ROLE, GRANTEE_NAME)
            SYNONYMS ('user grants', 'role assignments')
        )
    )
    
    RELATIONSHIPS (
        GRANTS_TO_USERS(GRANTEE_NAME) REFERENCES USERS(NAME),
        GRANTS_TO_USERS(ROLE) REFERENCES ROLES(NAME)
    )
    
    DIMENSIONS (
        USERS.NAME AS USER_NAME
            SYNONYMS ('user', 'username')
            COMMENT 'User account name',
        USERS.LOGIN_NAME
            SYNONYMS ('login', 'login id')
            COMMENT 'Login identifier',
        USERS.EMAIL
            SYNONYMS ('email', 'user email')
            COMMENT 'User email address',
        USERS.DEFAULT_WAREHOUSE
            SYNONYMS ('warehouse', 'default compute')
            COMMENT 'Default warehouse for user',
        USERS.DEFAULT_ROLE
            SYNONYMS ('default role', 'primary role')
            COMMENT 'Default role for user',
        USERS.CREATED_ON AS USER_CREATED
            SYNONYMS ('user created', 'account created')
            COMMENT 'When user was created',
        USERS.DISABLED
            SYNONYMS ('is disabled', 'inactive')
            COMMENT 'Whether user is disabled',
        USERS.HAS_MFA
            SYNONYMS ('mfa', 'multi-factor auth')
            COMMENT 'Whether MFA is enabled',
        ROLES.NAME AS ROLE_NAME
            SYNONYMS ('role', 'security role')
            COMMENT 'Role name',
        ROLES.OWNER AS ROLE_OWNER
            SYNONYMS ('role owner', 'owner')
            COMMENT 'Owner of the role',
        ROLES.CREATED_ON AS ROLE_CREATED
            SYNONYMS ('role created')
            COMMENT 'When role was created'
    )
    
    METRICS (
        TOTAL_USERS AS COUNT(DISTINCT USERS.USER_ID)
            SYNONYMS ('user count', 'number of users')
            COMMENT 'Total number of users',
        ACTIVE_USERS AS COUNT_IF(USERS.DISABLED = FALSE)
            SYNONYMS ('enabled users', 'active count')
            COMMENT 'Number of active (not disabled) users',
        DISABLED_USERS AS COUNT_IF(USERS.DISABLED = TRUE)
            SYNONYMS ('inactive users', 'disabled count')
            COMMENT 'Number of disabled users',
        MFA_ADOPTION AS COUNT_IF(USERS.HAS_MFA = TRUE) / NULLIF(COUNT(USERS.USER_ID), 0) * 100
            SYNONYMS ('mfa percentage', 'mfa rate')
            COMMENT 'Percentage of users with MFA enabled',
        TOTAL_ROLES AS COUNT(DISTINCT ROLES.ROLE_ID)
            SYNONYMS ('role count', 'number of roles')
            COMMENT 'Total number of roles'
    )
    
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records.
        DISABLED is a boolean - TRUE means user cannot log in.
        HAS_MFA is a boolean indicating multi-factor authentication status.'
        
    AI_QUESTION_CATEGORIZATION 'This semantic view answers questions about:
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
