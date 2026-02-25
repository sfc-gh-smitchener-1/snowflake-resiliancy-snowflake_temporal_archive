---
name: temporal-archive
description: Deploy Snowflake Temporal Archive - SCD Type 2 preservation of ACCOUNT_USAGE data with 7-year WORM backups, semantic views for Cortex Analyst, and an AI-powered Intelligence Agent for deep account analysis.
---

# Snowflake Temporal Archive Skill

Deploy a complete temporal data archive solution that preserves your Snowflake ACCOUNT_USAGE data with SCD Type 2 history, WORM-compliant backups, and AI-powered analytics.

## What This Skill Creates

1. **SCD Type 2 Archive Tables** - Preserve every change to 133 registered ACCOUNT_USAGE & ORGANIZATION_USAGE views (107 active) with full audit trail
2. **WORM Backup Policy** - SEC 17a-4 / HIPAA / FINRA compliant immutable backups (7-year retention)
3. **Automated Data Loads** - Twice daily scheduled tasks (configurable)
4. **10 Semantic Views** - Natural language analytics via Cortex Analyst
5. **Cortex Intelligence Agent** - AI agent with 10 tools for deep account analysis
6. **Streamlit Dashboard** - Interactive analytics application

## Prerequisites1

Before deploying, ensure you have:
- ACCOUNTADMIN role access (for initial setup)
- A Snowflake connection configured in Cortex Code
- Cortex Analyst and Cortex Agents enabled in your account

## Quick Start

If you want to deploy with default settings:

```
Deploy Temporal Archive to my account using the default connection
```

For customized deployment:

```
Deploy Temporal Archive with database name MY_ARCHIVE and warehouse MY_WH
```

## Configuration Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `database_name` | TEMPORAL_ARCHIVE | Target database name |
| `warehouse_name` | TEMPORAL_ARCHIVE_WH | Warehouse name |
| `warehouse_size` | XSMALL | Warehouse size (LARGE Gen2 recommended for production) |
| `admin_role` | DATA_ADMIN | Primary admin role |
| `backup_retention_days` | 2555 | Backup retention (7 years default) |
| `morning_load_hour` | 6 | Morning SCD load hour (local timezone) |
| `evening_load_hour` | 18 | Evening SCD load hour (local timezone) |
| `timezone` | America/New_York | Timezone for scheduled tasks |
| `connection` | default | Snowflake connection name |

## Deployment Workflow

### Step 1: Gather Configuration

Ask the user for their deployment preferences:

```
I'll help you deploy the Temporal Archive. Let me gather a few configuration details:

1. **Database Name** - Where to create the archive (default: TEMPORAL_ARCHIVE)
2. **Warehouse Name** - Compute warehouse (default: TEMPORAL_ARCHIVE_WH)  
3. **Snowflake Connection** - Which connection to use (default: default)
4. **Retention Period** - How long to retain backups (default: 7 years / 2555 days)

Would you like to use defaults or customize these settings?
```

### Step 2: Validate Prerequisites

Before deployment, validate the environment:

```sql
-- Check ACCOUNTADMIN access
SELECT CURRENT_ROLE();

-- Check if database already exists
SHOW DATABASES LIKE '<DATABASE_NAME>';

-- Check Cortex availability
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'test') IS NOT NULL AS cortex_available;
```

### Step 3: Deploy Infrastructure

Run the SQL scripts in order, substituting parameters:

**3.1 Initial Setup (01_initial_setup.sql)**
- Creates database, warehouse, roles
- Creates backup policy with WORM compliance
- Creates schemas (ARCHIVE, ACCOUNT_USAGE, ORGANIZATION_USAGE, SEMANTIC, STREAMLIT)

**3.2 SCD Load Infrastructure (02_scd_load.sql)**
- Creates VIEW_REGISTRY with 133 source views (107 active, 26 deactivated)
- Creates WATERMARK_STATE for delta load tracking
- Creates LOAD_VIEW_ARCHIVE procedure (3-strategy SCD Type 2 logic)
- Creates scheduled tasks for automated loads

**3.3 Semantic Layer (03_semantic_layer.sql)**
- Creates 10 semantic views for Cortex Analyst:
  - WAREHOUSE_COST_ANALYTICS
  - SERVERLESS_COST_ANALYTICS
  - COST_ANALYTICS
  - BCDR_ANALYTICS
  - SECURITY_ANALYTICS
  - STORAGE_ANALYTICS
  - GOVERNANCE_ANALYTICS
  - TASK_ANALYTICS
  - QUERY_PERFORMANCE_ANALYTICS
  - ORGANIZATION_ANALYTICS

**3.4 Streamlit Support (04_streamlit_ddl.sql)**
- Creates helper views and procedures
- Creates APP_CONFIG table

**3.5 Intelligence Agent**
- Creates SNOWFLAKEACCOUNTARCHIVE agent with 10 semantic view tools

### Step 4: Initial Data Load

After deployment, run initial SCD load:

```sql
CALL <DATABASE_NAME>.ARCHIVE.RUN_SCD_LOAD();
```

### Step 5: Verify Deployment

```sql
-- Check archive tables created
SELECT COUNT(*) as tables_created 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_CATALOG = '<DATABASE_NAME>' 
AND TABLE_SCHEMA IN ('ACCOUNT_USAGE', 'ORGANIZATION_USAGE');

-- Check semantic views
SHOW SEMANTIC VIEWS IN SCHEMA <DATABASE_NAME>.SEMANTIC;

-- Check agent
SHOW AGENTS IN SCHEMA <DATABASE_NAME>.SEMANTIC;

-- Check tasks are scheduled
SHOW TASKS IN SCHEMA <DATABASE_NAME>.ARCHIVE;
```

## SQL Template Variables

When generating SQL, replace these placeholders:

| Placeholder | Example Value |
|-------------|---------------|
| `{{DATABASE_NAME}}` | TEMPORAL_ARCHIVE |
| `{{WAREHOUSE_NAME}}` | TEMPORAL_ARCHIVE_WH |
| `{{WAREHOUSE_SIZE}}` | XSMALL |
| `{{ADMIN_ROLE}}` | DATA_ADMIN |
| `{{READER_ROLE}}` | TEMPORAL_ARCHIVE_READER |
| `{{WRITER_ROLE}}` | TEMPORAL_ARCHIVE_WRITER |
| `{{ARCHIVE_ADMIN_ROLE}}` | TEMPORAL_ARCHIVE_ADMIN |
| `{{BACKUP_POLICY_NAME}}` | {{DATABASE_NAME}}_WORM_BACKUP_POLICY |
| `{{BACKUP_RETENTION_DAYS}}` | 2555 |
| `{{BACKUP_SCHEDULE_MINUTES}}` | 1440 |
| `{{MORNING_LOAD_HOUR}}` | 6 |
| `{{EVENING_LOAD_HOUR}}` | 18 |
| `{{TIMEZONE}}` | America/New_York |
| `{{QUERY_TIMEOUT_SECONDS}}` | 299 |
| `{{ORG_SCHEMA}}` | ORGANIZATION_USAGE |

## File Locations

The SQL templates are located at:
- `sql/01_initial_setup.sql` - Infrastructure setup
- `sql/02_scd_load.sql` - SCD procedures and tasks
- `sql/03_semantic_layer.sql` - Semantic views
- `sql/04_streamlit_ddl.sql` - Streamlit support
- `sql/05_streamlit_app.sql` - Streamlit app deployment
- `agent/snowflake_intelligence_agent.json` - Agent configuration

## Post-Deployment

After successful deployment:

1. **Access Cortex Analyst**: Navigate to AI & ML → Cortex Analyst → Select any semantic view
2. **Access the Agent**: Navigate to AI & ML → Cortex Agents → SNOWFLAKEACCOUNTARCHIVE
3. **Monitor Loads**: Check LOAD_LOG table for SCD load history
4. **Deploy Streamlit** (optional): Upload app.py and run 05_streamlit_app.sql

## Sample Questions for the Agent

Once deployed, try these questions with the Intelligence Agent:

**Cost Analysis:**
- "Which warehouses consumed the most credits last month?"
- "Show me my dynamic table costs"
- "Who are my top credit consumers?"

**BC/DR Analysis:**
- "What are my hot tables with highest data churn?"
- "Show storage breakdown for DR planning"
- "What's my RPO based on replication schedules?"

**Security:**
- "Show failed login attempts this week"
- "Which users don't have MFA enabled?"
- "What are the login patterns by client type?"

**Operations:**
- "Which tasks are failing most frequently?"
- "Show me task error patterns"

**Query Performance:**
- "Show me long-running queries over 5 minutes"
- "Which users accessed the CUSTOMERS table?"
- "What queries have high partition scan percentages?"
- "Find queries with memory spill issues"

**Organization (requires ORGADMIN):**
- "What is our remaining contract balance?"
- "Show org-wide warehouse credit consumption by account"
- "What is total storage usage across all accounts?"

## Troubleshooting

### "Insufficient privileges" Error
Ensure you're using ACCOUNTADMIN role for initial setup:
```sql
USE ROLE ACCOUNTADMIN;
```

### Semantic Views Not Appearing in Cortex Analyst
Grant usage to the semantic schema:
```sql
GRANT USAGE ON DATABASE {{DATABASE_NAME}} TO ROLE SYSADMIN;
GRANT USAGE ON SCHEMA {{DATABASE_NAME}}.SEMANTIC TO ROLE SYSADMIN;
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA {{DATABASE_NAME}}.SEMANTIC TO ROLE SYSADMIN;
```

### Agent Not Responding
Ensure the agent has access to semantic views:
```sql
GRANT USAGE ON AGENT {{DATABASE_NAME}}.SEMANTIC.SNOWFLAKEACCOUNTARCHIVE TO ROLE <YOUR_ROLE>;
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│           SNOWFLAKE.ACCOUNT_USAGE (98 active views)                  │
│           SNOWFLAKE.ORGANIZATION_USAGE (9 active views)              │
└─────────────────────┬───────────────────────────────────────────────┘
                      │ Twice Daily 3-Strategy Delta Load
                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    {{DATABASE_NAME}}                                │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ ACCOUNT_USAGE Schema (SCD Type 2 Archive Tables)            │   │
│  │ - _ARCHIVE_ID (surrogate key)                               │   │
│  │ - _IS_CURRENT (current record flag)                         │   │
│  │ - _VALID_FROM / _VALID_TO (temporal validity)               │   │
│  │ - _ROW_HASH (change detection)                              │   │
│  │ - 7+ year retention via WORM backup                         │   │
│  └─────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ SEMANTIC Schema (10 Semantic Views + Cortex Agent)           │   │
│  │ - WAREHOUSE_COST_ANALYTICS                                  │   │
│  │ - SERVERLESS_COST_ANALYTICS                                 │   │
│  │ - COST_ANALYTICS                                            │   │
│  │ - BCDR_ANALYTICS (hot tables, churn, RPO/RTO)              │   │
│  │ - SECURITY_ANALYTICS                                        │   │
│  │ - STORAGE_ANALYTICS                                         │   │
│  │ - GOVERNANCE_ANALYTICS                                      │   │
│  │ - TASK_ANALYTICS                                            │   │
│  │ - QUERY_PERFORMANCE_ANALYTICS                               │   │
│  │ - ORGANIZATION_ANALYTICS                                    │   │
│  │ - SNOWFLAKEACCOUNTARCHIVE (Cortex Agent, 10 tools)          │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Support

For issues or enhancements, contact the Snowflake Field team or submit to the repository.
