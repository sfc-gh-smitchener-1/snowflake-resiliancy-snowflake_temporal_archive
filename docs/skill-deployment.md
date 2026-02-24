# Cortex Code Skill Deployment Guide

This repository includes a Cortex Code skill for self-service deployment of the Temporal Archive to any Snowflake account.

## Quick Start

In Cortex Code, simply say:

```
Deploy Temporal Archive to my account
```

For customized deployment:

```
Deploy Temporal Archive with database MY_ARCHIVE and warehouse MY_WH
```

## Skill Structure

```
skill/
├── SKILL.md                    # Main entry point (loaded by Cortex Code)
├── config.template.yaml        # All configurable parameters
├── templates/                  # Parameterized SQL templates
│   ├── 01_initial_setup.sql    # Database, warehouse, roles, backup policy
│   ├── 02_scd_load.sql         # VIEW_REGISTRY, SCD procedures, tasks
│   ├── 03_semantic_layer.sql    # 9 semantic views
│   ├── 04_streamlit_ddl.sql    # Streamlit support objects
│   └── agent_config.json       # Cortex Agent specification
└── scripts/
    ├── deploy.py               # Full deployment automation
    └── quick_setup.py          # Interactive setup helper
```

## Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `database_name` | TEMPORAL_ARCHIVE | Target database name |
| `warehouse_name` | TEMPORAL_ARCHIVE_WH | Compute warehouse |
| `warehouse_size` | LARGE | Warehouse size (recommended LARGE Gen2 for production) |
| `admin_role` | DATA_ADMIN | Primary admin role |
| `backup_retention_days` | 2555 | 7-year WORM retention |
| `morning_load_hour` | 6 | Morning SCD load (local timezone) |
| `evening_load_hour` | 18 | Evening SCD load (local timezone) |
| `timezone` | America/New_York | Task timezone |

## Template Variables

The SQL templates use `{{VARIABLE}}` syntax for parameterization:

| Variable | Example |
|----------|---------|
| `{{DATABASE_NAME}}` | TEMPORAL_ARCHIVE |
| `{{WAREHOUSE_NAME}}` | TEMPORAL_ARCHIVE_WH |
| `{{ADMIN_ROLE}}` | DATA_ADMIN |
| `{{READER_ROLE}}` | TEMPORAL_ARCHIVE_READER |
| `{{WRITER_ROLE}}` | TEMPORAL_ARCHIVE_WRITER |
| `{{SEMANTIC_SCHEMA}}` | SEMANTIC |
| `{{BACKUP_RETENTION_DAYS}}` | 2555 |
| `{{MORNING_LOAD_HOUR}}` | 6 |
| `{{EVENING_LOAD_HOUR}}` | 18 |
| `{{TIMEZONE}}` | America/New_York |

## Manual Deployment (Without Cortex Code)

### Step 1: Generate Parameterized SQL

```bash
cd skill/scripts
python quick_setup.py --defaults
# Or interactive mode:
python quick_setup.py
```

This generates SQL in `skill/scripts/generated/`:
- `01_initial_setup.sql`
- `02_scd_load.sql`
- `03_semantic_layer.sql`
- `04_streamlit_ddl.sql`
- `agent_config.json`

### Step 2: Run SQL Scripts

```sql
-- As ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;
\i generated/01_initial_setup.sql

-- As DATA_ADMIN (or your admin role)
USE ROLE DATA_ADMIN;
\i generated/02_scd_load.sql
\i generated/03_semantic_layer.sql
\i generated/04_streamlit_ddl.sql
```

### Step 3: Create Cortex Agent

Use the `agent-optimization` skill in Cortex Code:

```
Create agent from agent/snowflake_intelligence_agent.json
```

Or use the REST API directly with the generated `agent_config.json`.

### Step 4: Run Initial Load

```sql
CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();
```

### Step 5: Verify Deployment

```sql
-- Check archive tables
SELECT COUNT(*) as tables_created 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_CATALOG = 'TEMPORAL_ARCHIVE' 
AND TABLE_SCHEMA IN ('ACCOUNT_USAGE', 'ORGANIZATION_USAGE');

-- Check semantic views
SHOW SEMANTIC VIEWS IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC;

-- Check agent
SHOW AGENTS IN SCHEMA TEMPORAL_ARCHIVE.AGENTS;

-- Check scheduled tasks
SHOW TASKS IN SCHEMA TEMPORAL_ARCHIVE.ARCHIVE;
```

## What Gets Deployed

| Component | Count | Schema |
|-----------|-------|--------|
| SCD Archive Tables | 84 active | ACCOUNT_USAGE (29 org/reader/data-sharing deactivated) |
| Semantic Views | 9 | SEMANTIC |
| Cortex Agent | 1 | AGENTS |
| Scheduled Tasks | 2 | ARCHIVE |
| Procedures | 3 | ARCHIVE |
| Backup Policy | 1 | ARCHIVE |

## Customization Examples

### Different Database Name

```yaml
# config.yaml
database_name: MY_DATA_ARCHIVE
warehouse_name: MY_ARCHIVE_WH
```

### Hourly Loads Instead of Twice Daily

Modify the task schedules in `02_scd_load.sql`:

```sql
-- Change from:
SCHEDULE = 'USING CRON 0 6 * * * America/New_York'
-- To hourly:
SCHEDULE = 'USING CRON 0 * * * * America/New_York'
```

### Different Retention Period

```yaml
# config.yaml
backup_retention_days: 365  # 1 year instead of 7
```

### Disable Backup Policy

Set retention to 0 in config:

```yaml
backup_retention_days: 0
```

Or comment out the backup policy section in `01_initial_setup.sql`.

## Troubleshooting

### "Insufficient privileges" Error

Ensure ACCOUNTADMIN for initial setup:

```sql
USE ROLE ACCOUNTADMIN;
```

### Semantic Views Not Visible

Grant access to the semantic schema:

```sql
GRANT USAGE ON DATABASE TEMPORAL_ARCHIVE TO ROLE SYSADMIN;
GRANT USAGE ON SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE SYSADMIN;
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA TEMPORAL_ARCHIVE.SEMANTIC TO ROLE SYSADMIN;
```

### Agent Not Responding

Grant agent usage:

```sql
GRANT USAGE ON AGENT TEMPORAL_ARCHIVE.AGENTS.SNOWFLAKE_INTELLIGENCE TO ROLE <YOUR_ROLE>;
```

### Tasks Not Running

Resume tasks if suspended:

```sql
ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_MORNING RESUME;
ALTER TASK TEMPORAL_ARCHIVE.ARCHIVE.TASK_SCD_LOAD_EVENING RESUME;
```

## Requirements

- **Snowflake Edition**: Business Critical or higher (for RETENTION LOCK)
- **Role**: ACCOUNTADMIN for initial setup
- **Features**: Cortex Analyst and Cortex Agents enabled in account
