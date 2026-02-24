# Snowflake Temporal Archive Quickstart

> **Duration**: 20-30 minutes | **Level**: Intermediate | **Prerequisites**: ACCOUNTADMIN access

## Overview

In this quickstart, you will deploy a complete **Temporal Archive** solution that extends your Snowflake ACCOUNT_USAGE retention from 1 year to 7+ years using SCD Type 2 archiving. You'll also deploy 9 AI-ready semantic views for natural language analytics with Cortex Analyst.

### What You'll Build

```
┌─────────────────────────────────────────────────────────────────────────┐
│  TEMPORAL_ARCHIVE Database                                              │
│  ├── 84 Active SCD Type 2 Archive Tables (7+ year retention via SCD) │
│  ├── 9 Semantic Views (AI-ready for Cortex Analyst)                     │
│  ├── Automated Load Tasks (6 AM & 6 PM daily)                           │
│  └── [Optional] WORM Backup Policy (Business Critical Edition only)     │
└─────────────────────────────────────────────────────────────────────────┘
```

### What You'll Learn

- How to create SCD Type 2 archive tables for Snowflake metadata
- How to deploy native Snowflake Semantic Views for AI analytics
- How to query historical data with point-in-time accuracy
- How to identify performance issues using Query Performance Analytics
- How to audit user/table access patterns

---

## Prerequisites

Before you begin, ensure you have:

| Requirement | Details |
|-------------|---------|
| **Snowflake Account** | Any edition (Standard, Enterprise, or Business Critical) |
| **Role** | ACCOUNTADMIN (for initial setup only) |
| **Warehouse** | Any active warehouse for running deployment scripts |
| **Time** | 20-30 minutes |

> **Note**: Steps 1-7 work on all Snowflake editions. Step 8 (WORM-compliant backups with retention lock) requires **Business Critical Edition** or higher.

---

## Alternative: Deploy with Cortex Code (Fastest Method)

If you have **Cortex Code** installed, you can deploy the entire Temporal Archive with a single command. This section walks you through setting up Cortex Code and running the deployment skill.

### What is Cortex Code?

Cortex Code is Snowflake's official CLI tool for AI-assisted development. It provides:
- Natural language interface to Snowflake
- Pre-built skills for common tasks
- Direct SQL execution against your Snowflake account
- Code generation and automation

### A.1 Install Cortex Code

#### Option 1: Homebrew (macOS)

```bash
brew tap Snowflake-Labs/cortex-code
brew install cortex-code
```

#### Option 2: Direct Download

Download the latest release for your platform from the [Cortex Code releases page](https://github.com/Snowflake-Labs/cortex-code/releases).

#### Option 3: npm (Cross-platform)

```bash
npm install -g @snowflake-labs/cortex-code
```

### A.2 Verify Installation

```bash
cortex --version
```

You should see output like:
```
Cortex Code v1.x.x
```

### A.3 Configure Snowflake Connection

Cortex Code uses Snowflake connections to authenticate. You can configure connections in several ways:

#### Option 1: Browser-Based SSO/OAuth (Recommended)

The easiest and most secure method. Opens your browser for authentication:

```bash
cortex connections add myaccount --account xy12345.us-east-1 --user your_username --authenticator externalbrowser
```

This uses your organization's SSO provider (Okta, Azure AD, etc.) and doesn't require storing credentials locally.

#### Option 2: Programmatic Access Token (PAT) (Recommended for Automation)

Personal Access Tokens are ideal for CI/CD pipelines and automated deployments:

1. **Generate a PAT in Snowsight**:
   - Go to your user menu (bottom left) → **Settings** → **Authentication**
   - Click **Generate Token**
   - Set expiration and copy the token

2. **Configure Cortex Code with PAT**:

```bash
cortex connections add myaccount --account xy12345.us-east-1 --authenticator oauth --token YOUR_PAT_TOKEN
```

Or use environment variables:

```bash
export SNOWFLAKE_ACCOUNT=xy12345.us-east-1
export SNOWFLAKE_AUTHENTICATOR=oauth
export SNOWFLAKE_TOKEN=your_personal_access_token
```

#### Option 3: Interactive Setup

```bash
cortex connections add
```

Follow the prompts to enter:
- **Connection name**: A friendly name (e.g., `myaccount`)
- **Account identifier**: Your Snowflake account (e.g., `xy12345.us-east-1`)
- **Username**: Your Snowflake username
- **Authentication**: Choose from OAuth, SSO, Password, or Key-pair

#### Option 4: Use Existing SnowSQL Config

If you have SnowSQL configured, Cortex Code can use those connections:

```bash
cortex connections list
```

This shows all available connections from `~/.snowsql/config`.

#### Option 5: Environment Variables (Username/Password)

For development environments only (not recommended for production):

```bash
export SNOWFLAKE_ACCOUNT=xy12345.us-east-1
export SNOWFLAKE_USER=your_username
export SNOWFLAKE_PASSWORD=your_password
```

#### Option 6: Key-Pair Authentication

For secure, password-less authentication:

1. **Generate a key pair**:

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

2. **Register the public key in Snowflake**:

```sql
ALTER USER your_username SET RSA_PUBLIC_KEY='MIIBIjANBgkq...';
```

3. **Configure Cortex Code**:

```bash
cortex connections add myaccount \
  --account xy12345.us-east-1 \
  --user your_username \
  --authenticator snowflake_jwt \
  --private-key-path ~/.ssh/rsa_key.p8
```

### Authentication Method Comparison

| Method | Security | Best For | Requires |
|--------|----------|----------|----------|
| **OAuth/SSO** | ★★★★★ | Interactive use | Browser, SSO provider |
| **PAT** | ★★★★☆ | Automation, CI/CD | Token generation in Snowsight |
| **Key-Pair** | ★★★★☆ | Service accounts | Key management |
| **Password** | ★★☆☆☆ | Development only | MFA may block |

### A.4 Test Your Connection

```bash
cortex connections test myaccount
```

Or start Cortex Code and run a simple query:

```bash
cortex
```

Then in the Cortex Code prompt:

```
Show me the current user and role
```

You should see your Snowflake user and role information.

### A.5 Clone the Temporal Archive Repository

```bash
git clone https://github.com/your-org/snowflake-temporal-archive.git
cd snowflake-temporal-archive
```

### A.6 Deploy with the Skill

Start Cortex Code in the repository directory:

```bash
cortex
```

Then run one of the following commands:

#### Deploy with Defaults

```
Deploy Temporal Archive to my account
```

This deploys with default settings:
- Database: `TEMPORAL_ARCHIVE`
- Warehouse: `TEMPORAL_ARCHIVE_WH` (X-Small)
- Scheduled loads: 6 AM and 6 PM Eastern

#### Deploy with Custom Settings

```
Deploy Temporal Archive with database MY_ARCHIVE and warehouse MY_WH using connection myaccount
```

#### Deploy to a Specific Connection

```
Deploy Temporal Archive to my production account using the prod_snowflake connection
```

### A.7 What the Skill Deploys

The Temporal Archive skill automatically:

| Step | What It Does |
|------|--------------|
| 1 | Creates database, warehouse, and roles |
| 2 | Creates 4 schemas (ARCHIVE, ACCOUNT_USAGE, ORGANIZATION_USAGE, SEMANTIC) |
| 3 | Registers 113 ACCOUNT_USAGE views for archiving (84 active) |
| 4 | Creates SCD Type 2 load procedures |
| 5 | Deploys 9 semantic views for Cortex Analyst |
| 6 | Creates scheduled tasks (morning + evening loads) |
| 7 | Runs initial data load |
| 8 | Verifies deployment |

### A.8 Monitor Deployment Progress

Cortex Code shows real-time progress as it executes each step. You'll see output like:

```
✓ Created database TEMPORAL_ARCHIVE
✓ Created warehouse TEMPORAL_ARCHIVE_WH
✓ Created roles (DATA_ADMIN, TEMPORAL_ARCHIVE_READER, TEMPORAL_ARCHIVE_WRITER)
✓ Created VIEW_REGISTRY with 113 source views (84 active)
✓ Created LOAD_VIEW_ARCHIVE procedure
✓ Created 9 semantic views
✓ Created scheduled tasks
✓ Running initial data load...
✓ Loaded 84 active archive tables
✓ Deployment complete!
```

### A.9 Verify Deployment

After deployment, ask Cortex Code to verify:

```
Verify my Temporal Archive deployment
```

Or run verification queries directly:

```
Show me how many archive tables were created in TEMPORAL_ARCHIVE
```

```
List all semantic views in the TEMPORAL_ARCHIVE database
```

### A.10 Using the Semantic Views with Cortex Code

Once deployed, you can query the archive using natural language:

```
Show me long-running queries over 5 minutes from the last week
```

```
Which users have the most failed login attempts?
```

```
What's my warehouse credit consumption trend for the last 30 days?
```

```
Show me which tables were accessed by user JOHN_DOE last week
```

### A.11 Cortex Code Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+C` | Cancel current operation |
| `Ctrl+D` | Exit Cortex Code |
| `↑` / `↓` | Navigate command history |
| `Tab` | Autocomplete |
| `/help` | Show help menu |
| `/connections` | Manage connections |
| `/clear` | Clear screen |

### A.12 Troubleshooting Cortex Code

#### Connection Failed

```bash
# Check connection details
cortex connections list

# Test specific connection
cortex connections test myaccount

# Re-authenticate
cortex connections auth myaccount
```

#### Permission Denied

Ensure you're using ACCOUNTADMIN for initial deployment:

```
Switch to ACCOUNTADMIN role and deploy Temporal Archive
```

#### Skill Not Found

Make sure you're in the repository directory containing the `skill/` folder:

```bash
cd snowflake-temporal-archive
ls skill/
# Should show: SKILL.md, templates/, scripts/, etc.
```

---

**After deploying with Cortex Code, skip to [Step 5: Query Your Archive](#step-5-query-your-archive-5-minutes) to start analyzing your data, or continue to [Step 8](#step-8-worm-compliant-backup-policy-optional---business-critical-edition) to enable WORM backups.**

---

## Step 1: Initial Setup (5 minutes)

### 1.1 Open a SQL Workspace

Navigate to **Workspaces** in Snowsight and create a new SQL workspace (or open an existing one).

### 1.2 Create Infrastructure

Run the following SQL to create the database, warehouse, roles, and schemas:

```sql
-- =============================================================================
-- STEP 1: RUN AS ACCOUNTADMIN
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- Create the DATA_ADMIN role (owner of all Temporal Archive objects)
CREATE ROLE IF NOT EXISTS DATA_ADMIN
    COMMENT = 'Owner of Temporal Archive objects. Manages all archive infrastructure.';

GRANT ROLE DATA_ADMIN TO ROLE SYSADMIN;

-- Create the database
CREATE DATABASE IF NOT EXISTS TEMPORAL_ARCHIVE
    COMMENT = 'Snowflake Temporal Archive - SCD Type 2 history with 7+ year retention';

-- Create a dedicated warehouse
-- LARGE Gen2 recommended for production (84 active views, 3-strategy delta load)
-- Use SMALL for quickstart/testing with smaller subsets
CREATE WAREHOUSE IF NOT EXISTS TEMPORAL_ARCHIVE_WH
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for Temporal Archive SCD loads';

-- Transfer ownership to DATA_ADMIN
GRANT OWNERSHIP ON DATABASE TEMPORAL_ARCHIVE TO ROLE DATA_ADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON WAREHOUSE TEMPORAL_ARCHIVE_WH TO ROLE DATA_ADMIN COPY CURRENT GRANTS;

-- Grant DATA_ADMIN access to SNOWFLAKE.ACCOUNT_USAGE
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE DATA_ADMIN;

-- Grant task execution privileges
GRANT EXECUTE TASK ON ACCOUNT TO ROLE DATA_ADMIN;
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE DATA_ADMIN;

-- Create reader/writer/admin roles
CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_READER
    COMMENT = 'Read-only access to Temporal Archive for analysts';
CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_WRITER
    COMMENT = 'Write access for SCD load execution';
CREATE ROLE IF NOT EXISTS TEMPORAL_ARCHIVE_ADMIN
    COMMENT = 'Admin access for maintenance';

-- Create role hierarchy
GRANT ROLE TEMPORAL_ARCHIVE_READER TO ROLE DATA_ADMIN;
GRANT ROLE TEMPORAL_ARCHIVE_WRITER TO ROLE DATA_ADMIN;
GRANT ROLE TEMPORAL_ARCHIVE_ADMIN TO ROLE DATA_ADMIN;
GRANT ROLE TEMPORAL_ARCHIVE_READER TO ROLE TEMPORAL_ARCHIVE_WRITER;
GRANT ROLE TEMPORAL_ARCHIVE_WRITER TO ROLE TEMPORAL_ARCHIVE_ADMIN;

-- Grant DATA_ADMIN to your user (replace YOUR_USERNAME)
GRANT ROLE DATA_ADMIN TO USER IDENTIFIER($CURRENT_USER);
```

### 1.3 Create Schemas

```sql
-- Switch to DATA_ADMIN role
USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

-- Create the required schemas
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE
    COMMENT = 'Core archive utilities, procedures, and configuration';

CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE
    COMMENT = 'Archive of SNOWFLAKE.ACCOUNT_USAGE views';

CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ORGANIZATION_USAGE
    COMMENT = 'Archive of SNOWFLAKE.ORGANIZATION_USAGE views';

CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.SEMANTIC
    COMMENT = 'Native Snowflake Semantic Views for Cortex Analyst';
```

**✅ Checkpoint**: Run `SHOW SCHEMAS IN DATABASE TEMPORAL_ARCHIVE;` — you should see 4 schemas.

---

## Step 2: Deploy SCD Type 2 Load Procedure (5 minutes)

### 2.1 Create the Load Log Table

```sql
USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE SCHEMA ARCHIVE;

-- Create logging table for tracking loads
CREATE TABLE IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG (
    LOG_ID                  NUMBER AUTOINCREMENT,
    SOURCE_TABLE            VARCHAR(512),
    TARGET_TABLE            VARCHAR(512),
    ROWS_UPDATED            NUMBER,
    ROWS_INSERTED           NUMBER,
    STATUS                  VARCHAR(50),
    ERROR_MESSAGE           VARCHAR(4096),
    DURATION_SECONDS        NUMBER,
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Log of SCD load executions';
```

### 2.2 Create the View Registry

This registry tracks all ACCOUNT_USAGE views to archive:

```sql
-- Create registry of views to archive
CREATE OR REPLACE TABLE TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (
    SOURCE_SCHEMA VARCHAR(100),
    SOURCE_VIEW VARCHAR(200),
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Registry of all known views to archive from SNOWFLAKE database';

-- Populate with core ACCOUNT_USAGE views (subset for quickstart)
INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY (SOURCE_SCHEMA, SOURCE_VIEW) VALUES
-- Core metadata
('ACCOUNT_USAGE', 'DATABASES'),
('ACCOUNT_USAGE', 'TABLES'),
('ACCOUNT_USAGE', 'USERS'),
('ACCOUNT_USAGE', 'ROLES'),
-- Security & access
('ACCOUNT_USAGE', 'LOGIN_HISTORY'),
('ACCOUNT_USAGE', 'QUERY_HISTORY'),
('ACCOUNT_USAGE', 'ACCESS_HISTORY'),
('ACCOUNT_USAGE', 'GRANTS_TO_ROLES'),
-- Metering & costs
('ACCOUNT_USAGE', 'WAREHOUSE_METERING_HISTORY'),
('ACCOUNT_USAGE', 'METERING_DAILY_HISTORY'),
('ACCOUNT_USAGE', 'STORAGE_USAGE'),
('ACCOUNT_USAGE', 'DATABASE_STORAGE_USAGE_HISTORY'),
('ACCOUNT_USAGE', 'TABLE_STORAGE_METRICS'),
-- Governance
('ACCOUNT_USAGE', 'MASKING_POLICIES'),
('ACCOUNT_USAGE', 'ROW_ACCESS_POLICIES'),
('ACCOUNT_USAGE', 'TASK_HISTORY');
```

### 2.3 Create the SCD Type 2 Load Procedure

This procedure performs incremental loads using hash-based change detection:

```sql
CREATE OR REPLACE PROCEDURE TEMPORAL_ARCHIVE.ARCHIVE.LOAD_VIEW_ARCHIVE(
    p_source_schema VARCHAR,
    p_source_view VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_source_table VARCHAR;
    v_target_table VARCHAR;
    v_start_time TIMESTAMP_NTZ;
    v_rows_updated NUMBER DEFAULT 0;
    v_rows_inserted NUMBER DEFAULT 0;
    v_status VARCHAR DEFAULT 'SUCCESS';
    v_error_message VARCHAR DEFAULT NULL;
    v_columns_sql VARCHAR;
    v_create_sql VARCHAR;
    v_update_sql VARCHAR;
    v_insert_sql VARCHAR;
BEGIN
    v_start_time := CURRENT_TIMESTAMP();
    v_source_table := 'SNOWFLAKE.' || p_source_schema || '.' || p_source_view;
    v_target_table := 'TEMPORAL_ARCHIVE.' || p_source_schema || '.' || p_source_view || '_ARCHIVE';
    
    -- Get column list dynamically
    SELECT LISTAGG('"' || COLUMN_NAME || '"', ', ') WITHIN GROUP (ORDER BY ORDINAL_POSITION)
    INTO v_columns_sql
    FROM SNOWFLAKE.ACCOUNT_USAGE.COLUMNS
    WHERE TABLE_CATALOG = 'SNOWFLAKE' 
      AND TABLE_SCHEMA = :p_source_schema 
      AND TABLE_NAME = :p_source_view
      AND DELETED IS NULL;
    
    IF (v_columns_sql IS NULL OR v_columns_sql = '') THEN
        v_status := 'SKIPPED';
        v_error_message := 'No columns found or view not accessible';
        
        INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG 
            (SOURCE_TABLE, TARGET_TABLE, ROWS_UPDATED, ROWS_INSERTED, STATUS, ERROR_MESSAGE, DURATION_SECONDS)
        VALUES 
            (:v_source_table, :v_target_table, 0, 0, :v_status, :v_error_message, 
             TIMESTAMPDIFF(SECOND, :v_start_time, CURRENT_TIMESTAMP()));
        
        RETURN OBJECT_CONSTRUCT('status', v_status, 'error', v_error_message);
    END IF;
    
    -- Create target table if not exists
    v_create_sql := '
        CREATE TABLE IF NOT EXISTS ' || v_target_table || ' AS
        SELECT 
            SHA2(CONCAT_WS(''|'', ' || v_columns_sql || '), 256) AS "_ROW_HASH",
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_LOADED_AT",
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS "_VALID_FROM",
            NULL::TIMESTAMP_NTZ AS "_VALID_TO",
            TRUE AS "_IS_CURRENT",
            *
        FROM ' || v_source_table || '
        WHERE 1=0';
    
    EXECUTE IMMEDIATE v_create_sql;
    
    -- Update: Close out changed/deleted records
    v_update_sql := '
        UPDATE ' || v_target_table || ' t
        SET "_VALID_TO" = CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
            "_IS_CURRENT" = FALSE
        WHERE t."_IS_CURRENT" = TRUE
          AND NOT EXISTS (
              SELECT 1 FROM ' || v_source_table || ' s
              WHERE SHA2(CONCAT_WS(''|'', ' || REPLACE(v_columns_sql, '"', 's."') || '), 256) = t."_ROW_HASH"
          )';
    
    EXECUTE IMMEDIATE v_update_sql;
    v_rows_updated := SQLROWCOUNT;
    
    -- Insert: Add new/changed records
    v_insert_sql := '
        INSERT INTO ' || v_target_table || ' ("_ROW_HASH", "_LOADED_AT", "_VALID_FROM", "_VALID_TO", "_IS_CURRENT", ' || v_columns_sql || ')
        SELECT 
            SHA2(CONCAT_WS(''|'', ' || v_columns_sql || '), 256),
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
            CURRENT_TIMESTAMP()::TIMESTAMP_NTZ,
            NULL,
            TRUE,
            ' || v_columns_sql || '
        FROM ' || v_source_table || ' s
        WHERE NOT EXISTS (
            SELECT 1 FROM ' || v_target_table || ' t
            WHERE t."_IS_CURRENT" = TRUE
              AND t."_ROW_HASH" = SHA2(CONCAT_WS(''|'', ' || v_columns_sql || '), 256)
        )';
    
    EXECUTE IMMEDIATE v_insert_sql;
    v_rows_inserted := SQLROWCOUNT;
    
    -- Log the result
    INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG 
        (SOURCE_TABLE, TARGET_TABLE, ROWS_UPDATED, ROWS_INSERTED, STATUS, DURATION_SECONDS)
    VALUES 
        (:v_source_table, :v_target_table, :v_rows_updated, :v_rows_inserted, 'SUCCESS',
         TIMESTAMPDIFF(SECOND, :v_start_time, CURRENT_TIMESTAMP()));
    
    RETURN OBJECT_CONSTRUCT(
        'status', 'SUCCESS',
        'source', v_source_table,
        'target', v_target_table,
        'rows_updated', v_rows_updated,
        'rows_inserted', v_rows_inserted
    );
    
EXCEPTION
    WHEN OTHER THEN
        v_status := 'ERROR';
        v_error_message := SQLERRM;
        
        INSERT INTO TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG 
            (SOURCE_TABLE, TARGET_TABLE, ROWS_UPDATED, ROWS_INSERTED, STATUS, ERROR_MESSAGE, DURATION_SECONDS)
        VALUES 
            (:v_source_table, :v_target_table, 0, 0, :v_status, :v_error_message,
             TIMESTAMPDIFF(SECOND, :v_start_time, CURRENT_TIMESTAMP()));
        
        RETURN OBJECT_CONSTRUCT('status', 'ERROR', 'error', v_error_message);
END;
$$;
```

### 2.4 Create the Master Load Procedure

```sql
CREATE OR REPLACE PROCEDURE TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_cursor CURSOR FOR 
        SELECT SOURCE_SCHEMA, SOURCE_VIEW 
        FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY 
        WHERE IS_ACTIVE = TRUE;
    v_schema VARCHAR;
    v_view VARCHAR;
    v_result VARIANT;
    v_count NUMBER DEFAULT 0;
BEGIN
    FOR record IN v_cursor DO
        v_schema := record.SOURCE_SCHEMA;
        v_view := record.SOURCE_VIEW;
        
        CALL TEMPORAL_ARCHIVE.ARCHIVE.LOAD_VIEW_ARCHIVE(:v_schema, :v_view);
        v_count := v_count + 1;
    END FOR;
    
    RETURN 'Processed ' || v_count || ' views. Check LOAD_LOG for details.';
END;
$$;
```

**✅ Checkpoint**: Run `SHOW PROCEDURES IN SCHEMA TEMPORAL_ARCHIVE.ARCHIVE;` — you should see 2 procedures.

---

## Step 3: Run Initial Data Load (5-10 minutes)

### 3.1 Execute the Initial Load

```sql
-- This will archive all registered views (first run may take 5-10 minutes)
CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();
```

### 3.2 Verify the Load

```sql
-- Check load log for results
SELECT 
    SOURCE_TABLE,
    TARGET_TABLE,
    ROWS_INSERTED,
    STATUS,
    DURATION_SECONDS,
    LOAD_TIMESTAMP
FROM TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG
ORDER BY LOAD_TIMESTAMP DESC
LIMIT 20;
```

### 3.3 Verify Archive Tables

```sql
-- List all created archive tables
SHOW TABLES LIKE '%_ARCHIVE' IN SCHEMA TEMPORAL_ARCHIVE.ACCOUNT_USAGE;

-- Check row counts for key tables
SELECT 'QUERY_HISTORY_ARCHIVE' AS table_name, COUNT(*) AS row_count 
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
UNION ALL
SELECT 'ACCESS_HISTORY_ARCHIVE', COUNT(*) 
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ACCESS_HISTORY_ARCHIVE
UNION ALL
SELECT 'LOGIN_HISTORY_ARCHIVE', COUNT(*) 
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
UNION ALL
SELECT 'WAREHOUSE_METERING_HISTORY_ARCHIVE', COUNT(*) 
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE;
```

**✅ Checkpoint**: You should see archive tables with data. QUERY_HISTORY typically has the most rows.

---

## Step 4: Deploy Semantic Views (5 minutes)

Semantic Views enable natural language queries with Cortex Analyst. We'll deploy the **Query Performance Analytics** view as an example.

### 4.1 Create Query Performance Analytics Semantic View

This view joins QUERY_HISTORY with ACCESS_HISTORY for comprehensive query analysis:

```sql
USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.QUERY_PERFORMANCE_ANALYTICS
    
    TABLES (
        QUERY_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
            PRIMARY KEY (QUERY_ID)
            WITH SYNONYMS ('queries', 'sql executions', 'query runs', 'slow queries'),
            
        ACCESS_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ACCESS_HISTORY_ARCHIVE
            PRIMARY KEY (QUERY_ID)
            WITH SYNONYMS ('table access', 'data access', 'who accessed what')
    )
    
    RELATIONSHIPS (
        ACCESS_HISTORY (QUERY_ID) REFERENCES QUERY_HISTORY (QUERY_ID)
    )
    
    FACTS (
        -- Duration Metrics
        QUERY_HISTORY.total_elapsed_time AS QUERY_HISTORY.TOTAL_ELAPSED_TIME
            WITH SYNONYMS ('duration', 'elapsed time', 'runtime')
            COMMENT = 'Total query execution time in milliseconds',
        QUERY_HISTORY.execution_time AS QUERY_HISTORY.EXECUTION_TIME
            WITH SYNONYMS ('exec time', 'processing time')
            COMMENT = 'Time spent executing the query',
        QUERY_HISTORY.queued_overload_time AS QUERY_HISTORY.QUEUED_OVERLOAD_TIME
            WITH SYNONYMS ('queue time', 'wait time')
            COMMENT = 'Time waiting due to warehouse overload',
            
        -- I/O Metrics
        QUERY_HISTORY.bytes_scanned AS QUERY_HISTORY.BYTES_SCANNED
            WITH SYNONYMS ('bytes read', 'data scanned')
            COMMENT = 'Bytes scanned from storage',
        QUERY_HISTORY.rows_produced AS QUERY_HISTORY.ROWS_PRODUCED
            WITH SYNONYMS ('rows returned', 'result rows')
            COMMENT = 'Number of rows returned',
            
        -- Partition Metrics
        QUERY_HISTORY.partitions_scanned AS QUERY_HISTORY.PARTITIONS_SCANNED
            WITH SYNONYMS ('partitions read')
            COMMENT = 'Number of partitions scanned',
        QUERY_HISTORY.partitions_total AS QUERY_HISTORY.PARTITIONS_TOTAL
            WITH SYNONYMS ('total partitions')
            COMMENT = 'Total partitions in scanned tables',
            
        -- Cache/Spill Metrics
        QUERY_HISTORY.cache_hit_ratio AS QUERY_HISTORY.PERCENTAGE_SCANNED_FROM_CACHE
            WITH SYNONYMS ('cache hit', 'cache percentage')
            COMMENT = 'Percentage of data read from cache',
        QUERY_HISTORY.bytes_spilled_local AS QUERY_HISTORY.BYTES_SPILLED_TO_LOCAL_STORAGE
            WITH SYNONYMS ('local spill')
            COMMENT = 'Bytes spilled to local SSD',
        QUERY_HISTORY.bytes_spilled_remote AS QUERY_HISTORY.BYTES_SPILLED_TO_REMOTE_STORAGE
            WITH SYNONYMS ('remote spill')
            COMMENT = 'Bytes spilled to remote storage - indicates memory pressure'
    )
    
    DIMENSIONS (
        -- Query Identifiers
        QUERY_HISTORY.query_id AS QUERY_HISTORY.QUERY_ID
            WITH SYNONYMS ('query identifier', 'id')
            COMMENT = 'Unique query identifier',
        QUERY_HISTORY.query_parameterized_hash AS QUERY_HISTORY.QUERY_PARAMETERIZED_HASH
            WITH SYNONYMS ('query pattern', 'normalized hash')
            COMMENT = 'Groups similar queries with different parameters',
            
        -- User Context
        QUERY_HISTORY.user_name AS QUERY_HISTORY.USER_NAME
            WITH SYNONYMS ('user', 'who ran', 'executor')
            COMMENT = 'User who executed the query',
        QUERY_HISTORY.role_name AS QUERY_HISTORY.ROLE_NAME
            WITH SYNONYMS ('role', 'execution role')
            COMMENT = 'Role used to execute the query',
            
        -- Warehouse Context
        QUERY_HISTORY.warehouse_name AS QUERY_HISTORY.WAREHOUSE_NAME
            WITH SYNONYMS ('warehouse', 'compute')
            COMMENT = 'Virtual warehouse used',
        QUERY_HISTORY.warehouse_size AS QUERY_HISTORY.WAREHOUSE_SIZE
            WITH SYNONYMS ('size')
            COMMENT = 'Warehouse size: X-Small to 6X-Large',
            
        -- Query Metadata
        QUERY_HISTORY.query_type AS QUERY_HISTORY.QUERY_TYPE
            WITH SYNONYMS ('statement type', 'operation')
            COMMENT = 'Type: SELECT, INSERT, UPDATE, DELETE, etc.',
        QUERY_HISTORY.execution_status AS QUERY_HISTORY.EXECUTION_STATUS
            WITH SYNONYMS ('status', 'result')
            COMMENT = 'Query status: SUCCESS, FAIL, INCIDENT',
        QUERY_HISTORY.error_message AS QUERY_HISTORY.ERROR_MESSAGE
            WITH SYNONYMS ('error', 'failure reason')
            COMMENT = 'Error message if query failed',
            
        -- Time Dimensions
        QUERY_HISTORY.start_time AS QUERY_HISTORY.START_TIME
            WITH SYNONYMS ('query start', 'when')
            COMMENT = 'When the query started',
            
        -- Access History Dimensions
        ACCESS_HISTORY.direct_objects_accessed AS ACCESS_HISTORY.DIRECT_OBJECTS_ACCESSED
            WITH SYNONYMS ('tables accessed', 'what tables')
            COMMENT = 'Array of tables directly referenced - use LATERAL FLATTEN',
        ACCESS_HISTORY.objects_modified AS ACCESS_HISTORY.OBJECTS_MODIFIED
            WITH SYNONYMS ('tables modified', 'data changes')
            COMMENT = 'Array of tables modified by the query'
    )
    
    METRICS (
        -- Query Counts
        QUERY_HISTORY.total_queries AS COUNT(QUERY_HISTORY.query_id)
            WITH SYNONYMS ('query count', 'executions')
            COMMENT = 'Total number of queries',
        QUERY_HISTORY.failed_queries AS SUM(CASE WHEN QUERY_HISTORY.execution_status != 'SUCCESS' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('failures', 'errors')
            COMMENT = 'Number of failed queries',
            
        -- Duration Metrics
        QUERY_HISTORY.avg_duration_ms AS AVG(QUERY_HISTORY.total_elapsed_time)
            WITH SYNONYMS ('average duration', 'avg runtime')
            COMMENT = 'Average query duration in milliseconds',
        QUERY_HISTORY.max_duration_ms AS MAX(QUERY_HISTORY.total_elapsed_time)
            WITH SYNONYMS ('max duration', 'slowest')
            COMMENT = 'Maximum query duration',
            
        -- Alert Metrics
        QUERY_HISTORY.long_running_count AS SUM(CASE WHEN QUERY_HISTORY.total_elapsed_time > 300000 THEN 1 ELSE 0 END)
            WITH SYNONYMS ('slow queries', 'long queries')
            COMMENT = 'Queries running longer than 5 minutes',
        QUERY_HISTORY.high_scan_pct_count AS SUM(CASE WHEN QUERY_HISTORY.partitions_scanned / NULLIF(QUERY_HISTORY.partitions_total, 0) > 0.9 THEN 1 ELSE 0 END)
            WITH SYNONYMS ('full scan queries')
            COMMENT = 'Queries scanning >90% of partitions',
        QUERY_HISTORY.queries_with_remote_spill AS SUM(CASE WHEN QUERY_HISTORY.bytes_spilled_remote > 0 THEN 1 ELSE 0 END)
            WITH SYNONYMS ('spill count', 'memory pressure')
            COMMENT = 'Queries with remote spillage',
            
        -- User Metrics
        QUERY_HISTORY.unique_users AS COUNT(DISTINCT QUERY_HISTORY.user_name)
            WITH SYNONYMS ('user count')
            COMMENT = 'Number of unique users'
    )
    
    COMMENT = 'Query performance analytics with user/table attribution and alerting metrics'
    
    AI_SQL_GENERATION 'Always filter with "_IS_CURRENT" = TRUE to get current records.

ALERTING THRESHOLDS:
- Long-running: TOTAL_ELAPSED_TIME > 300000 (5 minutes in ms)
- High scan %: PARTITIONS_SCANNED / NULLIF(PARTITIONS_TOTAL, 0) > 0.9
- Memory pressure: BYTES_SPILLED_TO_REMOTE_STORAGE > 0
- Queue contention: QUEUED_OVERLOAD_TIME > 30000 (30 seconds)

TABLE ACCESS (requires LATERAL FLATTEN):
- LATERAL FLATTEN(INPUT => DIRECT_OBJECTS_ACCESSED) f
- Then use: f.VALUE:objectName::STRING'

    AI_QUESTION_CATEGORIZATION 'Answers questions about:
- Query performance and duration trends
- Long-running query identification
- High partition scan queries (clustering candidates)
- Memory pressure (spill detection)
- User/table access patterns
- Failed query analysis';
```

### 4.2 Create Cost Analytics Semantic View

```sql
CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.COST_ANALYTICS
    
    TABLES (
        WAREHOUSE_METERING AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
            PRIMARY KEY (WAREHOUSE_ID, START_TIME)
            WITH SYNONYMS ('warehouse costs', 'compute costs', 'credits'),
            
        METERING_DAILY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.METERING_DAILY_HISTORY_ARCHIVE
            PRIMARY KEY (SERVICE_TYPE, USAGE_DATE)
            WITH SYNONYMS ('daily metering', 'daily costs')
    )
    
    FACTS (
        WAREHOUSE_METERING.credits_used AS WAREHOUSE_METERING.CREDITS_USED
            WITH SYNONYMS ('credits consumed', 'compute credits')
            COMMENT = 'Total credits consumed by warehouse',
        WAREHOUSE_METERING.credits_used_compute AS WAREHOUSE_METERING.CREDITS_USED_COMPUTE
            WITH SYNONYMS ('compute only')
            COMMENT = 'Compute-only credits',
        WAREHOUSE_METERING.credits_used_cloud_services AS WAREHOUSE_METERING.CREDITS_USED_CLOUD_SERVICES
            WITH SYNONYMS ('cloud service credits')
            COMMENT = 'Cloud services credits',
        METERING_DAILY.daily_credits AS METERING_DAILY.CREDITS_USED
            WITH SYNONYMS ('daily total')
            COMMENT = 'Total daily credits by service'
    )
    
    DIMENSIONS (
        WAREHOUSE_METERING.warehouse_name AS WAREHOUSE_METERING.WAREHOUSE_NAME
            WITH SYNONYMS ('warehouse', 'compute')
            COMMENT = 'Virtual warehouse name',
        WAREHOUSE_METERING.start_time AS WAREHOUSE_METERING.START_TIME
            WITH SYNONYMS ('time', 'when')
            COMMENT = 'Metering period start',
        METERING_DAILY.service_type AS METERING_DAILY.SERVICE_TYPE
            WITH SYNONYMS ('service', 'type')
            COMMENT = 'Snowflake service type',
        METERING_DAILY.usage_date AS METERING_DAILY.USAGE_DATE
            WITH SYNONYMS ('date')
            COMMENT = 'Usage date'
    )
    
    METRICS (
        WAREHOUSE_METERING.total_credits AS SUM(WAREHOUSE_METERING.credits_used)
            WITH SYNONYMS ('total spend', 'total cost')
            COMMENT = 'Total credits consumed',
        WAREHOUSE_METERING.avg_credits AS AVG(WAREHOUSE_METERING.credits_used)
            WITH SYNONYMS ('average cost')
            COMMENT = 'Average credits per period'
    )
    
    COMMENT = 'Cost analytics for warehouse compute and daily metering'
    
    AI_SQL_GENERATION 'Filter with "_IS_CURRENT" = TRUE. Use START_TIME for time filtering.'
    
    AI_QUESTION_CATEGORIZATION 'Answers questions about warehouse costs, credit consumption, and spending trends';
```

### 4.3 Create Security Analytics Semantic View

```sql
CREATE OR REPLACE SEMANTIC VIEW TEMPORAL_ARCHIVE.SEMANTIC.SECURITY_ANALYTICS
    
    TABLES (
        LOGIN_HISTORY AS TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
            PRIMARY KEY (EVENT_ID)
            WITH SYNONYMS ('logins', 'authentication', 'sign ins')
    )
    
    FACTS (
        LOGIN_HISTORY.is_success AS LOGIN_HISTORY.IS_SUCCESS
            WITH SYNONYMS ('success flag')
            COMMENT = 'Whether login was successful'
    )
    
    DIMENSIONS (
        LOGIN_HISTORY.event_id AS LOGIN_HISTORY.EVENT_ID
            WITH SYNONYMS ('login id')
            COMMENT = 'Unique login event identifier',
        LOGIN_HISTORY.user_name AS LOGIN_HISTORY.USER_NAME
            WITH SYNONYMS ('user', 'who logged in')
            COMMENT = 'User who attempted login',
        LOGIN_HISTORY.client_ip AS LOGIN_HISTORY.CLIENT_IP
            WITH SYNONYMS ('ip address', 'source ip')
            COMMENT = 'Client IP address',
        LOGIN_HISTORY.reported_client_type AS LOGIN_HISTORY.REPORTED_CLIENT_TYPE
            WITH SYNONYMS ('client type', 'application')
            COMMENT = 'Client application type',
        LOGIN_HISTORY.first_authentication_factor AS LOGIN_HISTORY.FIRST_AUTHENTICATION_FACTOR
            WITH SYNONYMS ('auth method', 'authentication')
            COMMENT = 'Primary authentication method',
        LOGIN_HISTORY.second_authentication_factor AS LOGIN_HISTORY.SECOND_AUTHENTICATION_FACTOR
            WITH SYNONYMS ('mfa', 'second factor')
            COMMENT = 'MFA method if used',
        LOGIN_HISTORY.event_timestamp AS LOGIN_HISTORY.EVENT_TIMESTAMP
            WITH SYNONYMS ('login time', 'when')
            COMMENT = 'When login occurred',
        LOGIN_HISTORY.error_code AS LOGIN_HISTORY.ERROR_CODE
            WITH SYNONYMS ('error')
            COMMENT = 'Error code if failed',
        LOGIN_HISTORY.error_message AS LOGIN_HISTORY.ERROR_MESSAGE
            WITH SYNONYMS ('failure reason')
            COMMENT = 'Error message if failed'
    )
    
    METRICS (
        LOGIN_HISTORY.total_logins AS COUNT(LOGIN_HISTORY.event_id)
            WITH SYNONYMS ('login count')
            COMMENT = 'Total login attempts',
        LOGIN_HISTORY.successful_logins AS SUM(CASE WHEN LOGIN_HISTORY.is_success = 'YES' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('successes')
            COMMENT = 'Successful logins',
        LOGIN_HISTORY.failed_logins AS SUM(CASE WHEN LOGIN_HISTORY.is_success = 'NO' THEN 1 ELSE 0 END)
            WITH SYNONYMS ('failures', 'failed attempts')
            COMMENT = 'Failed login attempts',
        LOGIN_HISTORY.unique_users AS COUNT(DISTINCT LOGIN_HISTORY.user_name)
            WITH SYNONYMS ('user count')
            COMMENT = 'Unique users'
    )
    
    COMMENT = 'Security analytics for login monitoring and access auditing'
    
    AI_SQL_GENERATION 'Filter with "_IS_CURRENT" = TRUE. Use EVENT_TIMESTAMP for time filtering. IS_SUCCESS = ''YES'' for successful logins, ''NO'' for failures.'
    
    AI_QUESTION_CATEGORIZATION 'Answers questions about login attempts, failed logins, authentication methods, MFA adoption, and user access patterns';
```

### 4.4 Verify Semantic Views

```sql
-- List all semantic views
SHOW SEMANTIC VIEWS IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC;

-- Should show 3 semantic views:
-- QUERY_PERFORMANCE_ANALYTICS
-- COST_ANALYTICS
-- SECURITY_ANALYTICS
```

**✅ Checkpoint**: Run `SHOW SEMANTIC VIEWS IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC;` — you should see 3 semantic views.

---

## Step 5: Query Your Archive (5 minutes)

Now let's run some analytical queries against the archive.

### 5.1 Long-Running Query Detection

Find queries that ran longer than 5 minutes:

```sql
SELECT 
    USER_NAME,
    WAREHOUSE_NAME,
    WAREHOUSE_SIZE,
    QUERY_TYPE,
    ROUND(TOTAL_ELAPSED_TIME / 1000 / 60, 2) AS duration_minutes,
    ROUND(BYTES_SCANNED / 1024 / 1024 / 1024, 2) AS gb_scanned,
    EXECUTION_STATUS,
    START_TIME
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND TOTAL_ELAPSED_TIME > 300000  -- 5 minutes in milliseconds
  AND START_TIME >= DATEADD(day, -30, CURRENT_TIMESTAMP())
ORDER BY TOTAL_ELAPSED_TIME DESC
LIMIT 20;
```

### 5.2 High Partition Scan Analysis (Clustering Candidates)

Find queries scanning >90% of partitions (candidates for clustering):

```sql
SELECT 
    USER_NAME,
    WAREHOUSE_NAME,
    QUERY_PARAMETERIZED_HASH,
    COUNT(*) AS execution_count,
    AVG(PARTITIONS_SCANNED / NULLIF(PARTITIONS_TOTAL, 0) * 100) AS avg_scan_pct,
    AVG(TOTAL_ELAPSED_TIME / 1000) AS avg_duration_seconds,
    SUM(BYTES_SCANNED) / 1024 / 1024 / 1024 AS total_gb_scanned
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND PARTITIONS_TOTAL > 100  -- Only tables with meaningful partition counts
  AND PARTITIONS_SCANNED / NULLIF(PARTITIONS_TOTAL, 0) > 0.9
  AND START_TIME >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY USER_NAME, WAREHOUSE_NAME, QUERY_PARAMETERIZED_HASH
HAVING COUNT(*) >= 3  -- Repeated patterns
ORDER BY total_gb_scanned DESC
LIMIT 20;
```

### 5.3 Memory Pressure Analysis (Spill Detection)

Find queries with remote spillage (candidates for warehouse upsizing):

```sql
SELECT 
    USER_NAME,
    WAREHOUSE_NAME,
    WAREHOUSE_SIZE,
    COUNT(*) AS spill_count,
    ROUND(SUM(BYTES_SPILLED_TO_REMOTE_STORAGE) / 1024 / 1024 / 1024, 2) AS total_remote_spill_gb,
    ROUND(AVG(TOTAL_ELAPSED_TIME) / 1000, 2) AS avg_duration_seconds
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND BYTES_SPILLED_TO_REMOTE_STORAGE > 0
  AND START_TIME >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY USER_NAME, WAREHOUSE_NAME, WAREHOUSE_SIZE
ORDER BY total_remote_spill_gb DESC
LIMIT 10;
```

### 5.4 User-Table Access Patterns

Find which tables each user accessed (using LATERAL FLATTEN):

```sql
SELECT 
    ah.USER_NAME,
    f.VALUE:objectName::STRING AS table_accessed,
    f.VALUE:objectDomain::STRING AS object_type,
    COUNT(*) AS access_count,
    MIN(ah.QUERY_START_TIME) AS first_access,
    MAX(ah.QUERY_START_TIME) AS last_access
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ACCESS_HISTORY_ARCHIVE ah,
     LATERAL FLATTEN(INPUT => ah.DIRECT_OBJECTS_ACCESSED) f
WHERE ah."_IS_CURRENT" = TRUE
  AND ah.QUERY_START_TIME >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY ah.USER_NAME, f.VALUE:objectName::STRING, f.VALUE:objectDomain::STRING
HAVING COUNT(*) >= 5
ORDER BY access_count DESC
LIMIT 20;
```

### 5.5 Failed Login Analysis

Check for failed login attempts (security monitoring):

```sql
SELECT 
    USER_NAME,
    CLIENT_IP,
    REPORTED_CLIENT_TYPE,
    ERROR_CODE,
    ERROR_MESSAGE,
    COUNT(*) AS failure_count,
    MIN(EVENT_TIMESTAMP) AS first_failure,
    MAX(EVENT_TIMESTAMP) AS last_failure
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND IS_SUCCESS = 'NO'
  AND EVENT_TIMESTAMP >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY USER_NAME, CLIENT_IP, REPORTED_CLIENT_TYPE, ERROR_CODE, ERROR_MESSAGE
ORDER BY failure_count DESC
LIMIT 20;
```

### 5.6 Warehouse Cost Analysis

Analyze credit consumption by warehouse:

```sql
SELECT 
    WAREHOUSE_NAME,
    DATE_TRUNC('day', START_TIME) AS usage_date,
    ROUND(SUM(CREDITS_USED), 2) AS total_credits,
    ROUND(SUM(CREDITS_USED_COMPUTE), 2) AS compute_credits,
    ROUND(SUM(CREDITS_USED_CLOUD_SERVICES), 2) AS cloud_credits
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY WAREHOUSE_NAME, DATE_TRUNC('day', START_TIME)
ORDER BY usage_date DESC, total_credits DESC
LIMIT 50;
```

---

## Step 6: Schedule Automated Loads (Optional)

### 6.1 Create Scheduled Tasks

Set up automated loads twice daily (6 AM and 6 PM):

```sql
USE ROLE DATA_ADMIN;

-- Morning load task (6 AM ET)
CREATE OR REPLACE TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_MORNING
    WAREHOUSE = TEMPORAL_ARCHIVE_WH
    SCHEDULE = 'USING CRON 0 6 * * * America/New_York'
    COMMENT = 'Morning SCD load at 6 AM Eastern'
AS
    CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();

-- Evening load task (6 PM ET)
CREATE OR REPLACE TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING
    WAREHOUSE = TEMPORAL_ARCHIVE_WH
    SCHEDULE = 'USING CRON 0 18 * * * America/New_York'
    COMMENT = 'Evening SCD load at 6 PM Eastern'
AS
    CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();

-- Enable the tasks
ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_MORNING RESUME;
ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING RESUME;
```

### 6.2 Verify Tasks

```sql
-- Check task status
SHOW TASKS IN SCHEMA TEMPORAL_ARCHIVE.ARCHIVE;

-- View task history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD(hour, -24, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 10
))
ORDER BY SCHEDULED_TIME DESC;
```

---

## Step 7: Grant Access to Users (Optional)

### 7.1 Grant Read Access

```sql
USE ROLE ACCOUNTADMIN;

-- Grant reader role to analysts
GRANT ROLE TEMPORAL_ARCHIVE_READER TO USER analyst_user;

-- Grant specific schema access
GRANT USAGE ON DATABASE TEMPORAL_ARCHIVE TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.ACCOUNT_USAGE TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA TEMPORAL_ARCHIVE.ACCOUNT_USAGE TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE TEMPORAL_ARCHIVE_READER;
GRANT USAGE ON WAREHOUSE TEMPORAL_ARCHIVE_WH TO ROLE TEMPORAL_ARCHIVE_READER;
```

---

## Step 8: WORM-Compliant Backup Policy (Optional - Business Critical Edition)

> **Important**: This step requires **Business Critical Edition** or higher. Retention lock and legal holds are not available on Standard or Enterprise editions. To check your edition, run: `SELECT CURRENT_ACCOUNT(), SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO();`

### Understanding Snowflake Backups

Snowflake Backups provide **Write Once, Read Many (WORM)** protection for your data. According to the [Snowflake documentation](https://docs.snowflake.com/en/user-guide/backups):

| Use Case | Description |
|----------|-------------|
| **Regulatory Compliance** | Meet SEC 17a-4(f), FINRA 4511(c), CFTC 1.31, HIPAA requirements with immutable records |
| **Cyber Resilience** | Protect against ransomware - retention lock prevents deletion even by ACCOUNTADMIN |
| **Disaster Recovery** | Create point-in-time snapshots for recovery from accidental modifications |

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Backup** | A point-in-time snapshot of a table, schema, or database. Cannot be modified. |
| **Backup Set** | A schema-level object containing backups for a specific object. Max 2 per object. |
| **Backup Policy** | Defines schedule (hourly/daily/cron) and expiration period for automated backups. |
| **Retention Lock** | **IRREVERSIBLE** - Prevents backup deletion until expiration. Cannot be revoked by anyone, including Snowflake Support. |
| **Legal Hold** | Prevents specific backups from deletion, even after expiration. Can be removed by privileged users. |

### How Backups Work

Backups are **zero-copy** snapshots similar to clones:
- No data duplication at creation time
- Snowflake maintains pointers to immutable micro-partitions
- Storage costs only for retained data files that would otherwise be deleted
- Minimal compute cost for scheduled creation/expiration

### 8.1 Create Backup Schema and Policies

```sql
USE ROLE DATA_ADMIN;
USE DATABASE TEMPORAL_ARCHIVE;
USE WAREHOUSE TEMPORAL_ARCHIVE_WH;

-- Create schema for backup objects
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.BACKUPS
    COMMENT = 'Backup policies and backup sets for WORM compliance';

-- Grant retention lock privilege (ACCOUNTADMIN only)
USE ROLE ACCOUNTADMIN;
GRANT APPLY BACKUP RETENTION LOCK ON ACCOUNT TO ROLE DATA_ADMIN;
USE ROLE DATA_ADMIN;
```

### 8.2 Create Backup Policy (Without Retention Lock)

Start with a standard backup policy for testing:

```sql
-- Daily backup policy WITHOUT retention lock (can be deleted)
-- Good for testing before enabling WORM
CREATE OR REPLACE BACKUP POLICY TEMPORAL_ARCHIVE.BACKUPS.DAILY_BACKUP_POLICY
    SCHEDULE = '1440 MINUTE'  -- Every 24 hours
    EXPIRE_AFTER_DAYS = 30    -- Keep for 30 days
    COMMENT = 'Daily backups with 30-day retention (no lock)';
```

### 8.3 Create WORM Backup Policy (With Retention Lock)

> **WARNING**: Retention lock is **IRREVERSIBLE**. Once applied, backups cannot be deleted until expiration, even by ACCOUNTADMIN or Snowflake Support. Plan carefully to avoid unexpected storage charges.

```sql
-- 7-YEAR WORM backup policy WITH retention lock
-- IRREVERSIBLE - Cannot be revoked once applied to a backup set
CREATE OR REPLACE BACKUP POLICY TEMPORAL_ARCHIVE.BACKUPS.WORM_7_YEAR_POLICY
    WITH RETENTION LOCK
    SCHEDULE = 'USING CRON 0 0 * * SUN America/New_York'  -- Weekly on Sunday midnight
    EXPIRE_AFTER_DAYS = 2555  -- ~7 years (365 * 7)
    COMMENT = 'WORM-compliant weekly backups with 7-year retention lock for SEC 17a-4, FINRA, HIPAA';
```

### 8.4 Create Backup Sets

```sql
-- Backup set for entire TEMPORAL_ARCHIVE database (standard policy)
CREATE BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.ARCHIVE_DB_BACKUPS
    FOR DATABASE TEMPORAL_ARCHIVE
    WITH BACKUP POLICY TEMPORAL_ARCHIVE.BACKUPS.DAILY_BACKUP_POLICY
    COMMENT = 'Daily backups of entire Temporal Archive database';

-- Backup set for critical QUERY_HISTORY table (WORM policy)
-- WARNING: This applies retention lock - backups cannot be deleted for 7 years
CREATE BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.QUERY_HISTORY_WORM
    FOR TABLE TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
    WITH BACKUP POLICY TEMPORAL_ARCHIVE.BACKUPS.WORM_7_YEAR_POLICY
    COMMENT = 'WORM-compliant backups for regulatory audit trail';
```

### 8.5 Manual Backup Operations

```sql
-- Take an immediate backup (outside of schedule)
ALTER BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.ARCHIVE_DB_BACKUPS ADD BACKUP;

-- List all backups in a backup set
SHOW BACKUPS IN BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.ARCHIVE_DB_BACKUPS;

-- Get backup details
SHOW BACKUPS IN BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.ARCHIVE_DB_BACKUPS
    >> SELECT "backup_id", "created_on", "expire_on", "is_under_legal_hold" FROM $1;
```

### 8.6 Restore from Backup

```sql
-- Get the latest backup ID
SHOW BACKUPS IN BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.ARCHIVE_DB_BACKUPS
    >> SET latest_backup = (SELECT "backup_id" FROM $1 ORDER BY "created_on" DESC LIMIT 1);

-- Restore database to a new database
CREATE DATABASE TEMPORAL_ARCHIVE_RESTORED
    FROM BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.ARCHIVE_DB_BACKUPS
    IDENTIFIER $latest_backup;

-- Restore single table
SHOW BACKUPS IN BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.QUERY_HISTORY_WORM
    >> SET table_backup = (SELECT "backup_id" FROM $1 ORDER BY "created_on" DESC LIMIT 1);

CREATE TABLE TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_RESTORED
    FROM BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.QUERY_HISTORY_WORM
    IDENTIFIER $table_backup;
```

### 8.7 Apply Legal Hold (Optional)

Legal holds prevent specific backups from deletion even after expiration:

```sql
-- Grant legal hold privilege
USE ROLE ACCOUNTADMIN;
GRANT APPLY LEGAL HOLD ON ACCOUNT TO ROLE DATA_ADMIN;
USE ROLE DATA_ADMIN;

-- Apply legal hold to a specific backup
SHOW BACKUPS IN BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.ARCHIVE_DB_BACKUPS
    >> SET hold_backup = (SELECT "backup_id" FROM $1 ORDER BY "created_on" DESC LIMIT 1);

ALTER BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.ARCHIVE_DB_BACKUPS
    MODIFY BACKUP IDENTIFIER $hold_backup ADD LEGAL HOLD;

-- Remove legal hold (when no longer needed)
ALTER BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.ARCHIVE_DB_BACKUPS
    MODIFY BACKUP IDENTIFIER $hold_backup REMOVE LEGAL HOLD;
```

### 8.8 Monitor Backup Storage and Operations

```sql
-- Monitor backup storage usage
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.BACKUP_STORAGE_USAGE
ORDER BY USAGE_DATE DESC
LIMIT 30;

-- Monitor backup operations (creation, expiration, errors)
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.BACKUP_OPERATION_HISTORY
ORDER BY START_TIME DESC
LIMIT 50;

-- List all backup sets in account
SHOW BACKUP SETS;

-- List all backup policies
SHOW BACKUP POLICIES;
```

### 8.9 Verify Backup Configuration

```sql
-- Check backup set details
DESCRIBE BACKUP SET TEMPORAL_ARCHIVE.BACKUPS.ARCHIVE_DB_BACKUPS;

-- Check backup policy details
DESCRIBE BACKUP POLICY TEMPORAL_ARCHIVE.BACKUPS.DAILY_BACKUP_POLICY;
DESCRIBE BACKUP POLICY TEMPORAL_ARCHIVE.BACKUPS.WORM_7_YEAR_POLICY;
```

### Important Considerations for WORM Backups

| Consideration | Details |
|---------------|---------|
| **Irreversibility** | Retention lock cannot be revoked by anyone, including Snowflake Support |
| **Storage Costs** | Backups retain data files that would otherwise be deleted; monitor BACKUP_STORAGE_USAGE |
| **Max Backup Sets** | Maximum 2 backup sets per object (table/schema/database) |
| **Schedule Minimum** | Minimum schedule interval is 60 minutes (1 hour) |
| **Expiration Increase** | With retention lock, you can increase (but not decrease) expiration period |
| **Object Deletion** | Cannot drop database/schema/table if it has unexpired retention-locked backups |

### Regulatory Compliance

Snowflake backups with retention lock have been independently assessed by **Cohasset Associates** for compliance with:

- **SEC 17a-4(f)** - Securities and Exchange Commission electronic records
- **SEC 18a-6(e)** - Security-based swap dealers records
- **FINRA Rule 4511(c)** - Books and records requirements
- **CFTC Rule 1.31(c)-(d)** - Commodity Futures Trading Commission records

For the full compliance report, visit the [Snowflake Compliance Center](https://www.snowflake.com/trust-center/).

**✅ Checkpoint**: Run `SHOW BACKUP SETS;` to verify your backup sets are created.

---

## Summary

Congratulations! You have successfully deployed the Snowflake Temporal Archive with:

| Component | Status |
|-----------|--------|
| **Database** | TEMPORAL_ARCHIVE |
| **Warehouse** | TEMPORAL_ARCHIVE_WH |
| **Archive Tables** | 16+ SCD Type 2 tables |
| **Semantic Views** | 3 AI-ready views |
| **Scheduled Tasks** | 2 (morning + evening) |
| **Roles** | DATA_ADMIN, TEMPORAL_ARCHIVE_READER/WRITER/ADMIN |
| **WORM Backup** | Optional (Business Critical Edition required) |

### What's Next?

1. **Add More Views**: Expand the VIEW_REGISTRY to archive additional ACCOUNT_USAGE views
2. **Deploy More Semantic Views**: Add STORAGE_ANALYTICS, GOVERNANCE_ANALYTICS, BCDR_ANALYTICS
3. **Enable Cortex Analyst**: Use the semantic views with natural language queries
4. **Create Dashboards**: Build Snowsight dashboards for monitoring
5. **Set Up Alerts**: Create alerts for long-running queries, failed logins, etc.
6. **Enable WORM Backups**: If on Business Critical Edition, add retention-locked backups for compliance

### Key SCD Type 2 Columns

When querying archive tables, remember these columns:

| Column | Purpose |
|--------|---------|
| `_IS_CURRENT` | TRUE = current record, FALSE = historical |
| `_VALID_FROM` | When this version became active |
| `_VALID_TO` | When this version was superseded (NULL = current) |
| `_ROW_HASH` | SHA-256 hash for change detection |
| `_LOADED_AT` | When the record was loaded |

### Point-in-Time Query Example

```sql
-- Query data as it existed on a specific date
SELECT *
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE "_VALID_FROM" <= '2024-06-15'::TIMESTAMP
  AND ("_VALID_TO" > '2024-06-15'::TIMESTAMP OR "_VALID_TO" IS NULL);
```

---

## Cleanup (Optional)

To remove all Temporal Archive objects:

```sql
USE ROLE ACCOUNTADMIN;

-- Drop the database (this removes all tables, views, procedures)
DROP DATABASE IF EXISTS TEMPORAL_ARCHIVE;

-- Drop the warehouse
DROP WAREHOUSE IF EXISTS TEMPORAL_ARCHIVE_WH;

-- Drop the roles
DROP ROLE IF EXISTS TEMPORAL_ARCHIVE_READER;
DROP ROLE IF EXISTS TEMPORAL_ARCHIVE_WRITER;
DROP ROLE IF EXISTS TEMPORAL_ARCHIVE_ADMIN;
DROP ROLE IF EXISTS DATA_ADMIN;
```

---

## References

- [Snowflake Backups Documentation](https://docs.snowflake.com/en/user-guide/backups)
- [Semantic Views Reference](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view)
- [ACCOUNT_USAGE Views](https://docs.snowflake.com/en/sql-reference/account-usage)
- [SCD Type 2 Pattern](https://en.wikipedia.org/wiki/Slowly_changing_dimension#Type_2:_add_new_row)
