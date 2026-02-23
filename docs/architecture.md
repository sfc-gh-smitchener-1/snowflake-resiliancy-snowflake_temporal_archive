# Technical Architecture

Detailed technical architecture of the Snowflake Temporal Archive solution.

## High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              DATA FLOW ARCHITECTURE                             │
└─────────────────────────────────────────────────────────────────────────────────┘

    SNOWFLAKE.ACCOUNT_USAGE (186 views)
    SNOWFLAKE.ORGANIZATION_USAGE (21 views)
                    │
                    │ Twice Daily (6 AM & 6 PM)
                    │ Snowflake Tasks
                    ▼
    ┌───────────────────────────────────────────────────────────────────┐
    │                    TEMPORAL_ARCHIVE Database                      │
    │                                                                   │
    │  ┌────────────────────────────────────────────────────────────┐   │
    │  │ ARCHIVE Schema                                             │   │
    │  │ • VIEW_REGISTRY (186 source views)                         │   │
    │  │ • LOAD_LOG (execution history)                             │   │
    │  │ • RUN_SCD_LOAD() procedure                                 │   │
    │  │ • TASK_SCD_LOAD_MORNING (6 AM)                             │   │
    │  │ • TASK_SCD_LOAD_EVENING (6 PM)                             │   │
    │  └────────────────────────────────────────────────────────────┘   │
    │                           │                                       │
    │                           ▼                                       │
    │  ┌────────────────────────────────────────────────────────────┐   │
    │  │ ACCOUNT_USAGE Schema (SCD Type 2 Archive Tables)           │   │
    │  │ • QUERY_HISTORY_ARCHIVE                                    │   │
    │  │ • USERS_ARCHIVE                                            │   │
    │  │ • LOGIN_HISTORY_ARCHIVE                                    │   │
    │  │ • WAREHOUSE_METERING_HISTORY_ARCHIVE                       │   │
    │  │ • ... (186 total archive tables)                           │   │
    │  └────────────────────────────────────────────────────────────┘   │
    │                           │                                       │
    │                           ▼                                       │
    │  ┌────────────────────────────────────────────────────────────┐   │
    │  │ SEMANTIC Schema (9 Semantic Views)                         │   │
    │  │ • WAREHOUSE_COST_ANALYTICS                                 │   │
    │  │ • SERVERLESS_COST_ANALYTICS                                │   │
    │  │ • COST_ANALYTICS                                           │   │
    │  │ • SECURITY_ANALYTICS                                       │   │  
    │  │ • STORAGE_ANALYTICS                                        │   │
    │  │ • GOVERNANCE_ANALYTICS                                     │   │
    │  │ • TASK_ANALYTICS                                           │   │
    │  │ • BCDR_ANALYTICS                                           │   │
    │  │ • QUERY_PERFORMANCE_ANALYTICS                              │   │
    │  └────────────────────────────────────────────────────────────┘   │
    │                           │                                       │
    │                           ▼                                       │
    │  ┌────────────────────────────────────────────────────────────┐   │
    │  │ AGENTS Schema                                              │   │
    │  │ • SNOWFLAKE_INTELLIGENCE (Cortex Agent)                    │   │
    │  │   - 8 tools mapping to semantic views                      │   │
    │  │   - Natural language query interface                       │   │
    │  └────────────────────────────────────────────────────────────┘   │
    │                                                                   │
    │  ┌────────────────────────────────────────────────────────────┐   │
    │  │ Backup Policy (WORM)                                       │   │
    │  │ • TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY                      │   │
    │  │ • 7-year retention (2555 days)                             │   │
    │  │ • RETENTION LOCK (immutable)                               │   │
    │  │ • Daily backups (1440 minutes)                             │   │
    │  └────────────────────────────────────────────────────────────┘   │
    │                                                                   │
    └───────────────────────────────────────────────────────────────────┘
```

## Database Objects

### Schemas

| Schema | Purpose |
|--------|---------|
| ARCHIVE | Core infrastructure (procedures, tasks, logging) |
| ACCOUNT_USAGE | SCD Type 2 tables from SNOWFLAKE.ACCOUNT_USAGE |
| ORGANIZATION_USAGE | SCD Type 2 tables from SNOWFLAKE.ORGANIZATION_USAGE |
| DATA_SHARING_USAGE | SCD Type 2 tables from SNOWFLAKE.DATA_SHARING_USAGE |
| READER_ACCOUNT_USAGE | SCD Type 2 tables from SNOWFLAKE.READER_ACCOUNT_USAGE |
| SEMANTIC | Semantic views for Cortex Analyst |
| AGENTS | Cortex Agents |
| STREAMLIT | Streamlit application objects |

### Role Hierarchy

```
ACCOUNTADMIN
    │
    ▼
DATA_ADMIN (Owner of all objects)
    │
    ├──► TEMPORAL_ARCHIVE_ADMIN (Full admin access)
    │         │
    │         ▼
    │    TEMPORAL_ARCHIVE_WRITER (Read + execute procedures)
    │         │
    │         ▼
    └───►TEMPORAL_ARCHIVE_READER (Read-only access)
```

### Key Procedures

| Procedure | Purpose |
|-----------|---------|
| `LOAD_VIEW_ARCHIVE(schema, view)` | Load single view with SCD Type 2 logic |
| `LOAD_VIEW_ARCHIVE_WITH_RETRY(schema, view, retries, delay)` | Wrapper with retry logic |
| `RUN_SCD_LOAD()` | Orchestrator - loads all views from VIEW_REGISTRY |

### Scheduled Tasks

| Task | Schedule | Purpose |
|------|----------|---------|
| TASK_SCD_LOAD_MORNING | 6:00 AM ET | Morning SCD load |
| TASK_SCD_LOAD_EVENING | 6:00 PM ET | Evening SCD load |

## SCD Type 2 Implementation

### Archive Table Schema

Every archive table includes these SCD columns:

| Column | Type | Description |
|--------|------|-------------|
| `_ARCHIVE_ID` | NUMBER | Surrogate key (auto-increment) |
| `_ROW_HASH` | VARCHAR(64) | SHA-256 hash of all source columns |
| `_LOADED_AT` | TIMESTAMP_NTZ | When record was loaded |
| `_SOURCE_SYSTEM` | VARCHAR | Source (e.g., SNOWFLAKE_ACCOUNT_USAGE) |
| `_SOURCE_TABLE` | VARCHAR | Source view name |
| `_IS_CURRENT` | BOOLEAN | TRUE if current version |
| `_VALID_FROM` | TIMESTAMP_NTZ | Version start time |
| `_VALID_TO` | TIMESTAMP_NTZ | Version end time (9999-12-31 if current) |

### Change Detection Flow

```
1. Compute SHA-256 hash of source row
2. Compare hash with current records in archive
3. If hash not found in current records:
   a. Mark existing current record as historical (_IS_CURRENT = FALSE, _VALID_TO = now)
   b. Insert new record (_IS_CURRENT = TRUE, _VALID_FROM = now)
4. Log results to LOAD_LOG
```

### Initial vs Incremental Load

**Initial Load** (table doesn't exist):
- Creates table with all SCD columns
- Inserts all source rows as current records
- Sets _VALID_FROM to load time, _VALID_TO to 9999-12-31

**Incremental Load** (table exists):
- Computes hash for all source rows
- Marks changed/deleted records as historical
- Inserts new/changed records as current

## Semantic Layer

### Semantic View Components

Each semantic view defines:

| Component | Purpose |
|-----------|---------|
| TABLES | Source archive tables with primary keys and synonyms |
| RELATIONSHIPS | Foreign key relationships between tables |
| FACTS | Measurable numeric values |
| DIMENSIONS | Attributes for grouping/filtering |
| METRICS | Pre-defined aggregations |
| AI_SQL_GENERATION | Hints for Cortex Analyst |
| AI_QUESTION_CATEGORIZATION | Question routing hints |

### Example: WAREHOUSE_COST_ANALYTICS

```sql
CREATE SEMANTIC VIEW WAREHOUSE_COST_ANALYTICS
    TABLES (
        WAREHOUSE_METERING AS ...WAREHOUSE_METERING_HISTORY_ARCHIVE
            PRIMARY KEY (START_TIME, WAREHOUSE_ID),
        QUERY_HISTORY AS ...QUERY_HISTORY_ARCHIVE
            PRIMARY KEY (QUERY_ID)
    )
    FACTS (
        credits_used, bytes_scanned, query_duration...
    )
    DIMENSIONS (
        warehouse_name, user_name, role_name, query_type...
    )
    METRICS (
        total_credits, avg_query_duration, failed_queries...
    )
```

## Backup Policy

### WORM Compliance

The backup policy ensures regulatory compliance:

```sql
CREATE BACKUP POLICY TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY
    WITH RETENTION LOCK        -- Cannot be disabled
    SCHEDULE = '1440 MINUTE'   -- Daily backups
    EXPIRE_AFTER_DAYS = 2555   -- 7 years
```

### Compliance Standards

- **SEC 17a-4**: Financial records retention
- **HIPAA**: Healthcare data retention
- **FINRA**: Broker-dealer compliance
- **SOX**: Audit trail requirements

## Performance Considerations

### Query Optimization

1. **Always filter on `_IS_CURRENT`** for current-state queries
2. **Use `_VALID_FROM`/`_VALID_TO`** for point-in-time queries
3. **Consider clustering** on large archive tables:

```sql
ALTER TABLE QUERY_HISTORY_ARCHIVE CLUSTER BY ("_IS_CURRENT", "_VALID_FROM");
```

### Warehouse Sizing

| Use Case | Recommended Size |
|----------|-----------------|
| Initial load (small account) | X-Small |
| Initial load (large account) | Medium |
| Incremental loads | X-Small |
| Complex analytical queries | Medium+ |

### Storage Estimation

Archive storage grows based on:
- Number of source views (186 baseline)
- Data change frequency
- Historical record accumulation

Formula: `Storage ≈ (Source Size × Avg Versions per Record) + SCD Overhead (~20%)`
