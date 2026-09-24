-- ============================================================================
-- SNOWFLAKE TEMPORAL ARCHIVE - OPTIONAL WORM BACKUP POLICY (TEMPLATE)
-- ============================================================================
-- This is a parameterized template - replace {{VARIABLE}} placeholders.
--
-- This script is OPTIONAL and is never run automatically by the deployment
-- scripts. Run it MANUALLY, only if you need WORM-compliant backups.
--
-- Requires Business Critical Edition (retention lock) and ACCOUNTADMIN
-- (or a role with CREATE BACKUP POLICY / CREATE BACKUP SET / APPLY BACKUP
-- RETENTION LOCK privileges).
--
-- *** IRREVERSIBLE - READ FIRST ***
--   This policy uses WITH RETENTION LOCK + EXPIRE_AFTER_DAYS = {{BACKUP_RETENTION_DAYS}}.
--   Once a scheduled backup has run, the retention-locked backup set CANNOT
--   be deleted - even by ACCOUNTADMIN or Snowflake Support - and the
--   database cannot be dropped until every backup expires. See 06_cleanup.sql.
--
--   For demo/trial accounts: do NOT run this script. If you need backups
--   without the WORM lock, remove the WITH RETENTION LOCK line and use a
--   shorter EXPIRE_AFTER_DAYS.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- 1. WORM-compliant backup policy
CREATE BACKUP POLICY IF NOT EXISTS {{DATABASE_NAME}}.{{ARCHIVE_SCHEMA}}.{{BACKUP_POLICY_NAME}}
    WITH RETENTION LOCK
    SCHEDULE = '{{BACKUP_SCHEDULE_MINUTES}} MINUTE'
    EXPIRE_AFTER_DAYS = {{BACKUP_RETENTION_DAYS}}
    COMMENT = 'WORM-compliant backup policy with {{BACKUP_RETENTION_DAYS}}-day retention for SEC 17a-4, HIPAA, FINRA compliance';

-- 2. Attach the policy via a backup set for the database.
--    Policies attach to BACKUP SETS, not databases directly.
CREATE BACKUP SET IF NOT EXISTS {{BACKUP_SET_NAME}}
    FOR DATABASE {{DATABASE_NAME}}
    WITH BACKUP POLICY {{DATABASE_NAME}}.{{ARCHIVE_SCHEMA}}.{{BACKUP_POLICY_NAME}};

-- 3. Verify
SHOW BACKUP POLICIES;
SHOW BACKUP SETS;

SELECT 'WORM backup policy created - IRREVERSIBLE once a scheduled backup has run' AS STATUS;
