-- ============================================================================
-- SNOWFLAKE TEMPORAL ARCHIVE - MASTER DEPLOYMENT ORCHESTRATOR
-- ============================================================================
-- 
-- This script deploys the complete Temporal Archive solution in sequence.
--
-- DEPLOYMENT ROLES:
--   • 01_initial_setup.sql: Run by ACCOUNTADMIN/SECURITYADMIN (one-time)
--   • 02-05 scripts: Run by DATA_ADMIN (owns all objects)
--
-- Reference: https://docs.snowflake.com/en/user-guide/backups
--
-- Deployment Order:
--   1. 01_initial_setup.sql     - Creates DATA_ADMIN role, database, warehouse
--   2. 02_scd_load.sql          - SCD Type 2 procedures and Tasks
--   3. 03_semantic_layer.sql    - Semantic Views for Cortex Analyst
--   4. 04_streamlit_ddl.sql     - Streamlit support objects
--   5. 05_streamlit_app.sql     - Streamlit application deployment
--
-- PREREQUISITES:
--   - ACCOUNTADMIN role access (for 01_initial_setup.sql only)
--   - Business Critical Edition (for RETENTION LOCK backup policy)
--   - Cortex enabled on the account
--
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- PRE-FLIGHT CHECK
-- ═══════════════════════════════════════════════════════════════════════════

-- NOTE: 01_initial_setup.sql starts with ACCOUNTADMIN, then switches to DATA_ADMIN
USE ROLE ACCOUNTADMIN;

SELECT 
       '╔═══════════════════════════════════════════════════════════════════════╗' AS LINE UNION ALL
SELECT '║       SNOWFLAKE TEMPORAL ARCHIVE - DEPLOYMENT STARTING                ║' UNION ALL
SELECT '╚═══════════════════════════════════════════════════════════════════════╝' UNION ALL
SELECT '' UNION ALL
SELECT 'Timestamp: ' || CURRENT_TIMESTAMP()::VARCHAR UNION ALL
SELECT 'Account:   ' || CURRENT_ACCOUNT() UNION ALL
SELECT 'User:      ' || CURRENT_USER() UNION ALL
SELECT 'Reference: https://docs.snowflake.com/en/user-guide/backups';


-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 1: INITIAL SETUP (Run as ACCOUNTADMIN - one time only)
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '>>> Step 1: Running initial setup (creates DATA_ADMIN role, database, backup policy)...' AS STATUS;

-- Run: sql/01_initial_setup.sql
-- This creates:
--   - DATA_ADMIN role (owner of all objects)
--   - TEMPORAL_ARCHIVE database (owned by DATA_ADMIN)
--   - ARCHIVE, ACCOUNT_USAGE, ORGANIZATION_USAGE, DATA_SHARING_USAGE schemas
--   - TEMPORAL_ARCHIVE_WH warehouse (owned by DATA_ADMIN)
--   - TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY with RETENTION LOCK (7 years)
--   - Subordinate roles: TEMPORAL_ARCHIVE_READER, TEMPORAL_ARCHIVE_WRITER, TEMPORAL_ARCHIVE_ADMIN
--   - Grants DATA_ADMIN access to SNOWFLAKE.ACCOUNT_USAGE and EXECUTE TASK


-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 2: SCD LOAD PROCEDURES AND TASKS (Run as DATA_ADMIN)
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '>>> Step 2: Creating SCD Type 2 load procedures and scheduled Tasks...' AS STATUS;

-- Run: sql/02_scd_load.sql (as DATA_ADMIN)
-- This creates:
--   - TABLE_REGISTRY for source-to-target mappings
--   - RUN_SCD_LOAD() main procedure
--   - TASK_SCD_LOAD_MORNING (6 AM)
--   - TASK_SCD_LOAD_EVENING (6 PM)


-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 3: SEMANTIC LAYER (Run as DATA_ADMIN)
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '>>> Step 3: Creating semantic views for Cortex Analyst...' AS STATUS;

-- Run: sql/03_semantic_layer.sql (as DATA_ADMIN)
-- This creates:
--   - Semantic views for ACCOUNT_USAGE archive tables
--   - Dimensions and metrics for natural language queries
--   - BUILD_SEMANTIC_LAYER() procedure


-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 4: STREAMLIT DDL (Run as DATA_ADMIN)
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '>>> Step 4: Creating Streamlit support objects...' AS STATUS;

-- Run: sql/04_streamlit_ddl.sql (as DATA_ADMIN)
-- This creates:
--   - STREAMLIT schema
--   - Helper views for the app
--   - Configuration tables
--   - Support procedures


-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 5: STREAMLIT APP DEPLOYMENT (Run as DATA_ADMIN)
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '>>> Step 5: Deploying Streamlit application...' AS STATUS;

-- Run: sql/05_streamlit_app.sql (as DATA_ADMIN)
-- Upload: src/app.py to stage
-- This creates:
--   - TEMPORAL_ARCHIVE_APP Streamlit application


-- ═══════════════════════════════════════════════════════════════════════════
-- DEPLOYMENT COMPLETE
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 
       '╔═══════════════════════════════════════════════════════════════════════╗' AS LINE UNION ALL
SELECT '║       SNOWFLAKE TEMPORAL ARCHIVE - DEPLOYMENT COMPLETE                ║' UNION ALL
SELECT '╚═══════════════════════════════════════════════════════════════════════╝' UNION ALL
SELECT '' UNION ALL
SELECT 'Completed: ' || CURRENT_TIMESTAMP()::VARCHAR;


-- ═══════════════════════════════════════════════════════════════════════════
-- POST-DEPLOYMENT VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Verify database and schemas
SHOW DATABASES LIKE 'TEMPORAL_ARCHIVE';
SHOW SCHEMAS IN DATABASE TEMPORAL_ARCHIVE;

-- Verify backup policy
DESCRIBE BACKUP POLICY TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY;

-- Verify Tasks
SHOW TASKS IN SCHEMA TEMPORAL_ARCHIVE.ARCHIVE;

-- Verify Streamlit app
-- SHOW STREAMLITS IN SCHEMA TEMPORAL_ARCHIVE.STREAMLIT;


-- ═══════════════════════════════════════════════════════════════════════════
-- MANUAL DEPLOYMENT COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════
/*
If not using Git integration, run each script manually in order:

-- Step 1: Initial Setup (MUST run as ACCOUNTADMIN - one time only)
USE ROLE ACCOUNTADMIN;
!source sql/01_initial_setup.sql

-- Steps 2-5: Run as DATA_ADMIN (after Step 1 completes)
USE ROLE DATA_ADMIN;

-- Step 2: SCD Load Procedures  
!source sql/02_scd_load.sql

-- Step 3: Semantic Layer
!source sql/03_semantic_layer.sql

-- Step 4: Streamlit DDL
!source sql/04_streamlit_ddl.sql

-- Step 5: Upload Streamlit app and deploy
PUT file://src/app.py @TEMPORAL_ARCHIVE.STREAMLIT.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
!source sql/05_streamlit_app.sql

-- Step 6: Manual test run
CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();

-- Step 7: Build semantic layer
CALL TEMPORAL_ARCHIVE.SEMANTIC.BUILD_SEMANTIC_LAYER();
*/


-- ═══════════════════════════════════════════════════════════════════════════
-- OPERATIONS SCHEDULE
-- ═══════════════════════════════════════════════════════════════════════════
/*
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    SNOWFLAKE TEMPORAL ARCHIVE - OPERATIONS                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   OWNER ROLE:       DATA_ADMIN (owns all objects)                               │
│                                                                                 │
│   TASK_SCD_LOAD_MORNING                                                         │
│   ├── Schedule: CRON 0 6 * * * (6:00 AM daily)                                  │
│   ├── Procedure: CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD()                   │
│   └── Purpose: Load Snowflake.* views → Archive tables (SCD Type 2)             │
│                                                                                 │
│   TASK_SCD_LOAD_EVENING                                                         │
│   ├── Schedule: CRON 0 18 * * * (6:00 PM daily)                                 │
│   ├── Procedure: CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD()                   │
│   └── Purpose: Load Snowflake.* views → Archive tables (SCD Type 2)             │
│                                                                                 │
│   TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY                                           │
│   ├── Schedule: Daily (every 1440 minutes)                                      │
│   ├── Retention: 7 years (2555 days)                                            │
│   ├── RETENTION LOCK: Enabled (immutable, cannot be deleted)                    │
│   └── Purpose: WORM-compliant backups per regulatory requirements               │
│                                                                                 │
│   ROLE HIERARCHY:                                                               │
│   ├── ACCOUNTADMIN → grants privileges to DATA_ADMIN (one-time setup)          │
│   ├── DATA_ADMIN → owns all objects, grants to subordinate roles               │
│   │   ├── TEMPORAL_ARCHIVE_ADMIN → full access                                  │
│   │   ├── TEMPORAL_ARCHIVE_WRITER → SCD load operations                         │
│   │   └── TEMPORAL_ARCHIVE_READER → SELECT only                                 │
│                                                                                 │
│   Reference: https://docs.snowflake.com/en/user-guide/backups                   │
└─────────────────────────────────────────────────────────────────────────────────┘
*/
