# SCD Type 2 Implementation

Detailed documentation of the Slowly Changing Dimension Type 2 implementation used in the Temporal Archive.

## What is SCD Type 2?

SCD Type 2 preserves complete history by creating a new row for each change, with validity timestamps tracking when each version was active.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         SCD TYPE 2 RECORD LIFECYCLE                              │
└─────────────────────────────────────────────────────────────────────────────────┘

Day 1: User JOHN created with role ANALYST
┌─────────────────────────────────────────────────────────────────────────────────┐
│ _ARCHIVE_ID │ NAME │ ROLE    │ _IS_CURRENT │ _VALID_FROM      │ _VALID_TO       │
│ 1           │ JOHN │ ANALYST │ TRUE        │ 2025-01-01 06:00 │ 9999-12-31      │
└─────────────────────────────────────────────────────────────────────────────────┘

Day 30: User JOHN promoted to SENIOR_ANALYST
┌────────────────────────────────────────────────────────────────────────────────-─┐
│ _ARCHIVE_ID │ NAME │ ROLE           │ _IS_CURRENT │ _VALID_FROM      │ _VALID_TO │
│ 1           │ JOHN │ ANALYST        │ FALSE       │ 2025-01-01 06:00 │ 2025-01-30│
│ 2           │ JOHN │ SENIOR_ANALYST │ TRUE        │ 2025-01-30 06:00 │ 9999-12-31│
└───────────────────────────────────────────────────────────────────────────────-──┘

Day 90: User JOHN promoted to MANAGER
┌────────────────────────────────────────────────────────────────────────────────-─┐
│ _ARCHIVE_ID │ NAME │ ROLE           │ _IS_CURRENT │ _VALID_FROM      │ _VALID_TO │
│ 1           │ JOHN │ ANALYST        │ FALSE       │ 2025-01-01 06:00 │ 2025-01-30│
│ 2           │ JOHN │ SENIOR_ANALYST │ FALSE       │ 2025-01-30 06:00 │ 2025-04-01│
│ 3           │ JOHN │ MANAGER        │ TRUE        │ 2025-04-01 06:00 │ 9999-12-31│
└────────────────────────────────────────────────────────────────────────────────-─┘
```

## SCD Columns

Every archive table includes these standard columns, positioned **first** in the table definition (before source columns). This SCD-first layout enables `INSERT ... SELECT` without explicit column lists, since `ALTER TABLE ADD COLUMN` (from schema evolution) always appends to the end — which is the correct position for new source columns.

| Column | Type | Purpose |
|--------|------|---------|
| `_ARCHIVE_ID` | NUMBER AUTOINCREMENT | Surrogate primary key |
| `_ROW_HASH` | VARCHAR(64) | SHA-256 hash for change detection |
| `_LOADED_AT` | TIMESTAMP_NTZ | When this version was archived |
| `_SOURCE_SYSTEM` | VARCHAR(100) | Source system (e.g., SNOWFLAKE_ACCOUNT_USAGE) |
| `_SOURCE_TABLE` | VARCHAR(100) | Source view name |
| `_IS_CURRENT` | BOOLEAN | TRUE if this is the current version |
| `_VALID_FROM` | TIMESTAMP_NTZ | When this version became effective |
| `_VALID_TO` | TIMESTAMP_NTZ | When this version ended (9999-12-31 if current) |

## Change Detection Algorithm

### Hash-Based Detection

Instead of comparing individual columns, we use SHA-256 hashing:

```sql
SHA2(TO_JSON(OBJECT_CONSTRUCT(*)), 256)
```

This approach:
- Works with any table structure (no PK mapping needed)
- Detects changes to any column automatically
- Is deterministic and reproducible
- Handles NULL values correctly

### Load Process (3-Strategy)

The load procedure selects a strategy per view from VIEW_REGISTRY:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        3-STRATEGY SCD LOAD ALGORITHM                            │
└─────────────────────────────────────────────────────────────────────────────────┘

                    ┌──────────────────────┐
                    │   Source View        │
                    │ (ACCOUNT_USAGE.X)    │
                    └──────────┬───────────┘
                               │
                    ┌──────────┴───────────┐
                    │  Lookup LOAD_STRATEGY│
                    │  in VIEW_REGISTRY    │
                    └──────────┬───────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                      │
         ▼                     ▼                      ▼
┌──────────────────┐ ┌──────────────────┐  ┌──────────────────┐
│  APPEND_ONLY     │ │ SOFT_DELETE      │  │  FULL_COMPARE    │
│  (57 views)      │ │ _MUTABLE         │  │  (10 views)      │
│                  │ │ (40 views)       │  │                  │
│ 1. Read watermark│ │ 1. Create temp   │  │ 1. Compute hash  │
│    from state    │ │    table with    │  │    for all source │
│ 2. Query rows    │ │    source hashes │  │ 2. Compare with  │
│    after mark    │ │ 2. UPDATE expired│  │    archive hashes│
│ 3. INSERT only   │ │ 3. INSERT new    │  │ 3. UPDATE expired│
│ 4. Update mark   │ │ 4. Drop temp     │  │ 4. INSERT new    │
└──────────────────┘ └──────────────────┘  └──────────────────┘
```

## Querying SCD Data

### Current State Query

Get the current version of all records:

```sql
SELECT *
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE "_IS_CURRENT" = TRUE;
```

### Point-in-Time Query

Query the state as of a specific timestamp:

```sql
SELECT *
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE "_VALID_FROM" <= '2025-06-15 12:00:00'
  AND "_VALID_TO" > '2025-06-15 12:00:00';
```

### Change History Query

Get all versions of a specific record:

```sql
SELECT 
    NAME,
    DEFAULT_ROLE,
    "_VALID_FROM",
    "_VALID_TO",
    "_IS_CURRENT"
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE NAME = 'JOHN_DOE'
ORDER BY "_VALID_FROM";
```

### Changes in a Time Window

Find records that changed during a specific period:

```sql
SELECT *
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE "_VALID_FROM" BETWEEN '2025-01-01' AND '2025-03-31'
ORDER BY "_VALID_FROM";
```

### Deleted Records

Records that existed but no longer appear in source:

```sql
SELECT *
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE "_IS_CURRENT" = FALSE
  AND "_VALID_TO" != '9999-12-31 23:59:59'
  AND NOT EXISTS (
    SELECT 1 FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE curr
    WHERE curr.NAME = USERS_ARCHIVE.NAME
      AND curr."_IS_CURRENT" = TRUE
  );
```

## Load Procedure Details

### LOAD_VIEW_ARCHIVE

Core procedure that handles a single view:

```sql
CALL TEMPORAL_ARCHIVE.ARCHIVE.LOAD_VIEW_ARCHIVE('ACCOUNT_USAGE', 'USERS');
```

Returns:

```json
{
  "source": "SNOWFLAKE.ACCOUNT_USAGE.USERS",
  "target": "TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE",
  "action": "INCREMENTAL_LOAD",
  "rows_inserted": 5,
  "rows_updated": 2,
  "status": "success",
  "timestamp": "2025-01-15 06:00:00"
}
```

### LOAD_VIEW_ARCHIVE_WITH_RETRY

Wrapper with exponential backoff retry:

```sql
CALL TEMPORAL_ARCHIVE.ARCHIVE.LOAD_VIEW_ARCHIVE_WITH_RETRY(
    'ACCOUNT_USAGE',  -- schema
    'USERS',          -- view
    3,                -- max retries
    5                 -- initial delay seconds
);
```

### RUN_SCD_LOAD

Orchestrator that processes all views:

```sql
CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();
```

Returns summary:

```json
{
  "start_time": "2025-01-15 06:00:00",
  "end_time": "2025-01-15 06:18:33",
  "duration_seconds": 823,
  "run_id": 1,
  "views_in_registry": 98,
  "views_processed": 98,
  "success_count": 98,
  "error_count": 0,
  "total_updated": 536,
  "total_inserted": 9034,
  "table_results": [...]
}
```

## VIEW_REGISTRY

The registry controls which views are archived:

```sql
SELECT * FROM TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY;
```

| SOURCE_SCHEMA | SOURCE_VIEW | IS_ACTIVE | LOAD_STRATEGY | WATERMARK_COLUMN | UNIQUE_KEY_COLUMN |
|--------------|-------------|-----------|---------------|------------------|-------------------|
| ACCOUNT_USAGE | QUERY_HISTORY | TRUE | APPEND_ONLY | START_TIME | NULL |
| ACCOUNT_USAGE | USERS | TRUE | SOFT_DELETE_MUTABLE | NULL | NAME |
| ACCOUNT_USAGE | LOGIN_HISTORY | TRUE | APPEND_ONLY | EVENT_TIMESTAMP | NULL |
| ACCOUNT_USAGE | FUNCTIONS | TRUE | FULL_COMPARE | NULL | NULL |
| ORGANIZATION_USAGE | WAREHOUSE_METERING_HISTORY | FALSE | APPEND_ONLY | START_TIME | NULL |
| ... | ... | ... | ... | ... | ... |

**View Counts**: 133 total (107 active, 26 deactivated)
- **57 APPEND_ONLY**: Time-series views with watermark-based delta loading
- **40 SOFT_DELETE_MUTABLE**: Mutable views with full SCD2 via temp table
- **10 FULL_COMPARE**: Fallback hash comparison for views without clear keys
- **26 deactivated**: DATA_SHARING_USAGE (3), READER_ACCOUNT_USAGE (5), ORGANIZATION_USAGE (12 remaining inactive), non-existent/secure ACCOUNT_USAGE (6)

To disable a view:

```sql
UPDATE TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY 
SET IS_ACTIVE = FALSE 
WHERE SOURCE_VIEW = 'LARGE_VIEW_TO_SKIP';
```

To re-activate deactivated org views (when org-level data exists):

```sql
UPDATE TEMPORAL_ARCHIVE.ARCHIVE.VIEW_REGISTRY
SET IS_ACTIVE = TRUE
WHERE SOURCE_SCHEMA = 'ORGANIZATION_USAGE';
```

## WATERMARK_STATE

Tracks the last-loaded watermark for APPEND_ONLY views, enabling delta loading:

```sql
SELECT * FROM TEMPORAL_ARCHIVE.ARCHIVE.WATERMARK_STATE;
```

| Column | Type | Description |
|--------|------|-------------|
| `SOURCE_SCHEMA` | VARCHAR | Source schema name |
| `SOURCE_VIEW` | VARCHAR | Source view name |
| `LAST_WATERMARK` | TIMESTAMP_NTZ | Last MAX(watermark_column) loaded |
| `UPDATED_AT` | TIMESTAMP_NTZ | When watermark was last updated |

On each APPEND_ONLY load, the procedure:
1. Reads `LAST_WATERMARK` for the view
2. Queries only source rows where `watermark_column > LAST_WATERMARK`
3. Inserts new rows into the archive
4. Updates `LAST_WATERMARK` with the new MAX value

## Performance Optimization

### Clustering Keys

For large archive tables, clustering is automatically applied during deployment:

```sql
ALTER TABLE TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE 
CLUSTER BY ("_IS_CURRENT", "_LOADED_AT");
```

The following 7 tables are clustered by default: COLUMNS_ARCHIVE, QUERY_HISTORY_ARCHIVE,
AGGREGATE_QUERY_HISTORY_ARCHIVE, ACCESS_HISTORY_ARCHIVE, AGGREGATE_ACCESS_HISTORY_ARCHIVE,
TABLES_ARCHIVE, VIEWS_ARCHIVE.

### Partitioning Queries

For large historical queries, partition by date:

```sql
SELECT *
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
  AND START_TIME >= DATEADD('month', -1, CURRENT_DATE())
```

### Materialized Views

For frequently-accessed aggregations:

```sql
CREATE MATERIALIZED VIEW DAILY_CREDIT_SUMMARY AS
SELECT 
    DATE_TRUNC('day', START_TIME) AS day,
    WAREHOUSE_NAME,
    SUM(CREDITS_USED) AS daily_credits
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
GROUP BY 1, 2;
```

## Troubleshooting

### Duplicate Records

If you see duplicates with `_IS_CURRENT = TRUE`:

```sql
-- Find duplicates
SELECT "_SOURCE_TABLE", COUNT(*) as dupes
FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
WHERE "_IS_CURRENT" = TRUE
GROUP BY "_SOURCE_TABLE"
HAVING COUNT(*) != COUNT(DISTINCT "_ROW_HASH");
```

### Missing Changes

If changes aren't being detected, verify the hash is working:

```sql
-- Compare hashes
SELECT 
    SHA2(TO_JSON(OBJECT_CONSTRUCT(*)), 256) as source_hash
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
LIMIT 5;
```

### Load Failures

Check the load log for per-view detail rows grouped by RUN_ID:

```sql
-- Latest run summary
SELECT * FROM TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG
WHERE LOAD_STRATEGY = 'SUMMARY'
ORDER BY LOAD_TIMESTAMP DESC LIMIT 1;

-- Detail rows for a specific run
SELECT * FROM TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG
WHERE RUN_ID = (SELECT MAX(RUN_ID) FROM TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG)
  AND LOAD_STRATEGY != 'SUMMARY'
  AND STATUS != 'success'
ORDER BY SOURCE_TABLE;
```
