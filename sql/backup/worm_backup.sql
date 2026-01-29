/*
================================================================================
SNOWFLAKE TEMPORAL ARCHIVE - WORM BACKUP POLICY
================================================================================

Snowflake native backup policy with RETENTION LOCK for WORM compliance.
Creates daily immutable backups retained for 7 years per regulatory requirements.

Reference: https://docs.snowflake.com/en/user-guide/backups

WORM Compliance:
    • RETENTION LOCK ensures backups cannot be deleted by any user
    • Even ACCOUNTADMIN and ORGADMIN cannot remove locked backups
    • Requires Business Critical Edition or higher
    • Meets regulatory requirements for immutable data retention

Schedule:
    • Daily backups (every 1440 minutes = 24 hours)
    • Retained for 7 years (2555 days)
    • Runs after SCD loads complete (6 AM and 6 PM)

================================================================================
*/

USE ROLE ACCOUNTADMIN;


-- =============================================================================
-- CREATE BACKUP POLICY WITH RETENTION LOCK
-- Reference: https://docs.snowflake.com/en/user-guide/backups
--
-- Parameters:
--   WITH RETENTION LOCK  - Immutable backups, cannot be deleted
--   SCHEDULE             - Daily (1440 minutes = 24 hours)
--   EXPIRE_AFTER_DAYS    - 7 years (2555 days) per regulatory requirements
-- =============================================================================

CREATE BACKUP POLICY IF NOT EXISTS TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY
    WITH RETENTION LOCK
    SCHEDULE = '1440 MINUTE'
    EXPIRE_AFTER_DAYS = 2555
    COMMENT = 'Snowflake Temporal Archive: WORM-compliant daily backups with 7-year retention. Immutable per regulatory requirements. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- APPLY BACKUP POLICY TO TEMPORAL ARCHIVE DATABASE
-- =============================================================================

ALTER DATABASE TEMPORAL_ARCHIVE
    SET BACKUP POLICY = TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY;


-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- View backup policy details
-- DESCRIBE BACKUP POLICY TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY;

-- Show all backup policies
-- SHOW BACKUP POLICIES;

-- View backup history
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.BACKUP_HISTORY())
-- ORDER BY CREATED DESC
-- LIMIT 50;

-- Verify policy is applied to database
-- SHOW DATABASES LIKE 'TEMPORAL_ARCHIVE';


-- =============================================================================
-- BACKUP POLICY SPECIFICATIONS
-- =============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────────────┐
│              TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Policy Name:      TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY                         │
│   Retention Lock:   ENABLED (immutable, cannot be deleted)                      │
│   Schedule:         Daily (every 1440 minutes)                                  │
│   Retention:        7 years (2555 days)                                         │
│   Edition Required: Business Critical or higher                                 │
│                                                                                 │
│   Applied To:       TEMPORAL_ARCHIVE database                                   │
│                                                                                 │
│   Compliance:       WORM (Write Once Read Many)                                 │
│                     - Backups cannot be deleted by ANY user                     │
│                     - Meets SEC 17a-4, FINRA, HIPAA requirements                │
│                     - Immutable audit trail for 7 years                         │
│                                                                                 │
│   Reference:        https://docs.snowflake.com/en/user-guide/backups            │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         DAILY OPERATIONS TIMELINE                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   06:00 AM ─────▶  TASK_SCD_LOAD_MORNING                                        │
│                    Load Snowflake.* views → Archive tables                      │
│                                                                                 │
│   06:00 PM ─────▶  TASK_SCD_LOAD_EVENING                                        │
│                    Load Snowflake.* views → Archive tables                      │
│                                                                                 │
│   Daily ─────────▶ TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY                          │
│                    Automatic immutable backup with 7-year retention             │
│                    (Snowflake manages backup timing internally)                 │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
*/
