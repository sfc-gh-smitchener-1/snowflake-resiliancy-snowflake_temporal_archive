-- ============================================================================
-- SNOWFLAKE TEMPORAL ARCHIVE - STREAMLIT APP DEPLOYMENT
-- ============================================================================
-- 
-- Creates the native Streamlit application in Snowflake.
-- Run this script in a Snowflake Worksheet after 04_streamlit_ddl.sql.
--
-- PREREQUISITES: 
--   1. Run 04_streamlit_ddl.sql first
--   2. Upload src/app.py to the STREAMLIT_STAGE:
--      PUT file://src/app.py @TEMPORAL_ARCHIVE.STREAMLIT.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--
-- Reference: https://docs.snowflake.com/en/user-guide/backups
-- ============================================================================

-- =============================================================================
-- RUN AS DATA_ADMIN
-- =============================================================================
USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE SCHEMA STREAMLIT;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

-- =============================================================================
-- CREATE STREAMLIT APP
-- =============================================================================

CREATE OR REPLACE STREAMLIT TEMPORAL_ARCHIVE.STREAMLIT.TEMPORAL_ARCHIVE_APP
    ROOT_LOCATION = '@TEMPORAL_ARCHIVE.STREAMLIT.STREAMLIT_STAGE'
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = TEMPORAL_ARCHIVE_WH
    COMMENT = 'Snowflake Temporal Archive - ACCOUNT_USAGE historical analytics with Cortex AI. Ref: https://docs.snowflake.com/en/user-guide/backups';


-- =============================================================================
-- GRANT ACCESS TO ROLES
-- =============================================================================

GRANT USAGE ON STREAMLIT TEMPORAL_ARCHIVE.STREAMLIT.TEMPORAL_ARCHIVE_APP TO ROLE TEMPORAL_ARCHIVE_ADMIN;

GRANT USAGE ON STREAMLIT TEMPORAL_ARCHIVE.STREAMLIT.TEMPORAL_ARCHIVE_APP TO ROLE TEMPORAL_ARCHIVE_WRITER;

GRANT USAGE ON STREAMLIT TEMPORAL_ARCHIVE.STREAMLIT.TEMPORAL_ARCHIVE_APP TO ROLE TEMPORAL_ARCHIVE_READER;


-- =============================================================================
-- VERIFICATION
-- =============================================================================

SHOW STREAMLITS IN SCHEMA TEMPORAL_ARCHIVE.STREAMLIT;

SELECT '05_streamlit_app.sql completed. Deployment complete!' AS STATUS;


-- =============================================================================
-- UPLOAD INSTRUCTIONS
-- =============================================================================
-- 
-- To upload the Streamlit app files:
--
-- 1. From SnowSQL:
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
-- =============================================================================
