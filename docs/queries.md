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
