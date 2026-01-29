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

## The Strategic Value of ACCOUNT_USAGE Historical Data

### Why Archive ACCOUNT_USAGE?

The `SNOWFLAKE.ACCOUNT_USAGE` schema is a goldmine of operational intelligence, but **Snowflake only retains this data for 1 year**. After 365 days, critical insights into your platform's history are permanently lost. The Temporal Archive solves this by preserving the complete history indefinitely with WORM-compliant immutability.

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    THE ACCOUNT_USAGE RETENTION PROBLEM                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   SNOWFLAKE NATIVE                          TEMPORAL ARCHIVE                        │
│   ┌─────────────────────┐                   ┌─────────────────────┐                 │
│   │                     │                   │                     │                 │
│   │   365 DAYS ONLY     │      ────▶        │   7+ YEARS          │                 │
│   │                     │                   │                     │                 │
│   │   Then data is      │                   │   WORM-compliant    │                 │
│   │   PERMANENTLY LOST  │                   │   immutable history │                 │
│   │                     │                   │                     │                 │
│   └─────────────────────┘                   └─────────────────────┘                 │
│                                                                                     │
│   ❌ Cannot analyze multi-year trends       ✓ Full historical analysis              │
│   ❌ No audit trail for compliance          ✓ Complete audit trail                  │
│   ❌ Lost cost optimization insights        ✓ Deep cost pattern mining              │
│   ❌ Cannot prove historical access         ✓ Immutable access records              │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Business Value Categories

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         ACCOUNT_USAGE BUSINESS VALUE                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐                   │
│   │  COST           │   │  TRANSPARENCY   │   │  COMPLIANCE     │                   │
│   │  OPTIMIZATION   │   │  & GOVERNANCE   │   │  & AUDIT        │                   │
│   │                 │   │                 │   │                 │                   │
│   │  Save money     │   │  Full visibility│   │  Regulatory     │                   │
│   │  through data-  │   │  into platform  │   │  requirements   │                   │
│   │  driven insight │   │  operations     │   │  met with proof │                   │
│   └─────────────────┘   └─────────────────┘   └─────────────────┘                   │
│           │                     │                     │                             │
│           ▼                     ▼                     ▼                             │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                    SEMANTIC LAYER & AI AGENTS                               │   │
│   │                                                                             │   │
│   │  • Natural language queries on historical data                              │   │
│   │  • Automated anomaly detection and alerting                                 │   │
│   │  • Predictive cost forecasting                                              │   │
│   │  • Compliance report generation                                             │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Cost Optimization Use Cases

Historical ACCOUNT_USAGE data enables powerful cost analysis that can deliver **significant savings**:

### 1. Warehouse Right-Sizing Analysis

Identify over-provisioned warehouses by analyzing historical utilization patterns.

```sql
-- Example: Find warehouses consistently under-utilized over 2+ years
-- Potential savings: 20-40% reduction in compute costs

SELECT 
    WAREHOUSE_NAME,
    DATE_TRUNC('month', START_TIME) AS month,
    AVG(AVG_RUNNING) AS avg_concurrent_queries,
    AVG(AVG_QUEUED_LOAD) AS avg_queue_depth,
    SUM(CREDITS_USED) AS monthly_credits,
    -- Flag for right-sizing recommendation
    CASE 
        WHEN AVG(AVG_RUNNING) < 2 AND AVG(AVG_QUEUED_LOAD) < 0.1 
        THEN 'DOWNSIZE CANDIDATE'
        WHEN AVG(AVG_QUEUED_LOAD) > 1 
        THEN 'UPSIZE OR MULTI-CLUSTER'
        ELSE 'APPROPRIATELY SIZED'
    END AS recommendation
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
GROUP BY WAREHOUSE_NAME, DATE_TRUNC('month', START_TIME)
ORDER BY monthly_credits DESC;
```

### 2. Query Cost Attribution Over Time

Track which teams, users, or applications drive costs across years - not just months.

```sql
-- Example: Multi-year cost attribution by user/role
-- Use case: Chargeback models, budget planning, identifying cost trends

SELECT 
    USER_NAME,
    ROLE_NAME,
    DATE_TRUNC('quarter', START_TIME) AS quarter,
    COUNT(*) AS query_count,
    SUM(TOTAL_ELAPSED_TIME) / 1000 / 60 AS total_minutes,
    SUM(CREDITS_USED_CLOUD_SERVICES) AS cloud_credits,
    -- Year-over-year comparison
    LAG(SUM(CREDITS_USED_CLOUD_SERVICES)) OVER (
        PARTITION BY USER_NAME ORDER BY DATE_TRUNC('quarter', START_TIME)
    ) AS prev_quarter_credits,
    ROUND(
        (SUM(CREDITS_USED_CLOUD_SERVICES) - LAG(SUM(CREDITS_USED_CLOUD_SERVICES)) OVER (
            PARTITION BY USER_NAME ORDER BY DATE_TRUNC('quarter', START_TIME)
        )) / NULLIF(LAG(SUM(CREDITS_USED_CLOUD_SERVICES)) OVER (
            PARTITION BY USER_NAME ORDER BY DATE_TRUNC('quarter', START_TIME)
        ), 0) * 100, 2
    ) AS quarter_over_quarter_pct_change
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
GROUP BY USER_NAME, ROLE_NAME, DATE_TRUNC('quarter', START_TIME)
ORDER BY quarter DESC, cloud_credits DESC;
```

### 3. Storage Growth Forecasting

Predict future storage needs and costs based on multi-year growth patterns.

```sql
-- Example: Storage growth trend analysis for capacity planning
-- Use case: Budget forecasting, contract negotiations

SELECT 
    USAGE_DATE,
    AVERAGE_STAGE_BYTES / POWER(1024, 4) AS stage_tb,
    AVERAGE_DATABASE_BYTES / POWER(1024, 4) AS database_tb,
    AVERAGE_FAILSAFE_BYTES / POWER(1024, 4) AS failsafe_tb,
    (AVERAGE_STAGE_BYTES + AVERAGE_DATABASE_BYTES + AVERAGE_FAILSAFE_BYTES) 
        / POWER(1024, 4) AS total_tb,
    -- Calculate monthly growth rate
    (total_tb - LAG(total_tb, 30) OVER (ORDER BY USAGE_DATE)) 
        / NULLIF(LAG(total_tb, 30) OVER (ORDER BY USAGE_DATE), 0) * 100 
        AS monthly_growth_pct
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.STORAGE_USAGE_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
ORDER BY USAGE_DATE DESC;
```

---

## Transparency & Governance Use Cases

### 4. User Access Pattern Analysis

Understand how your platform is being used across the organization over time.

```sql
-- Example: Login pattern analysis for security and governance
-- Use case: Identify dormant accounts, unusual access patterns, licensing optimization

SELECT 
    USER_NAME,
    CLIENT_IP,
    REPORTED_CLIENT_TYPE,
    DATE_TRUNC('month', EVENT_TIMESTAMP) AS month,
    COUNT(*) AS login_count,
    COUNT(DISTINCT DATE_TRUNC('day', EVENT_TIMESTAMP)) AS active_days,
    MIN(EVENT_TIMESTAMP) AS first_login,
    MAX(EVENT_TIMESTAMP) AS last_login,
    -- Flag potentially dormant users
    CASE 
        WHEN MAX(EVENT_TIMESTAMP) < DATEADD('day', -90, CURRENT_TIMESTAMP()) 
        THEN 'DORMANT - Review for deactivation'
        ELSE 'ACTIVE'
    END AS account_status
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND IS_SUCCESS = 'YES'
GROUP BY USER_NAME, CLIENT_IP, REPORTED_CLIENT_TYPE, DATE_TRUNC('month', EVENT_TIMESTAMP)
ORDER BY month DESC, login_count DESC;
```

### 5. Role and Privilege Evolution

Track how access controls have changed over time - critical for security reviews.

```sql
-- Example: Track role hierarchy changes over time
-- Use case: Security audits, access reviews, privilege creep detection

SELECT 
    GRANTEE_NAME,
    ROLE,
    GRANTED_BY,
    "_VALID_FROM" AS privilege_granted_at,
    "_VALID_TO" AS privilege_revoked_at,
    "_IS_CURRENT" AS currently_active,
    DATEDIFF('day', "_VALID_FROM", 
        CASE WHEN "_IS_CURRENT" THEN CURRENT_TIMESTAMP() ELSE "_VALID_TO"::TIMESTAMP END
    ) AS days_with_privilege
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.GRANTS_TO_ROLES_ARCHIVE
WHERE GRANTEE_NAME = 'SENSITIVE_DATA_ROLE'
ORDER BY "_VALID_FROM" DESC;
```

### 6. Data Access Transparency

See exactly who accessed what data and when - across years, not just the last 365 days.

```sql
-- Example: Data access audit for specific tables
-- Use case: Privacy compliance, data governance, breach investigation

SELECT 
    USER_NAME,
    ROLE_NAME,
    QUERY_TEXT,
    DATABASE_NAME,
    SCHEMA_NAME,
    START_TIME,
    ROWS_PRODUCED,
    BYTES_SCANNED / POWER(1024, 3) AS gb_scanned
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND QUERY_TEXT ILIKE '%CUSTOMER_PII%'  -- Sensitive table name
  AND START_TIME BETWEEN '2023-01-01' AND '2025-12-31'
ORDER BY START_TIME DESC;
```

---

## Compliance & Audit Use Cases

### 7. Regulatory Compliance Evidence

Provide immutable proof of data handling for regulatory audits (SOX, GDPR, HIPAA, etc.)

```sql
-- Example: Generate compliance evidence report
-- Use case: SOX audit, GDPR data access requests, HIPAA audit trails

SELECT 
    'DATA_ACCESS_AUDIT' AS report_type,
    USER_NAME,
    ROLE_NAME,
    DATABASE_NAME || '.' || SCHEMA_NAME AS data_location,
    QUERY_TYPE,
    START_TIME AS access_timestamp,
    EXECUTION_STATUS,
    ROWS_PRODUCED AS records_accessed,
    -- Archive metadata proves immutability
    "_LOADED_AT" AS archived_at,
    "_ROW_HASH" AS integrity_hash,
    "_SOURCE_SYSTEM" AS source
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND DATABASE_NAME IN ('PRODUCTION', 'CUSTOMER_DATA', 'FINANCIAL')
  AND START_TIME >= DATEADD('year', -7, CURRENT_TIMESTAMP())
ORDER BY START_TIME DESC;
```

### 8. Failed Login Security Audit

Investigate security incidents with complete historical context.

```sql
-- Example: Security incident investigation - failed login analysis
-- Use case: Breach investigation, security audit, threat detection

SELECT 
    EVENT_TIMESTAMP,
    USER_NAME,
    CLIENT_IP,
    REPORTED_CLIENT_TYPE,
    ERROR_CODE,
    ERROR_MESSAGE,
    -- Geographic analysis if available
    FIRST_AUTHENTICATION_FACTOR,
    SECOND_AUTHENTICATION_FACTOR,
    -- Count failed attempts in 24-hour window
    COUNT(*) OVER (
        PARTITION BY USER_NAME 
        ORDER BY EVENT_TIMESTAMP 
        RANGE BETWEEN INTERVAL '24 HOURS' PRECEDING AND CURRENT ROW
    ) AS failed_attempts_24h
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND IS_SUCCESS = 'NO'
ORDER BY EVENT_TIMESTAMP DESC;
```

### 9. Change Management Audit Trail

Prove when configuration changes were made and by whom.

```sql
-- Example: Database and schema change history
-- Use case: Change management audit, rollback investigation

SELECT 
    DATABASE_NAME,
    DATABASE_OWNER,
    CREATED AS originally_created,
    "_VALID_FROM" AS this_version_from,
    "_VALID_TO" AS this_version_to,
    "_IS_CURRENT" AS is_current_state,
    COMMENT,
    OPTIONS
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASES_ARCHIVE
WHERE DATABASE_NAME = 'PRODUCTION_DB'
ORDER BY "_VALID_FROM" DESC;
```

---

## Semantic Layer & AI Agent Applications

The Temporal Archive is designed to power **AI agents and semantic analysis** for automated insights:

### 10. Natural Language Querying

AI agents can query historical data using natural language:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    AI AGENT INTERACTION EXAMPLES                                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│   USER: "What was our warehouse spending trend over the last 3 years?"              │
│                                                                                     │
│   AGENT: Analyzes WAREHOUSE_METERING_HISTORY_ARCHIVE                                │
│          → Generates trend visualization                                            │
│          → Identifies seasonal patterns                                             │
│          → Recommends optimization opportunities                                    │
│                                                                                     │
│   ─────────────────────────────────────────────────────────────────────────────     │
│                                                                                     │
│   USER: "Who accessed the CUSTOMER_DATA schema in Q4 2024?"                         │
│                                                                                     │
│   AGENT: Queries QUERY_HISTORY_ARCHIVE                                              │
│          → Returns complete access list                                             │
│          → Groups by user and role                                                  │
│          → Flags unusual access patterns                                            │
│                                                                                     │
│   ─────────────────────────────────────────────────────────────────────────────     │
│                                                                                     │
│   USER: "Generate a SOX compliance report for the last fiscal year"                 │
│                                                                                     │
│   AGENT: Combines multiple ARCHIVE tables                                           │
│          → Generates formatted compliance report                                    │
│          → Includes immutability attestation                                        │
│          → Provides hash verification for audit                                     │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 11. Anomaly Detection & Alerting

Historical baselines enable automated anomaly detection:

```sql
-- Example: Detect anomalous query patterns using historical baselines
-- Use case: Security monitoring, cost spike detection

WITH monthly_baselines AS (
    SELECT 
        USER_NAME,
        DATE_TRUNC('month', START_TIME) AS month,
        COUNT(*) AS query_count,
        SUM(BYTES_SCANNED) AS total_bytes,
        AVG(COUNT(*)) OVER (PARTITION BY USER_NAME ORDER BY month ROWS BETWEEN 12 PRECEDING AND 1 PRECEDING) AS avg_query_count_12mo,
        STDDEV(COUNT(*)) OVER (PARTITION BY USER_NAME ORDER BY month ROWS BETWEEN 12 PRECEDING AND 1 PRECEDING) AS stddev_query_count_12mo
    FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
    WHERE "_IS_CURRENT" = TRUE
    GROUP BY USER_NAME, DATE_TRUNC('month', START_TIME)
)
SELECT 
    *,
    CASE 
        WHEN query_count > avg_query_count_12mo + (3 * stddev_query_count_12mo)
        THEN 'ANOMALY: Significantly higher than historical average'
        WHEN query_count < avg_query_count_12mo - (3 * stddev_query_count_12mo)
        THEN 'ANOMALY: Significantly lower than historical average'
        ELSE 'NORMAL'
    END AS anomaly_flag
FROM monthly_baselines
WHERE anomaly_flag != 'NORMAL'
ORDER BY month DESC;
```

---

## Summary: The Value Proposition

| Category | Without Temporal Archive | With Temporal Archive |
|----------|--------------------------|----------------------|
| **Data Retention** | 1 year (Snowflake limit) | 7+ years (configurable) |
| **Cost Analysis** | Limited trend visibility | Multi-year optimization insights |
| **Compliance** | Cannot prove historical access | Immutable WORM audit trail |
| **Security Audit** | Gaps in investigation capability | Complete forensic history |
| **AI/ML Ready** | Insufficient training data | Rich historical dataset |
| **Governance** | Point-in-time snapshots only | Full temporal evolution |

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
    "_VALID_TO"           VARCHAR(50)
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
    "_VALID_TO"             VARCHAR(50)
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

1. All tables MUST include the complete SCD column set (7 columns)
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
