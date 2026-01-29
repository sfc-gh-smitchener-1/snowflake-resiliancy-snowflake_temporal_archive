# Snowflake Temporal Archive

## Project Overview

**Snowflake Temporal Archive** is a data platform solution designed to capture and preserve the complete temporal history of all `Snowflake.*` data shares using **SCD Type 2** (Slowly Changing Dimension) tables. The archived data is protected using Snowflake's native **Backup Policy with RETENTION LOCK** to meet **WORM (Write Once Read Many)** compliance requirements.

### Core Objectives

1. **Temporal History Preservation** - Capture every change to shared data with full audit trail
2. **WORM Compliance** - Immutable backups with RETENTION LOCK (7-year retention)
3. **Semantic Model Foundation** - Enable AI agents and research analysis on historical usage patterns
4. **Deep Data Analytics** - Comprehensive analysis of Snowflake data usage and trends

### Operational Model

| Process | Schedule | Execution Method |
|---------|----------|------------------|
| **SCD Load** | Twice daily (6 AM, 6 PM) | Snowflake Task → `CALL RUN_SCD_LOAD()` |
| **WORM Backup** | Daily | Snowflake Backup Policy with RETENTION LOCK |

All operations run **natively within Snowflake** - no external orchestration required.

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              DAILY OPERATIONS SCHEDULE                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   06:00 AM ─────────┐                                                               │
│                     ▼                                                               │
│              ┌─────────────┐     ┌─────────────────────────────────────────────┐    │
│              │ SCD LOAD #1 │────▶│ Load from Snowflake.* views → Archive      │    │
│              └─────────────┘     └─────────────────────────────────────────────┘    │
│                                                                                     │
│   06:00 PM ─────────┐                                                               │
│                     ▼                                                               │
│              ┌─────────────┐     ┌─────────────────────────────────────────────┐    │
│              │ SCD LOAD #2 │────▶│ Load from Snowflake.* views → Archive      │    │
│              └─────────────┘     └─────────────────────────────────────────────┘    │
│                                                                                     │
│   Daily ────────────┐                                                               │
│                     ▼                                                               │
│              ┌─────────────┐     ┌─────────────────────────────────────────────┐    │
│              │ WORM BACKUP │────▶│ Snowflake Backup Policy (RETENTION LOCK)   │    │
│              │   POLICY    │     │ • Immutable (cannot be deleted by anyone)  │    │
│              └─────────────┘     │ • 7-year retention (2555 days)             │    │
│                                  │ Ref: docs.snowflake.com/en/user-guide/     │    │
│                                  │      backups                               │    │
│                                  └─────────────────────────────────────────────┘    │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Reference Documentation

All implementations reference the official Snowflake backup documentation:
- **Primary Reference**: https://docs.snowflake.com/en/user-guide/backups

---

## Architecture

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           SNOWFLAKE TEMPORAL ARCHIVE                                    │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────────────────────┐  │
│  │  Snowflake.*     │    │   STAGING        │    │      SCD TYPE 2 TABLES           │  │
│  │  Data Shares     │───▶│   LAYER          │───▶│      (Temporal History)          │  │
│  │                  │    │                  │    │                                  │  │
│  │  • ACCOUNT_USAGE │    │  • Raw Ingestion │    │  • Full Change History           │  │
│  │  • ORGANIZATION  │    │  • Hash Compute  │    │  • _IS_CURRENT Tracking          │  │
│  │  • DATA_SHARING  │    │  • CDC Detection │    │  • _VALID_FROM / _VALID_TO       │  │
│  │  • READER_USAGE  │    │                  │    │                                  │  │
│  └──────────────────┘    └──────────────────┘    └──────────────────────────────────┘  │
│                                                               │                         │
│                                                               ▼                         │
│                                    ┌──────────────────────────────────────────────┐    │
│                                    │       SNOWFLAKE BACKUP POLICY                │    │
│                                    │       (WORM Compliance)                      │    │
│                                    │                                              │    │
│                                    │  • WITH RETENTION LOCK                       │    │
│                                    │  • Daily backups (1440 minutes)              │    │
│                                    │  • 7-year retention (2555 days)              │    │
│                                    │  • Immutable - cannot be deleted             │    │
│                                    │  • Requires Business Critical Edition        │    │
│                                    │                                              │    │
│                                    │  Ref: docs.snowflake.com/en/user-guide/      │    │
│                                    │       backups                                │    │
│                                    └──────────────────────────────────────────────┘    │
│                                                               │                         │
│                                                               ▼                         │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                           SEMANTIC & ANALYTICS LAYER                              │  │
│  │                                                                                   │  │
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────────┐   │  │
│  │  │  Semantic Models    │  │  Agent Research     │  │  Usage Analytics        │   │  │
│  │  │                     │  │                     │  │                         │   │  │
│  │  │  • Entity Graphs    │  │  • Pattern Mining   │  │  • Historical Trends    │   │  │
│  │  │  • Relationship     │  │  • Anomaly Detect   │  │  • Cost Analysis        │   │  │
│  │  │    Mapping          │  │  • Usage Forecast   │  │  • Performance Metrics  │   │  │
│  │  │  • Context Layer    │  │  • Compliance Audit │  │  • Deep Data Insights   │   │  │
│  │  └─────────────────────┘  └─────────────────────┘  └─────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### SCD Type 2 Processing Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          SCD TYPE 2 CHANGE DETECTION                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   SOURCE RECORD                      ARCHIVE TABLE                                  │
│   ┌─────────────┐                    ┌──────────────────────────────────────────┐   │
│   │ Id: 001     │                    │ Id: 001                                  │   │
│   │ Name: Acme  │   ──COMPARE──▶     │ _ROW_HASH: abc123...                     │   │
│   │ Status: New │   (Hash Match?)    │ _IS_CURRENT: TRUE                        │   │
│   └─────────────┘                    │ _VALID_FROM: 2024-01-01 00:00:00         │   │
│         │                            │ _VALID_TO: 9999-12-31                    │   │
│         │                            └──────────────────────────────────────────┘   │
│         │                                                                           │
│         ▼                                                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                         HASH MISMATCH DETECTED                              │   │
│   │                                                                             │   │
│   │   1. UPDATE existing record:                                                │   │
│   │      SET _IS_CURRENT = FALSE                                                │   │
│   │      SET _VALID_TO = CURRENT_TIMESTAMP()                                    │   │
│   │                                                                             │   │
│   │   2. INSERT new record:                                                     │   │
│   │      _IS_CURRENT = TRUE                                                     │   │
│   │      _VALID_FROM = CURRENT_TIMESTAMP()                                      │   │
│   │      _VALID_TO = '9999-12-31 23:59:59'                                      │   │
│   │      _ROW_HASH = NEW_HASH                                                   │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### WORM Backup Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    SNOWFLAKE BACKUP POLICY - WORM COMPLIANCE                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                    TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY                      │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        ▼                                            │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                                                                             │   │
│   │   CREATE BACKUP POLICY TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY                  │   │
│   │       WITH RETENTION LOCK                                                   │   │
│   │       SCHEDULE = '1440 MINUTE'                                              │   │
│   │       EXPIRE_AFTER_DAYS = 2555                                              │   │
│   │                                                                             │   │
│   │   ┌─────────────────────────────────────────────────────────────────────┐   │   │
│   │   │  RETENTION LOCK GUARANTEES:                                         │   │   │
│   │   │                                                                     │   │   │
│   │   │  • Backups CANNOT be deleted by ANY user                            │   │   │
│   │   │  • Even ACCOUNTADMIN and ORGADMIN cannot remove                     │   │   │
│   │   │  • Meets SEC 17a-4, FINRA, HIPAA requirements                       │   │   │
│   │   │  • Immutable audit trail for regulatory compliance                  │   │   │
│   │   └─────────────────────────────────────────────────────────────────────┘   │   │
│   │                                                                             │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│   Applied To: TEMPORAL_ARCHIVE database                                             │
│   Retention:  7 years (2555 days)                                                   │
│   Schedule:   Daily (every 1440 minutes)                                            │
│   Edition:    Business Critical or higher required                                  │
│                                                                                     │
│   Reference: https://docs.snowflake.com/en/user-guide/backups                       │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## SCD Column Specification

**Every table** in the Snowflake Temporal Archive must include the following SCD metadata columns appended to the end of each row:

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `_LOADED_AT` | `TIMESTAMP_NTZ` | Timestamp when the record was loaded into the archive |
| `_SOURCE_SYSTEM` | `VARCHAR(100)` | Source system identifier (e.g., 'SNOWFLAKE_ACCOUNT_USAGE') |
| `_SOURCE_TABLE` | `VARCHAR(100)` | Original source table name |
| `_ROW_HASH` | `VARCHAR(64)` | SHA-256 hash of business columns for change detection |
| `_IS_CURRENT` | `BOOLEAN` | Flag indicating if this is the current active version |
| `_VALID_FROM` | `TIMESTAMP_NTZ` | Timestamp when this version became effective |
| `_VALID_TO` | `VARCHAR(50)` | Timestamp when this version was superseded (or '9999-12-31 23:59:59' for current) |
| `Id` | `VARCHAR(18)` | Primary identifier from source system |
| `IsDeleted` | `BOOLEAN` | Soft delete flag from source |
| `CreatedDate` | `VARCHAR(50)` | Original creation timestamp from source |
| `CreatedById` | `VARCHAR(18)` | User ID who created the record in source |
| `LastModifiedDate` | `VARCHAR(50)` | Last modification timestamp from source |
| `LastModifiedById` | `VARCHAR(18)` | User ID who last modified the record in source |
| `SystemModstamp` | `VARCHAR(50)` | System modification timestamp from source |

### Column Order Convention

All archive tables follow this column structure:

```sql
CREATE TABLE archive_schema.TABLE_NAME (
    -- Business columns from source table first
    <source_column_1>     <datatype>,
    <source_column_2>     <datatype>,
    ...
    <source_column_n>     <datatype>,
    
    -- SCD metadata columns (ALWAYS at the end, in this exact order)
    "_LOADED_AT"          TIMESTAMP_NTZ,
    "_SOURCE_SYSTEM"      VARCHAR(100),
    "_SOURCE_TABLE"       VARCHAR(100),
    "_ROW_HASH"           VARCHAR(64),
    "_IS_CURRENT"         BOOLEAN,
    "_VALID_FROM"         TIMESTAMP_NTZ,
    "_VALID_TO"           VARCHAR(50),
    "Id"                  VARCHAR(18),
    "IsDeleted"           BOOLEAN,
    "CreatedDate"         VARCHAR(50),
    "CreatedById"         VARCHAR(18),
    "LastModifiedDate"    VARCHAR(50),
    "LastModifiedById"    VARCHAR(18),
    "SystemModstamp"      VARCHAR(50)
);
```

---

## Project Structure

```
snowflake-temporal-archive/
├── README.md                              # Project overview, architecture, and AI context
│
├── sql/
│   ├── ddl/
│   │   └── 01_initial_setup.sql           # Database, schemas, warehouse, backup policy
│   ├── procedures/
│   │   └── scd_load_procedure.sql         # RUN_SCD_LOAD() procedure + Tasks
│   ├── backup/
│   │   └── worm_backup.sql                # Backup policy documentation
│   └── analytics/
│       ├── usage-analysis/                # Usage pattern queries
│       └── compliance-reports/            # WORM compliance reporting
│
├── docs/
│   ├── architecture/
│   │   ├── overview.md                    # Detailed architecture documentation
│   │   ├── scd-type2-patterns.md          # SCD implementation patterns
│   │   └── worm-compliance.md             # WORM backup policy strategies
│   ├── semantic-models/
│   │   ├── entity-definitions.md          # Semantic entity specifications
│   │   ├── relationship-graphs.md         # Entity relationship documentation
│   │   └── agent-context.md               # AI agent context layer specs
│   └── analytics/
│       ├── usage-patterns.md              # Historical usage analysis docs
│       └── research-queries.md            # Research query templates
│
└── semantic/
    ├── models/                            # Semantic model definitions
    ├── embeddings/                        # Vector embedding configs
    └── agents/                            # Agent research configurations
```

---

## Quick Start

### 1. Run Initial Setup

```sql
-- Execute the setup script in Snowflake
-- Reference: https://docs.snowflake.com/en/user-guide/backups
-- NOTE: Requires Business Critical Edition for RETENTION LOCK

USE ROLE ACCOUNTADMIN;

-- Run the setup file (includes backup policy creation)
!source sql/ddl/01_initial_setup.sql
```

**Or run manually:**

```sql
-- Create database
CREATE DATABASE IF NOT EXISTS TEMPORAL_ARCHIVE;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ARCHIVE;
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ACCOUNT_USAGE;
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.ORGANIZATION_USAGE;
CREATE SCHEMA IF NOT EXISTS TEMPORAL_ARCHIVE.DATA_SHARING_USAGE;

-- Create warehouse
CREATE WAREHOUSE IF NOT EXISTS TEMPORAL_ARCHIVE_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

-- Create WORM backup policy (requires Business Critical Edition)
CREATE BACKUP POLICY TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY
    WITH RETENTION LOCK
    SCHEDULE = '1440 MINUTE'
    EXPIRE_AFTER_DAYS = 2555
    COMMENT = 'WORM-compliant daily backups with 7-year retention';

-- Apply backup policy to database
ALTER DATABASE TEMPORAL_ARCHIVE
    SET BACKUP POLICY = TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY;
```

### 2. Deploy SCD Load Procedures and Tasks

```sql
-- Deploy the SCD load procedure and scheduled tasks
!source sql/procedures/scd_load_procedure.sql
```

### 3. Verify Setup

```sql
-- Check backup policy
DESCRIBE BACKUP POLICY TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY;

-- Verify policy is applied
SHOW DATABASES LIKE 'TEMPORAL_ARCHIVE';

-- Check task status
SHOW TASKS IN SCHEMA TEMPORAL_ARCHIVE.ARCHIVE;

-- Manual test run
CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();
```

### Operations Schedule

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    SNOWFLAKE TEMPORAL ARCHIVE - OPERATIONS                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   TASK_SCD_LOAD_MORNING                                                         │
│   ├── Schedule: CRON 0 6 * * * (6:00 AM daily)                                  │
│   ├── Procedure: CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD()                   │
│   └── Purpose: Load Snowflake.* views → Archive tables (SCD Type 2)             │
│                                                                                 │
│   TASK_SCD_LOAD_EVENING                                                         │
│   ├── Schedule: CRON 0 18 * * * (6:00 PM daily)                                 │
│   ├── Procedure: CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD()                   │
│   └── Purpose: Load Snowflake.* views → Archive tables (SCD Type 2)             │
│                                                                                 │
│   TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY                                           │
│   ├── Schedule: Daily (every 1440 minutes)                                      │
│   ├── Retention: 7 years (2555 days)                                            │
│   ├── RETENTION LOCK: Enabled (immutable, cannot be deleted)                    │
│   └── Purpose: WORM-compliant backups per regulatory requirements               │
│                                                                                 │
│   Reference: https://docs.snowflake.com/en/user-guide/backups                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Example: Archive Table Structure

```sql
-- Example: QUERY_HISTORY archive table
-- Reference: https://docs.snowflake.com/en/user-guide/backups

CREATE TABLE TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE (
    -- Source columns (from Snowflake.ACCOUNT_USAGE.QUERY_HISTORY)
    QUERY_ID                VARCHAR(36),
    QUERY_TEXT              VARCHAR(16777216),
    DATABASE_NAME           VARCHAR(256),
    SCHEMA_NAME             VARCHAR(256),
    QUERY_TYPE              VARCHAR(256),
    SESSION_ID              NUMBER(38,0),
    USER_NAME               VARCHAR(256),
    WAREHOUSE_NAME          VARCHAR(256),
    WAREHOUSE_SIZE          VARCHAR(256),
    EXECUTION_STATUS        VARCHAR(256),
    START_TIME              TIMESTAMP_LTZ,
    END_TIME                TIMESTAMP_LTZ,
    TOTAL_ELAPSED_TIME      NUMBER(38,0),
    
    -- SCD Metadata Columns (REQUIRED - Always at end of EVERY table)
    "_LOADED_AT"            TIMESTAMP_NTZ,
    "_SOURCE_SYSTEM"        VARCHAR(100),
    "_SOURCE_TABLE"         VARCHAR(100),
    "_ROW_HASH"             VARCHAR(64),
    "_IS_CURRENT"           BOOLEAN,
    "_VALID_FROM"           TIMESTAMP_NTZ,
    "_VALID_TO"             VARCHAR(50),
    "Id"                    VARCHAR(18),
    "IsDeleted"             BOOLEAN,
    "CreatedDate"           VARCHAR(50),
    "CreatedById"           VARCHAR(18),
    "LastModifiedDate"      VARCHAR(50),
    "LastModifiedById"      VARCHAR(18),
    "SystemModstamp"        VARCHAR(50)
);
```

---

## Implementation Phases

### Phase 1: Foundation
- [ ] Database and schema setup
- [ ] Backup policy with RETENTION LOCK
- [ ] SCD Type 2 stored procedures
- [ ] Snowflake Task scheduling

### Phase 2: Data Capture
- [ ] Snowflake.ACCOUNT_USAGE archive
- [ ] Snowflake.ORGANIZATION_USAGE archive
- [ ] Snowflake.DATA_SHARING_USAGE archive
- [ ] Snowflake.READER_ACCOUNT_USAGE archive

### Phase 3: WORM Compliance Validation
- [ ] Verify backup policy execution
- [ ] Confirm RETENTION LOCK behavior
- [ ] Compliance audit reporting
- [ ] 7-year retention verification

### Phase 4: Semantic Layer
- [ ] Entity semantic models
- [ ] Relationship graph construction
- [ ] Agent context layer
- [ ] Research query framework

### Phase 5: Analytics & Research
- [ ] Historical usage pattern analysis
- [ ] Cost trend analytics
- [ ] Performance deep-dives
- [ ] AI-assisted research tools

---

## Key Design Principles

1. **Immutability First** - Backup policy with RETENTION LOCK ensures immutable backups
2. **Complete Lineage** - Full audit trail from source to archive
3. **Hash-Based CDC** - Deterministic change detection via SHA-256 row hashing
4. **Native Execution** - All operations run within Snowflake (Tasks + Backup Policy)
5. **Compliance by Design** - 7-year WORM retention built into architecture
6. **Research Ready** - Structure optimized for historical analysis and AI agents

---

## Requirements

- **Snowflake Edition**: Business Critical or higher (required for RETENTION LOCK)
- **Permissions**: ACCOUNTADMIN role for initial setup
- **Storage**: Sufficient storage for 7 years of daily backups

---

## Contributing

When contributing to this project:

1. All tables MUST include the complete SCD column set (14 columns)
2. Reference https://docs.snowflake.com/en/user-guide/backups for backup patterns
3. Include ASCII architecture diagrams in documentation
4. Document semantic model implications
5. Consider agent/research use cases in design decisions

---

## References

- **Snowflake Backups**: https://docs.snowflake.com/en/user-guide/backups
- **Backup Policy**: https://docs.snowflake.com/en/sql-reference/sql/create-backup-policy
- **WORM Compliance**: https://docs.snowflake.com/en/release-notes/2025/other/2025-12-10-worm-backups
- **Tasks**: https://docs.snowflake.com/en/user-guide/tasks-intro
