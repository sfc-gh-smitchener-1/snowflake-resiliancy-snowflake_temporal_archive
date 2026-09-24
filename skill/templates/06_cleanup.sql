-- ============================================================================
-- SNOWFLAKE TEMPORAL ARCHIVE - CLEANUP / TEARDOWN (PARAMETERIZED TEMPLATE)
-- ============================================================================
-- This is a parameterized template - replace {{VARIABLE}} placeholders.
-- Removes all Temporal Archive objects from the account.
-- Run as ACCOUNTADMIN in a Snowflake Worksheet.
--
-- IMPORTANT - WORM RETENTION LOCK WARNING:
--   01_initial_setup.sql creates a backup policy WITH RETENTION LOCK and
--   attaches it to the {{BACKUP_SET_NAME}} backup set ({{BACKUP_RETENTION_DAYS}}-day
--   expiry). Once a scheduled backup has run, that set contains unexpired
--   retention-locked backups. Per Snowflake docs, such a backup set CANNOT
--   be deleted - even by ACCOUNTADMIN or Snowflake Support - and the
--   database cannot be dropped until every backup expires.
--   Applying a retention-locked policy to a backup set is IRREVERSIBLE.
--
--   If section 2 fails with a retention-lock error, your options are:
--     1. Leave the database in place (you can still drop the warehouse and
--        roles in section 3 - and the tasks are dropped with the DB only,
--        so first suspend them above to stop new loads).
--     2. Wait for backup expiry.
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

ALTER TASK {{DATABASE_NAME}}.{{ARCHIVE_SCHEMA}}.TASK_SCD_LOAD_MORNING SUSPEND;
ALTER TASK {{DATABASE_NAME}}.{{ARCHIVE_SCHEMA}}.TASK_SCD_LOAD_EVENING SUSPEND;

-- =============================================================================
-- 2. REMOVE BACKUP OBJECTS (CRITICAL - DO THIS BEFORE DROPPING THE DATABASE)
-- =============================================================================
-- The backup policy lives inside {{DATABASE_NAME}}.{{ARCHIVE_SCHEMA}}, and the
-- {{BACKUP_SET_NAME}} set references both the policy and the database.
-- Delete the set first, then the policy, then the database. If a step fails
-- with a retention-lock error, see the warning at the top of this file.

-- 2a. Stop the creation of NEW backups while tearing down.
ALTER BACKUP SET {{BACKUP_SET_NAME}}
    SUSPEND BACKUP POLICY;

-- 2b. Drop the backup set (fails if it holds unexpired retention-locked
--     backups). Inspect first with: SHOW BACKUP SETS; SHOW BACKUPS;
DROP BACKUP SET IF EXISTS {{BACKUP_SET_NAME}};

-- 2c. Drop the backup policy (only possible once no set references it).
DROP BACKUP POLICY IF EXISTS {{DATABASE_NAME}}.{{ARCHIVE_SCHEMA}}.{{BACKUP_POLICY_NAME}};

-- =============================================================================
-- 3. DROP CORE OBJECTS
-- =============================================================================
-- Dropping the database removes all archive tables, SCD tables, semantic
-- views, procedures, tasks, the {{STREAMLIT_SCHEMA}} schema objects, and the
-- Cortex agent ({{DATABASE_NAME}}.{{SEMANTIC_SCHEMA}}.{{AGENT_NAME}}).

DROP DATABASE IF EXISTS {{DATABASE_NAME}};

DROP WAREHOUSE IF EXISTS {{WAREHOUSE_NAME}};

-- =============================================================================
-- 4. DROP ROLES (OPTIONAL - REVIEW BEFORE RUNNING)
-- =============================================================================
-- WARNING: {{ADMIN_ROLE}} is a generic role name that other solutions may also
-- use. Only run this statement if this deployment owns it exclusively.

DROP ROLE IF EXISTS {{READER_ROLE}};
DROP ROLE IF EXISTS {{WRITER_ROLE}};
DROP ROLE IF EXISTS {{ARCHIVE_ADMIN_ROLE}};
-- DROP ROLE IF EXISTS {{ADMIN_ROLE}};

-- =============================================================================
-- 5. VERIFY CLEANUP
-- =============================================================================

SHOW DATABASES LIKE '{{DATABASE_NAME}}';
SHOW WAREHOUSES LIKE '{{WAREHOUSE_NAME}}';

SELECT 'Cleanup complete - no Temporal Archive objects remain' AS STATUS;
