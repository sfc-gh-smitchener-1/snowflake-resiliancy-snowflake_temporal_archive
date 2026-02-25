# Sample Analytical Queries

Ready-to-use SQL queries for the Temporal Archive. All queries filter on `"_IS_CURRENT" = TRUE` to return current records.

## Cost Optimization

### Warehouse Right-Sizing Analysis

Identify over-provisioned warehouses by analyzing historical utilization patterns.

```sql
-- Find warehouses consistently under-utilized
-- Potential savings: 20-40% reduction in compute costs

SELECT 
    WAREHOUSE_NAME,
    DATE_TRUNC('month', START_TIME) AS month,
    AVG(AVG_RUNNING) AS avg_concurrent_queries,
    AVG(AVG_QUEUED_LOAD) AS avg_queue_depth,
    SUM(CREDITS_USED) AS monthly_credits,
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

### Multi-Year Cost Attribution

Track which teams, users, or applications drive costs across years.

```sql
-- Cost attribution by user/role with quarter-over-quarter comparison

SELECT 
    USER_NAME,
    ROLE_NAME,
    DATE_TRUNC('quarter', START_TIME) AS quarter,
    COUNT(*) AS query_count,
    SUM(TOTAL_ELAPSED_TIME) / 1000 / 60 AS total_minutes,
    SUM(CREDITS_USED_CLOUD_SERVICES) AS cloud_credits,
    LAG(SUM(CREDITS_USED_CLOUD_SERVICES)) OVER (
        PARTITION BY USER_NAME ORDER BY DATE_TRUNC('quarter', START_TIME)
    ) AS prev_quarter_credits,
    ROUND(
        (SUM(CREDITS_USED_CLOUD_SERVICES) - LAG(SUM(CREDITS_USED_CLOUD_SERVICES)) OVER (
            PARTITION BY USER_NAME ORDER BY DATE_TRUNC('quarter', START_TIME)
        )) / NULLIF(LAG(SUM(CREDITS_USED_CLOUD_SERVICES)) OVER (
            PARTITION BY USER_NAME ORDER BY DATE_TRUNC('quarter', START_TIME)
        ), 0) * 100, 2
    ) AS qoq_change_pct
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
GROUP BY USER_NAME, ROLE_NAME, DATE_TRUNC('quarter', START_TIME)
ORDER BY quarter DESC, cloud_credits DESC;
```

### Storage Growth Forecasting

Predict future storage needs based on multi-year growth patterns.

```sql
-- Storage growth trend analysis for capacity planning

WITH storage_trend AS (
    SELECT 
        USAGE_DATE,
        AVERAGE_STAGE_BYTES / POWER(1024, 4) AS stage_tb,
        AVERAGE_DATABASE_BYTES / POWER(1024, 4) AS database_tb,
        AVERAGE_FAILSAFE_BYTES / POWER(1024, 4) AS failsafe_tb,
        (AVERAGE_STAGE_BYTES + AVERAGE_DATABASE_BYTES + AVERAGE_FAILSAFE_BYTES) 
            / POWER(1024, 4) AS total_tb
    FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.STORAGE_USAGE_ARCHIVE
    WHERE "_IS_CURRENT" = TRUE
)
SELECT 
    *,
    (total_tb - LAG(total_tb, 30) OVER (ORDER BY USAGE_DATE)) 
        / NULLIF(LAG(total_tb, 30) OVER (ORDER BY USAGE_DATE), 0) * 100 
        AS monthly_growth_pct
FROM storage_trend
ORDER BY USAGE_DATE DESC;
```

---

## Security & Governance

### User Access Pattern Analysis

Identify dormant accounts and unusual access patterns.

```sql
-- Login pattern analysis for security and governance

SELECT 
    USER_NAME,
    CLIENT_IP,
    REPORTED_CLIENT_TYPE,
    DATE_TRUNC('month', EVENT_TIMESTAMP) AS month,
    COUNT(*) AS login_count,
    COUNT(DISTINCT DATE_TRUNC('day', EVENT_TIMESTAMP)) AS active_days,
    MIN(EVENT_TIMESTAMP) AS first_login,
    MAX(EVENT_TIMESTAMP) AS last_login,
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

### Failed Login Security Audit

Investigate security incidents with complete historical context.

```sql
-- Security incident investigation - failed login analysis

SELECT 
    EVENT_TIMESTAMP,
    USER_NAME,
    CLIENT_IP,
    REPORTED_CLIENT_TYPE,
    ERROR_CODE,
    ERROR_MESSAGE,
    FIRST_AUTHENTICATION_FACTOR,
    SECOND_AUTHENTICATION_FACTOR,
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

### Role and Privilege Evolution

Track how access controls have changed over time.

```sql
-- Track role hierarchy changes over time for security audits

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

---

## Compliance & Audit

### Regulatory Compliance Evidence

Generate immutable proof of data handling for audits.

```sql
-- Compliance evidence report for SOX, GDPR, HIPAA

SELECT 
    'DATA_ACCESS_AUDIT' AS report_type,
    USER_NAME,
    ROLE_NAME,
    DATABASE_NAME || '.' || SCHEMA_NAME AS data_location,
    QUERY_TYPE,
    START_TIME AS access_timestamp,
    EXECUTION_STATUS,
    ROWS_PRODUCED AS records_accessed,
    "_LOADED_AT" AS archived_at,
    "_ROW_HASH" AS integrity_hash,
    "_SOURCE_SYSTEM" AS source
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND DATABASE_NAME IN ('PRODUCTION', 'CUSTOMER_DATA', 'FINANCIAL')
  AND START_TIME >= DATEADD('year', -7, CURRENT_TIMESTAMP())
ORDER BY START_TIME DESC;
```

### Data Access Transparency

See exactly who accessed what data and when.

```sql
-- Data access audit for specific sensitive tables

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
  AND QUERY_TEXT ILIKE '%CUSTOMER_PII%'
  AND START_TIME BETWEEN '2023-01-01' AND '2025-12-31'
ORDER BY START_TIME DESC;
```

### Change Management Audit Trail

Prove when configuration changes were made and by whom.

```sql
-- Database and schema change history

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

## Anomaly Detection

### Query Pattern Anomalies

Detect unusual query patterns using historical baselines.

```sql
-- Detect anomalous query patterns using 12-month baselines

WITH monthly_baselines AS (
    SELECT 
        USER_NAME,
        DATE_TRUNC('month', START_TIME) AS month,
        COUNT(*) AS query_count,
        SUM(BYTES_SCANNED) AS total_bytes,
        AVG(COUNT(*)) OVER (
            PARTITION BY USER_NAME 
            ORDER BY DATE_TRUNC('month', START_TIME) 
            ROWS BETWEEN 12 PRECEDING AND 1 PRECEDING
        ) AS avg_query_count_12mo,
        STDDEV(COUNT(*)) OVER (
            PARTITION BY USER_NAME 
            ORDER BY DATE_TRUNC('month', START_TIME) 
            ROWS BETWEEN 12 PRECEDING AND 1 PRECEDING
        ) AS stddev_query_count_12mo
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
WHERE month >= DATEADD('month', -6, CURRENT_DATE())
ORDER BY month DESC;
```

---

## Query Performance Analytics

### Long-Running Query Detection

Identify queries running longer than 5 minutes for performance investigation.

```sql
-- Find long-running queries (>5 minutes) with user/warehouse context

SELECT 
    QUERY_ID,
    USER_NAME,
    ROLE_NAME,
    WAREHOUSE_NAME,
    WAREHOUSE_SIZE,
    QUERY_TYPE,
    TOTAL_ELAPSED_TIME / 1000 / 60 AS duration_minutes,
    BYTES_SCANNED / POWER(1024, 3) AS gb_scanned,
    PARTITIONS_SCANNED,
    PARTITIONS_TOTAL,
    ROUND(PARTITIONS_SCANNED * 100.0 / NULLIF(PARTITIONS_TOTAL, 0), 2) AS partition_scan_pct,
    EXECUTION_STATUS,
    START_TIME
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND TOTAL_ELAPSED_TIME > 300000  -- 5 minutes in milliseconds
ORDER BY TOTAL_ELAPSED_TIME DESC
LIMIT 50;
```

### High Partition Scan Percentage (Clustering Candidates)

Find queries scanning >90% of partitions - candidates for table clustering.

```sql
-- Queries with poor partition pruning (clustering optimization candidates)

SELECT 
    QUERY_PARAMETERIZED_HASH,
    COUNT(*) AS execution_count,
    AVG(TOTAL_ELAPSED_TIME) / 1000 AS avg_duration_sec,
    AVG(PARTITIONS_SCANNED * 100.0 / NULLIF(PARTITIONS_TOTAL, 0)) AS avg_scan_pct,
    MAX(PARTITIONS_TOTAL) AS max_partitions,
    SUM(BYTES_SCANNED) / POWER(1024, 4) AS total_tb_scanned,
    LISTAGG(DISTINCT DATABASE_NAME || '.' || SCHEMA_NAME, ', ') AS databases_accessed
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND PARTITIONS_TOTAL > 100  -- Only tables with significant partitions
  AND PARTITIONS_SCANNED / NULLIF(PARTITIONS_TOTAL, 0) > 0.9  -- >90% scan
  AND START_TIME >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY QUERY_PARAMETERIZED_HASH
ORDER BY total_tb_scanned DESC
LIMIT 20;
```

### Memory Pressure Analysis (Spill Detection)

Identify queries with memory spill - candidates for warehouse upsizing.

```sql
-- Queries with remote spill (severe memory pressure)

SELECT 
    USER_NAME,
    WAREHOUSE_NAME,
    WAREHOUSE_SIZE,
    QUERY_TYPE,
    QUERY_ID,
    TOTAL_ELAPSED_TIME / 1000 AS duration_sec,
    BYTES_SPILLED_TO_LOCAL_STORAGE / POWER(1024, 3) AS local_spill_gb,
    BYTES_SPILLED_TO_REMOTE_STORAGE / POWER(1024, 3) AS remote_spill_gb,
    BYTES_SCANNED / POWER(1024, 3) AS gb_scanned,
    CASE 
        WHEN BYTES_SPILLED_TO_REMOTE_STORAGE > 0 THEN 'CRITICAL: Upsize warehouse'
        WHEN BYTES_SPILLED_TO_LOCAL_STORAGE > POWER(1024, 3) THEN 'WARNING: Consider upsizing'
        ELSE 'OK'
    END AS recommendation,
    START_TIME
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND (BYTES_SPILLED_TO_LOCAL_STORAGE > 0 OR BYTES_SPILLED_TO_REMOTE_STORAGE > 0)
ORDER BY BYTES_SPILLED_TO_REMOTE_STORAGE DESC, BYTES_SPILLED_TO_LOCAL_STORAGE DESC
LIMIT 50;
```

### Queue Time Analysis (Capacity Planning)

Detect warehouse capacity constraints via queue time patterns.

```sql
-- Queries with significant queue time (capacity constraints)

SELECT 
    WAREHOUSE_NAME,
    DATE_TRUNC('hour', START_TIME) AS hour,
    COUNT(*) AS query_count,
    AVG(QUEUED_OVERLOAD_TIME) / 1000 AS avg_queue_sec,
    MAX(QUEUED_OVERLOAD_TIME) / 1000 AS max_queue_sec,
    SUM(CASE WHEN QUEUED_OVERLOAD_TIME > 30000 THEN 1 ELSE 0 END) AS high_queue_count,
    ROUND(SUM(CASE WHEN QUEUED_OVERLOAD_TIME > 30000 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_queued,
    CASE 
        WHEN AVG(QUEUED_OVERLOAD_TIME) > 60000 THEN 'CRITICAL: Multi-cluster or upsize'
        WHEN AVG(QUEUED_OVERLOAD_TIME) > 30000 THEN 'WARNING: Consider scaling'
        ELSE 'OK'
    END AS recommendation
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY WAREHOUSE_NAME, DATE_TRUNC('hour', START_TIME)
HAVING AVG(QUEUED_OVERLOAD_TIME) > 5000
ORDER BY avg_queue_sec DESC;
```

### User-Table Access Patterns

Track which users accessed which tables using ACCESS_HISTORY.

```sql
-- Who accessed which tables (requires LATERAL FLATTEN for ACCESS_HISTORY arrays)

SELECT 
    qh.USER_NAME,
    qh.ROLE_NAME,
    f.VALUE:objectName::STRING AS table_accessed,
    f.VALUE:objectDomain::STRING AS object_type,
    COUNT(*) AS access_count,
    MIN(qh.START_TIME) AS first_access,
    MAX(qh.START_TIME) AS last_access,
    SUM(qh.BYTES_SCANNED) / POWER(1024, 3) AS total_gb_scanned
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE qh
JOIN TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ACCESS_HISTORY_ARCHIVE ah 
    ON qh.QUERY_ID = ah.QUERY_ID AND ah."_IS_CURRENT" = TRUE
, LATERAL FLATTEN(INPUT => ah.DIRECT_OBJECTS_ACCESSED) f
WHERE qh."_IS_CURRENT" = TRUE
  AND qh.START_TIME >= DATEADD('day', -30, CURRENT_DATE())
  AND f.VALUE:objectDomain::STRING = 'Table'
GROUP BY qh.USER_NAME, qh.ROLE_NAME, f.VALUE:objectName::STRING, f.VALUE:objectDomain::STRING
ORDER BY access_count DESC
LIMIT 100;
```

### Data Lineage - Tables Modified by Queries

Track which queries modified which tables for audit and lineage.

```sql
-- Data lineage: what tables were modified and by whom

SELECT 
    qh.USER_NAME,
    qh.ROLE_NAME,
    qh.QUERY_TYPE,
    f.VALUE:objectName::STRING AS table_modified,
    f.VALUE:columns AS columns_modified,
    COUNT(*) AS modification_count,
    SUM(qh.ROWS_INSERTED) AS total_rows_inserted,
    SUM(qh.ROWS_UPDATED) AS total_rows_updated,
    SUM(qh.ROWS_DELETED) AS total_rows_deleted,
    MIN(qh.START_TIME) AS first_modification,
    MAX(qh.START_TIME) AS last_modification
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE qh
JOIN TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ACCESS_HISTORY_ARCHIVE ah 
    ON qh.QUERY_ID = ah.QUERY_ID AND ah."_IS_CURRENT" = TRUE
, LATERAL FLATTEN(INPUT => ah.OBJECTS_MODIFIED) f
WHERE qh."_IS_CURRENT" = TRUE
  AND qh.START_TIME >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY qh.USER_NAME, qh.ROLE_NAME, qh.QUERY_TYPE, 
         f.VALUE:objectName::STRING, f.VALUE:columns
ORDER BY modification_count DESC;
```

### Cache Efficiency Analysis

Analyze cache hit rates to identify cold query patterns.

```sql
-- Cache efficiency by warehouse and time of day

SELECT 
    WAREHOUSE_NAME,
    EXTRACT(HOUR FROM START_TIME) AS hour_of_day,
    COUNT(*) AS query_count,
    AVG(PERCENTAGE_SCANNED_FROM_CACHE) * 100 AS avg_cache_hit_pct,
    SUM(CASE WHEN PERCENTAGE_SCANNED_FROM_CACHE < 0.2 THEN 1 ELSE 0 END) AS low_cache_queries,
    SUM(BYTES_SCANNED) / POWER(1024, 4) AS total_tb_scanned,
    SUM(BYTES_SCANNED * (1 - PERCENTAGE_SCANNED_FROM_CACHE)) / POWER(1024, 4) AS tb_from_storage
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATEADD('day', -7, CURRENT_DATE())
  AND BYTES_SCANNED > 0
GROUP BY WAREHOUSE_NAME, EXTRACT(HOUR FROM START_TIME)
ORDER BY WAREHOUSE_NAME, hour_of_day;
```

### Repeated Expensive Query Patterns

Group similar queries by parameterized hash to find optimization opportunities.

```sql
-- Most expensive repeated query patterns

SELECT 
    QUERY_PARAMETERIZED_HASH,
    COUNT(*) AS execution_count,
    COUNT(DISTINCT USER_NAME) AS unique_users,
    AVG(TOTAL_ELAPSED_TIME) / 1000 AS avg_duration_sec,
    SUM(TOTAL_ELAPSED_TIME) / 1000 / 60 AS total_duration_min,
    AVG(BYTES_SCANNED) / POWER(1024, 3) AS avg_gb_scanned,
    SUM(BYTES_SCANNED) / POWER(1024, 4) AS total_tb_scanned,
    SUM(CREDITS_USED_CLOUD_SERVICES) AS total_cloud_credits,
    AVG(PARTITIONS_SCANNED * 100.0 / NULLIF(PARTITIONS_TOTAL, 0)) AS avg_partition_scan_pct,
    MAX(QUERY_TEXT) AS sample_query
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATEADD('day', -30, CURRENT_DATE())
  AND EXECUTION_STATUS = 'SUCCESS'
GROUP BY QUERY_PARAMETERIZED_HASH
HAVING COUNT(*) >= 10  -- Only patterns executed 10+ times
ORDER BY total_tb_scanned DESC
LIMIT 20;
```

### Policy-Protected Data Access Audit

Track queries that accessed data protected by masking or row access policies.

```sql
-- Queries that accessed policy-protected data

SELECT 
    qh.USER_NAME,
    qh.ROLE_NAME,
    qh.QUERY_TYPE,
    p.VALUE:policyName::STRING AS policy_name,
    p.VALUE:policyKind::STRING AS policy_type,
    COUNT(*) AS access_count,
    MIN(qh.START_TIME) AS first_access,
    MAX(qh.START_TIME) AS last_access
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE qh
JOIN TEMPORAL_ARCHIVE.ACCOUNT_USAGE.ACCESS_HISTORY_ARCHIVE ah 
    ON qh.QUERY_ID = ah.QUERY_ID AND ah."_IS_CURRENT" = TRUE
, LATERAL FLATTEN(INPUT => ah.POLICIES_REFERENCED) p
WHERE qh."_IS_CURRENT" = TRUE
  AND qh.START_TIME >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY qh.USER_NAME, qh.ROLE_NAME, qh.QUERY_TYPE,
         p.VALUE:policyName::STRING, p.VALUE:policyKind::STRING
ORDER BY access_count DESC;
```

### Performance Alert Dashboard Query

Comprehensive alert query combining all performance thresholds.

```sql
-- Performance alerts dashboard - queries needing attention

SELECT 
    QUERY_ID,
    USER_NAME,
    WAREHOUSE_NAME,
    START_TIME,
    TOTAL_ELAPSED_TIME / 1000 / 60 AS duration_min,
    CASE 
        WHEN TOTAL_ELAPSED_TIME > 300000 THEN 'LONG_RUNNING'
        ELSE NULL 
    END AS long_running_alert,
    CASE 
        WHEN PARTITIONS_SCANNED / NULLIF(PARTITIONS_TOTAL, 0) > 0.9 THEN 'HIGH_SCAN_PCT'
        ELSE NULL 
    END AS partition_alert,
    CASE 
        WHEN BYTES_SPILLED_TO_REMOTE_STORAGE > 0 THEN 'REMOTE_SPILL'
        WHEN BYTES_SPILLED_TO_LOCAL_STORAGE > POWER(1024, 3) THEN 'LOCAL_SPILL'
        ELSE NULL 
    END AS spill_alert,
    CASE 
        WHEN QUEUED_OVERLOAD_TIME > 30000 THEN 'HIGH_QUEUE'
        ELSE NULL 
    END AS queue_alert,
    CASE 
        WHEN PERCENTAGE_SCANNED_FROM_CACHE < 0.1 AND BYTES_SCANNED > POWER(1024, 3) THEN 'CACHE_MISS'
        ELSE NULL 
    END AS cache_alert
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATEADD('day', -1, CURRENT_DATE())
  AND (
    TOTAL_ELAPSED_TIME > 300000
    OR PARTITIONS_SCANNED / NULLIF(PARTITIONS_TOTAL, 0) > 0.9
    OR BYTES_SPILLED_TO_REMOTE_STORAGE > 0
    OR QUEUED_OVERLOAD_TIME > 30000
  )
ORDER BY START_TIME DESC;
```

---

## BC/DR Analytics

### Hot Tables (High Churn)

Identify tables with high data churn for DR prioritization.

```sql
-- Find hot tables with highest data churn (failsafe indicates recent changes)

SELECT 
    TABLE_CATALOG AS database_name,
    TABLE_SCHEMA AS schema_name,
    TABLE_NAME,
    ACTIVE_BYTES / POWER(1024, 3) AS active_gb,
    TIME_TRAVEL_BYTES / POWER(1024, 3) AS time_travel_gb,
    FAILSAFE_BYTES / POWER(1024, 3) AS failsafe_gb,
    ROUND(FAILSAFE_BYTES * 100.0 / NULLIF(ACTIVE_BYTES, 0), 2) AS churn_pct,
    CASE 
        WHEN FAILSAFE_BYTES > ACTIVE_BYTES * 0.5 THEN 'HIGH CHURN'
        WHEN FAILSAFE_BYTES > ACTIVE_BYTES * 0.1 THEN 'MEDIUM CHURN'
        ELSE 'LOW CHURN'
    END AS churn_category
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND ACTIVE_BYTES > 0
ORDER BY FAILSAFE_BYTES DESC
LIMIT 50;
```

### Storage Inventory for DR Planning

Complete storage breakdown for disaster recovery planning.

```sql
-- Storage inventory summary

SELECT 
    DATE_TRUNC('month', USAGE_DATE) AS month,
    SUM(AVERAGE_DATABASE_BYTES) / POWER(1024, 4) AS database_tb,
    SUM(AVERAGE_STAGE_BYTES) / POWER(1024, 4) AS stage_tb,
    SUM(AVERAGE_FAILSAFE_BYTES) / POWER(1024, 4) AS failsafe_tb,
    SUM(AVERAGE_DATABASE_BYTES + AVERAGE_STAGE_BYTES + AVERAGE_FAILSAFE_BYTES) 
        / POWER(1024, 4) AS total_tb
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.STORAGE_USAGE_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
GROUP BY DATE_TRUNC('month', USAGE_DATE)
ORDER BY month DESC;
```

---

## SCD Type 2 Queries

### Point-in-Time Query

Query the state of data at a specific point in time.

```sql
-- What was the user list on January 1, 2025?

SELECT *
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE "_VALID_FROM" <= '2025-01-01 00:00:00'
  AND "_VALID_TO" > '2025-01-01 00:00:00';
```

### Change History for a Record

Track all changes to a specific record.

```sql
-- Complete change history for a specific user

SELECT 
    NAME,
    LOGIN_NAME,
    EMAIL,
    DEFAULT_ROLE,
    DISABLED,
    "_VALID_FROM",
    "_VALID_TO",
    "_IS_CURRENT",
    "_LOADED_AT"
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE NAME = 'JOHN_DOE'
ORDER BY "_VALID_FROM" DESC;
```

### Records Changed in a Time Window

Find all records that changed during a specific period.

```sql
-- What changed in the last 7 days?

SELECT 
    "_SOURCE_TABLE" AS table_name,
    COUNT(*) AS changes
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE "_VALID_FROM" >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY "_SOURCE_TABLE"
ORDER BY changes DESC;
```

---

## Semantic View Queries

These queries leverage the 10 semantic views deployed in the `TEMPORAL_ARCHIVE.SEMANTIC` schema. Use them with Cortex Analyst for natural language analytics, or run them directly.

### WAREHOUSE_COST_ANALYTICS

#### Top Warehouses by Credit Consumption

```sql
-- Which warehouses consumed the most credits last month?

SELECT 
    WAREHOUSE_NAME,
    ROUND(SUM(CREDITS_USED), 2) AS total_credits,
    ROUND(SUM(CREDITS_USED_COMPUTE), 2) AS compute_credits,
    ROUND(SUM(CREDITS_USED_CLOUD_SERVICES), 2) AS cloud_credits,
    COUNT(*) AS metering_periods
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE()))
  AND START_TIME < DATE_TRUNC('month', CURRENT_DATE())
GROUP BY WAREHOUSE_NAME
ORDER BY total_credits DESC;
```

#### Top Credit Consumers by User and Role

```sql
-- Who are the top credit consumers by user and role?

SELECT 
    USER_NAME,
    ROLE_NAME,
    WAREHOUSE_NAME,
    COUNT(*) AS query_count,
    ROUND(SUM(TOTAL_ELAPSED_TIME) / 1000 / 60, 2) AS total_minutes,
    ROUND(SUM(CREDITS_USED_CLOUD_SERVICES), 4) AS cloud_credits
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY USER_NAME, ROLE_NAME, WAREHOUSE_NAME
ORDER BY cloud_credits DESC
LIMIT 25;
```

### SERVERLESS_COST_ANALYTICS

#### Dynamic Table Refresh Costs

```sql
-- What are my dynamic table costs and refresh patterns?

SELECT 
    NAME AS dt_name,
    DATABASE_NAME,
    SCHEMA_NAME,
    STATE,
    COUNT(*) AS refresh_count,
    SUM(CASE WHEN STATE = 'SUCCEEDED' THEN 1 ELSE 0 END) AS successes,
    SUM(CASE WHEN STATE IN ('FAILED', 'UPSTREAM_FAILED') THEN 1 ELSE 0 END) AS failures,
    AVG(TARGET_LAG_SEC) AS avg_target_lag_sec
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DYNAMIC_TABLE_REFRESH_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND REFRESH_START_TIME >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY NAME, DATABASE_NAME, SCHEMA_NAME, STATE
ORDER BY refresh_count DESC;
```

#### Serverless Task Credit Consumption

```sql
-- Which serverless tasks are consuming the most credits?

SELECT 
    TASK_NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    ROUND(SUM(CREDITS_USED), 4) AS total_credits,
    COUNT(*) AS execution_count,
    ROUND(AVG(CREDITS_USED), 6) AS avg_credits_per_run
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY TASK_NAME, DATABASE_NAME, SCHEMA_NAME
ORDER BY total_credits DESC
LIMIT 20;
```

### COST_ANALYTICS

#### Daily Cost Breakdown by Service Type

```sql
-- What's my daily cost breakdown by service type?

SELECT 
    USAGE_DATE,
    SERVICE_TYPE,
    ROUND(SUM(CREDITS_USED), 2) AS total_credits,
    ROUND(SUM(CREDITS_USED_COMPUTE), 2) AS compute_credits,
    ROUND(SUM(CREDITS_USED_CLOUD_SERVICES), 2) AS cloud_credits,
    ROUND(SUM(CREDITS_BILLED), 2) AS billed_credits
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.METERING_DAILY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND USAGE_DATE >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY USAGE_DATE, SERVICE_TYPE
ORDER BY USAGE_DATE DESC, total_credits DESC;
```

### SECURITY_ANALYTICS

#### Failed Login Patterns (Brute Force Detection)

```sql
-- Detect potential brute force attacks: multiple failed logins from same IP

SELECT 
    CLIENT_IP,
    USER_NAME,
    REPORTED_CLIENT_TYPE,
    COUNT(*) AS failed_attempts,
    MIN(EVENT_TIMESTAMP) AS first_attempt,
    MAX(EVENT_TIMESTAMP) AS last_attempt,
    DATEDIFF('minute', MIN(EVENT_TIMESTAMP), MAX(EVENT_TIMESTAMP)) AS window_minutes
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND IS_SUCCESS = 'NO'
  AND EVENT_TIMESTAMP >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY CLIENT_IP, USER_NAME, REPORTED_CLIENT_TYPE
HAVING COUNT(*) >= 5
ORDER BY failed_attempts DESC;
```

#### MFA Adoption Report

```sql
-- Which users don't have MFA enabled?

SELECT 
    NAME AS user_name,
    EMAIL,
    DEFAULT_ROLE,
    HAS_MFA,
    LAST_SUCCESS_LOGIN,
    DISABLED,
    DATEDIFF('day', LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) AS days_since_login
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND (HAS_MFA = FALSE OR HAS_MFA IS NULL)
  AND DISABLED = 'false'
ORDER BY LAST_SUCCESS_LOGIN DESC;
```

### STORAGE_ANALYTICS

#### Largest Tables by Storage

```sql
-- What are my largest tables by storage?

SELECT 
    TABLE_CATALOG AS database_name,
    TABLE_SCHEMA AS schema_name,
    TABLE_NAME,
    ROUND(ACTIVE_BYTES / POWER(1024, 3), 2) AS active_gb,
    ROUND(TIME_TRAVEL_BYTES / POWER(1024, 3), 2) AS time_travel_gb,
    ROUND(FAILSAFE_BYTES / POWER(1024, 3), 2) AS failsafe_gb,
    ROUND((ACTIVE_BYTES + TIME_TRAVEL_BYTES + FAILSAFE_BYTES) / POWER(1024, 3), 2) AS total_gb
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND ACTIVE_BYTES > 0
ORDER BY ACTIVE_BYTES DESC
LIMIT 25;
```

#### Storage Growth Trend by Database

```sql
-- Show me storage growth trend by database for the last 90 days

SELECT 
    DATABASE_NAME,
    USAGE_DATE,
    ROUND(AVERAGE_DATABASE_BYTES / POWER(1024, 3), 2) AS database_gb,
    ROUND(AVERAGE_FAILSAFE_BYTES / POWER(1024, 3), 2) AS failsafe_gb
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND USAGE_DATE >= DATEADD('day', -90, CURRENT_DATE())
ORDER BY DATABASE_NAME, USAGE_DATE DESC;
```

### GOVERNANCE_ANALYTICS

#### Users with ACCOUNTADMIN Role

```sql
-- List all users with ACCOUNTADMIN role

SELECT 
    g.GRANTEE_NAME AS user_name,
    g.ROLE AS granted_role,
    g.GRANTED_BY,
    g.CREATED_ON AS grant_date,
    u.EMAIL,
    u.HAS_MFA,
    u.LAST_SUCCESS_LOGIN,
    u.DISABLED
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.GRANTS_TO_USERS_ARCHIVE g
LEFT JOIN TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE u
    ON g.GRANTEE_NAME = u.NAME AND u."_IS_CURRENT" = TRUE
WHERE g."_IS_CURRENT" = TRUE
  AND g.ROLE = 'ACCOUNTADMIN'
ORDER BY g.CREATED_ON;
```

#### Dormant User Identification

```sql
-- Find dormant users (no login in 90+ days) for deactivation review

SELECT 
    NAME AS user_name,
    EMAIL,
    DEFAULT_ROLE,
    LAST_SUCCESS_LOGIN,
    DATEDIFF('day', LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) AS days_inactive,
    DISABLED,
    HAS_MFA
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND DISABLED = 'false'
  AND LAST_SUCCESS_LOGIN < DATEADD('day', -90, CURRENT_TIMESTAMP())
ORDER BY days_inactive DESC;
```

### TASK_ANALYTICS

#### Task Failure Analysis

```sql
-- Which tasks are failing most frequently?

SELECT 
    NAME AS task_name,
    DATABASE_NAME,
    SCHEMA_NAME,
    STATE,
    COUNT(*) AS run_count,
    SUM(CASE WHEN STATE = 'FAILED' THEN 1 ELSE 0 END) AS failure_count,
    ROUND(SUM(CASE WHEN STATE = 'FAILED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS failure_pct,
    MAX(ERROR_MESSAGE) AS latest_error
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TASK_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND SCHEDULED_TIME >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY NAME, DATABASE_NAME, SCHEMA_NAME, STATE
HAVING SUM(CASE WHEN STATE = 'FAILED' THEN 1 ELSE 0 END) > 0
ORDER BY failure_count DESC;
```

#### Task Execution Timeline

```sql
-- Show task execution patterns for the last 24 hours

SELECT 
    NAME AS task_name,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    DATEDIFF('second', QUERY_START_TIME, COMPLETED_TIME) AS duration_seconds,
    ATTEMPT_NUMBER,
    ERROR_MESSAGE
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TASK_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND SCHEDULED_TIME >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
ORDER BY SCHEDULED_TIME DESC;
```

### BCDR_ANALYTICS

#### Hot Tables (High Data Churn for DR Prioritization)

```sql
-- What are my hot tables with highest data churn?

SELECT 
    TABLE_CATALOG AS database_name,
    TABLE_SCHEMA AS schema_name,
    TABLE_NAME,
    ROUND(ACTIVE_BYTES / POWER(1024, 3), 2) AS active_gb,
    ROUND(FAILSAFE_BYTES / POWER(1024, 3), 2) AS failsafe_gb,
    ROUND(FAILSAFE_BYTES * 100.0 / NULLIF(ACTIVE_BYTES, 0), 2) AS churn_pct,
    CASE 
        WHEN FAILSAFE_BYTES > ACTIVE_BYTES * 0.5 THEN 'HIGH CHURN - Priority DR'
        WHEN FAILSAFE_BYTES > ACTIVE_BYTES * 0.1 THEN 'MEDIUM CHURN'
        ELSE 'LOW CHURN'
    END AS dr_priority
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND ACTIVE_BYTES > 0
ORDER BY FAILSAFE_BYTES DESC
LIMIT 30;
```

#### Replication RPO Monitoring

```sql
-- What's my RPO based on replication schedules?

SELECT 
    DATABASE_NAME,
    START_TIME,
    END_TIME,
    DATEDIFF('minute', START_TIME, END_TIME) AS replication_minutes,
    ROUND(CREDITS_USED, 4) AS credits,
    ROUND(BYTES_TRANSFERRED / POWER(1024, 3), 2) AS gb_transferred
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.DATABASE_REPLICATION_USAGE_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATEADD('day', -7, CURRENT_DATE())
ORDER BY START_TIME DESC;
```

### QUERY_PERFORMANCE_ANALYTICS

#### Long-Running Queries with Table Access

```sql
-- Show me long-running queries over 5 minutes with what they accessed

SELECT 
    qh.QUERY_ID,
    qh.USER_NAME,
    qh.WAREHOUSE_NAME,
    qh.WAREHOUSE_SIZE,
    ROUND(qh.TOTAL_ELAPSED_TIME / 1000 / 60, 2) AS duration_minutes,
    ROUND(qh.BYTES_SCANNED / POWER(1024, 3), 2) AS gb_scanned,
    qh.EXECUTION_STATUS,
    qh.START_TIME
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE qh
WHERE qh."_IS_CURRENT" = TRUE
  AND qh.TOTAL_ELAPSED_TIME > 300000
  AND qh.START_TIME >= DATEADD('day', -7, CURRENT_DATE())
ORDER BY qh.TOTAL_ELAPSED_TIME DESC
LIMIT 20;
```

#### Queries with Remote Spillage (Memory Pressure)

```sql
-- Find queries with remote spillage indicating memory pressure

SELECT 
    USER_NAME,
    WAREHOUSE_NAME,
    WAREHOUSE_SIZE,
    QUERY_ID,
    ROUND(TOTAL_ELAPSED_TIME / 1000, 2) AS duration_sec,
    ROUND(BYTES_SPILLED_TO_REMOTE_STORAGE / POWER(1024, 3), 2) AS remote_spill_gb,
    ROUND(BYTES_SPILLED_TO_LOCAL_STORAGE / POWER(1024, 3), 2) AS local_spill_gb,
    START_TIME
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND BYTES_SPILLED_TO_REMOTE_STORAGE > 0
  AND START_TIME >= DATEADD('day', -7, CURRENT_DATE())
ORDER BY BYTES_SPILLED_TO_REMOTE_STORAGE DESC
LIMIT 20;
```

---

## Pipeline Monitoring

Queries for monitoring the Temporal Archive pipeline itself — load status, watermark tracking, and registry health.

### Load Log Analysis

```sql
-- Recent load history with status breakdown

SELECT 
    SOURCE_SCHEMA,
    SOURCE_VIEW,
    STATUS,
    ROWS_INSERTED,
    ROWS_UPDATED,
    DURATION_SECONDS,
    LOAD_TIMESTAMP
FROM TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG
ORDER BY LOAD_TIMESTAMP DESC
LIMIT 50;
```

### Load Summary by Run

```sql
-- Aggregate load metrics per run (grouped by approximate load time)

SELECT 
    DATE_TRUNC('hour', LOAD_TIMESTAMP) AS run_hour,
    COUNT(*) AS views_processed,
    SUM(CASE WHEN STATUS = 'SUCCESS' THEN 1 ELSE 0 END) AS successes,
    SUM(CASE WHEN STATUS != 'SUCCESS' THEN 1 ELSE 0 END) AS failures,
    SUM(ROWS_INSERTED) AS total_inserted,
    SUM(ROWS_UPDATED) AS total_updated,
    ROUND(SUM(DURATION_SECONDS), 0) AS total_duration_sec,
    ROUND(AVG(DURATION_SECONDS), 2) AS avg_duration_sec
FROM TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG
GROUP BY DATE_TRUNC('hour', LOAD_TIMESTAMP)
ORDER BY run_hour DESC
LIMIT 20;
```

### Watermark State Status

```sql
-- Current watermark positions for APPEND_ONLY views

SELECT 
    ws.SOURCE_SCHEMA,
    ws.SOURCE_VIEW,
    ws.LAST_WATERMARK,
    ws.UPDATED_AT,
    vr.LOAD_STRATEGY,
    vr.WATERMARK_COLUMN,
    vr.IS_ACTIVE
FROM TEMPORAL_ARCHIVE.ARCHIVE.WATERMARK_STATE ws
JOIN TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY vr
    ON ws.SOURCE_SCHEMA = vr.SOURCE_SCHEMA 
    AND ws.SOURCE_VIEW = vr.SOURCE_VIEW
ORDER BY ws.UPDATED_AT DESC;
```

### View Registry Health

```sql
-- View registry summary by strategy and status

SELECT 
    LOAD_STRATEGY,
    IS_ACTIVE,
    COUNT(*) AS view_count,
    LISTAGG(SOURCE_SCHEMA || '.' || SOURCE_VIEW, ', ') 
        WITHIN GROUP (ORDER BY SOURCE_SCHEMA, SOURCE_VIEW) AS views
FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY
GROUP BY LOAD_STRATEGY, IS_ACTIVE
ORDER BY IS_ACTIVE DESC, LOAD_STRATEGY;
```

### Failed Loads Investigation

```sql
-- Investigate recent load failures with error details

SELECT 
    SOURCE_SCHEMA,
    SOURCE_VIEW,
    STATUS,
    ERROR_MESSAGE,
    LOAD_TIMESTAMP,
    DURATION_SECONDS
FROM TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG
WHERE STATUS != 'SUCCESS'
  AND LOAD_TIMESTAMP >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY LOAD_TIMESTAMP DESC;
```

### Deactivated Views Summary

```sql
-- List all deactivated views and the reason

SELECT 
    SOURCE_SCHEMA,
    SOURCE_VIEW,
    LOAD_STRATEGY,
    WATERMARK_COLUMN,
    IS_ACTIVE
FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY
WHERE IS_ACTIVE = FALSE
ORDER BY SOURCE_SCHEMA, SOURCE_VIEW;
-- 26 views: ORGANIZATION_USAGE (12 remaining), DATA_SHARING_USAGE (3), READER_ACCOUNT_USAGE (5), non-existent/secure ACCOUNT_USAGE (6)
-- 9 ORGANIZATION_USAGE views activated (ACCOUNTS, CONTRACT_ITEMS, DATA_TRANSFER_HISTORY, etc.)
```

### ORGANIZATION_ANALYTICS

> **Note**: Organization views require ORGADMIN role. These queries will return data only if your account has ORGADMIN access and org views have been activated in VIEW_REGISTRY.

#### Remaining Contract Balance

```sql
-- What is our remaining contract balance?

SELECT 
    CONTRACT_NUMBER,
    CURRENCY,
    ROUND(SUM(FREE_USAGE_BALANCE + CAPACITY_BALANCE + ON_DEMAND_CONSUMPTION_BALANCE + ROLLOVER_BALANCE), 2) AS TOTAL_REMAINING_BALANCE,
    DATE
FROM TEMPORAL_ARCHIVE.ORGANIZATION_USAGE.REMAINING_BALANCE_DAILY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND DATE >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY CONTRACT_NUMBER, CURRENCY, DATE
ORDER BY DATE DESC
LIMIT 30;
```

#### Org-Wide Warehouse Credit Consumption by Account

```sql
-- Show org-wide warehouse credit consumption by account

SELECT 
    ACCOUNT_NAME,
    WAREHOUSE_NAME,
    ROUND(SUM(CREDITS_USED), 2) AS total_credits,
    ROUND(SUM(CREDITS_USED_COMPUTE), 2) AS compute_credits,
    ROUND(SUM(CREDITS_USED_CLOUD_SERVICES), 2) AS cloud_credits
FROM TEMPORAL_ARCHIVE.ORGANIZATION_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY ACCOUNT_NAME, WAREHOUSE_NAME
ORDER BY total_credits DESC
LIMIT 25;
```

#### Org-Wide Storage by Account

```sql
-- What is storage usage across all accounts in the organization?

SELECT 
    ACCOUNT_NAME,
    ROUND(AVG(STORAGE_BYTES) / POWER(1024, 4), 2) AS avg_storage_tb,
    ROUND(AVG(STAGE_BYTES) / POWER(1024, 4), 2) AS avg_stage_tb,
    ROUND(AVG(FAILSAFE_BYTES) / POWER(1024, 4), 2) AS avg_failsafe_tb
FROM TEMPORAL_ARCHIVE.ORGANIZATION_USAGE.STORAGE_DAILY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND USAGE_DATE >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY ACCOUNT_NAME
ORDER BY avg_storage_tb DESC;
```
