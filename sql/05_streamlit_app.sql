-- ============================================================================
-- SNOWFLAKE TEMPORAL ARCHIVE - STREAMLIT APP DEPLOYMENT
-- ============================================================================
-- 
-- This script creates the native Streamlit application in Snowflake.
-- PREREQUISITE: Run 04_streamlit_ddl.sql first
-- PREREQUISITE: Upload app.py to the STREAMLIT_STAGE
--
-- Reference: https://docs.snowflake.com/en/user-guide/backups
--
-- RUN AS: DATA_ADMIN (owner of all Temporal Archive objects)
-- ============================================================================

USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE SCHEMA TEMPORAL_ARCHIVE.STREAMLIT;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

-- ═══════════════════════════════════════════════════════════════════════════
-- CREATE STREAMLIT APP
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE STREAMLIT TEMPORAL_ARCHIVE_APP
    ROOT_LOCATION = '@TEMPORAL_ARCHIVE.STREAMLIT.STREAMLIT_STAGE'
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = TEMPORAL_ARCHIVE_WH
    COMMENT = 'Snowflake Temporal Archive - ACCOUNT_USAGE historical analytics with Cortex AI. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- ═══════════════════════════════════════════════════════════════════════════
-- GRANT ACCESS TO ROLES
-- ═══════════════════════════════════════════════════════════════════════════

GRANT USAGE ON STREAMLIT TEMPORAL_ARCHIVE_APP TO ROLE TEMPORAL_ARCHIVE_ADMIN;
GRANT USAGE ON STREAMLIT TEMPORAL_ARCHIVE_APP TO ROLE TEMPORAL_ARCHIVE_WRITER;
GRANT USAGE ON STREAMLIT TEMPORAL_ARCHIVE_APP TO ROLE TEMPORAL_ARCHIVE_READER;


-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '05_streamlit_app.sql completed successfully' AS STATUS;

SHOW STREAMLITS IN SCHEMA TEMPORAL_ARCHIVE.STREAMLIT;

SELECT 
    'Temporal Archive App Features:' AS INFO,
    '1. Historical ACCOUNT_USAGE Explorer' AS FEATURE_1,
    '2. Cost Optimization Analytics' AS FEATURE_2,
    '3. Security & Compliance Auditing' AS FEATURE_3,
    '4. Cortex AI Natural Language Queries' AS FEATURE_4,
    '5. WORM Backup Status Dashboard' AS FEATURE_5;


-- ═══════════════════════════════════════════════════════════════════════════
-- UPLOAD INSTRUCTIONS
-- ═══════════════════════════════════════════════════════════════════════════
-- 
-- To upload the Streamlit app files:
--
-- 1. From SnowSQL or Snowflake UI:
--    PUT file://src/app.py @TEMPORAL_ARCHIVE.STREAMLIT.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--
-- 2. Verify files are uploaded:
--    LIST @TEMPORAL_ARCHIVE.STREAMLIT.STREAMLIT_STAGE;
--
-- 3. Access the app:
--    - Navigate to Snowsight > Projects > Streamlit
--    - Or use the direct URL from SHOW STREAMLITS output
--
-- Reference: https://docs.snowflake.com/en/user-guide/backups
-- ═══════════════════════════════════════════════════════════════════════════
