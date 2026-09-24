-- ============================================================================
-- SNOWFLAKE TEMPORAL ARCHIVE - CLEANUP / TEARDOWN
-- ============================================================================
-- Removes all Temporal Archive objects from the account.
-- Run as ACCOUNTADMIN in a Snowflake Worksheet.
--
-- IMPORTANT - WORM RETENTION LOCK WARNING:
--   01_initial_setup.sql creates a backup policy WITH RETENTION LOCK and
--   attaches it to the TEMPORAL_ARCHIVE_BACKUPS backup set (7-year expiry).
--   Once a scheduled backup has run, that set contains unexpired
--   retention-locked backups. Per Snowflake docs, such a backup set CANNOT
--   be deleted - even by ACCOUNTADMIN or Snowflake Support - and the
--   database cannot be dropped until every backup expires (up to 7 years).
--   Applying a retention-locked policy to a backup set is IRREVERSIBLE.
--
--   If section 2 fails with a retention-lock error, your options are:
--     1. Leave the database in place (you can still drop the warehouse and
--        roles in section 3 - and the tasks are dropped with the DB only,
--        so first suspend them above to stop new loads).
--     2. Wait for backup expiry (up to 7 years).
--
--   For future demo deployments, prevent this entirely: deploy with
--   features.create_backup_policy: false in config.yaml (and if you must
--   have backups, use a short EXPIRE_AFTER_DAYS without a retention lock).
--
-- PREREQUISITE: no backup has run yet, or the retention lock doesn't apply.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- 1. STOP SCHEDULED WORK
-- =============================================================================
-- Suspend the SCD load tasks so nothing runs mid-teardown.
-- (Tasks are dropped with the database in section 3.)

ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_MORNING SUSPEND;
ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING SUSPEND;

-- =============================================================================
-- 2. REMOVE BACKUP OBJECTS (CRITICAL - DO THIS BEFORE DROPPING THE DATABASE)
-- =============================================================================
-- The backup policy lives inside TEMPORAL_ARCHIVE.ARCHIVE, and the
-- TEMPORAL_ARCHIVE_BACKUPS set references both the policy and the database.
-- Delete the set first, then the policy, then the database. If a step fails
-- with a retention-lock error, see the warning at the top of this file.

-- 2a. Stop the creation of NEW backups while tearing down.
ALTER BACKUP SET TEMPORAL_ARCHIVE_BACKUPS
    SUSPEND BACKUP POLICY;

-- 2b. Drop the backup set (fails if it holds unexpired retention-locked
--     backups). Inspect first with: SHOW BACKUP SETS; SHOW BACKUPS;
DROP BACKUP SET IF EXISTS TEMPORAL_ARCHIVE_BACKUPS;

-- 2c. Drop the backup policy (only possible once no set references it).
DROP BACKUP POLICY IF EXISTS TEMPORAL_ARCHIVE.ARCHIVE.TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY;

-- =============================================================================
-- 3. DROP CORE OBJECTS
-- =============================================================================
-- Dropping the database removes all archive tables, SCD tables, semantic
-- views, procedures, tasks, the STREAMLIT schema objects, and the Cortex
-- agent (TEMPORAL_ARCHIVE.SEMANTIC.SNOWFLAKEACCOUNTARCHIVE).

DROP DATABASE IF EXISTS TEMPORAL_ARCHIVE;

DROP WAREHOUSE IF EXISTS TEMPORAL_ARCHIVE_WH;

-- =============================================================================
-- 4. DROP ROLES (OPTIONAL - REVIEW BEFORE RUNNING)
-- =============================================================================
-- WARNING: DATA_ADMIN is a generic role name that other solutions may also
-- use. Only run this statement if this deployment owns DATA_ADMIN exclusively.

DROP ROLE IF EXISTS TEMPORAL_ARCHIVE_READER;
DROP ROLE IF EXISTS TEMPORAL_ARCHIVE_WRITER;
DROP ROLE IF EXISTS TEMPORAL_ARCHIVE_ADMIN;
-- DROP ROLE IF EXISTS DATA_ADMIN;

-- =============================================================================
-- 5. VERIFY CLEANUP
-- =============================================================================

SHOW DATABASES LIKE 'TEMPORAL_ARCHIVE';
SHOW WAREHOUSES LIKE 'TEMPORAL_ARCHIVE_WH';

SELECT 'Cleanup complete - no Temporal Archive objects remain' AS STATUS;
