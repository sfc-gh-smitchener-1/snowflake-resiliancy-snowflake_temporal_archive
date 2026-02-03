/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - SCD TASKS
================================================================================

Creates and enables the scheduled Tasks for SCD loads.
Run this script in a Snowflake Worksheet after 02b_scd_procedures.sql.

Reference: https://docs.snowflake.com/en/user-guide/backups
================================================================================
*/

USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE SCHEMA ARCHIVE;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

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


-- =============================================================================
-- ENABLE TASKS
-- =============================================================================

ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_MORNING RESUME;

ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING RESUME;


-- =============================================================================
-- VERIFICATION
-- =============================================================================

SHOW TASKS IN SCHEMA TEMPORAL_ARCHIVE.ARCHIVE;

SELECT 'SCD tasks created and enabled. Next: Run 03_semantic_layer.sql' AS STATUS;
