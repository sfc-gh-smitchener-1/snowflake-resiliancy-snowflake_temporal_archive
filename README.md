
![Snowflake Temporal Archive](TempArchive.png)

**Preserve your Snowflake ACCOUNT_USAGE history beyond the native 365-day limit with SCD Type 2 archiving and WORM-compliant backups.**

## What This Does

| Feature | Description |
|---------|-------------|
| **Extended Retention** | Archive 212 ACCOUNT_USAGE & ORGANIZATION_USAGE views (181 active) with 7+ year history (vs 1 year native) |
| **SCD Type 2 History** | Track every change with full audit trail and point-in-time queries |
| **WORM Compliance** | Immutable backups with RETENTION LOCK for SEC 17a-4, HIPAA, FINRA |
| **AI-Ready Analytics** | 10 semantic views + Cortex Intelligence Agent for natural language queries |
| **Self-Service Deployment** | Cortex Code skill for parameterized deployment to any account |

## Quick Start

### Option 1: Hands-On Quickstart (20-30 minutes)

**[Quickstart Guide](docs/quickstart.md)** - Step-by-step tutorial to deploy Temporal Archive from scratch.

### Option 2: Cortex Code Skill (Recommended for existing users)

```
Deploy Temporal Archive to my account
```

Or with custom settings:
```
Deploy Temporal Archive with database MY_ARCHIVE and warehouse MY_WH
```

### Option 3: Manual SQL Deployment

```sql
-- Run as ACCOUNTADMIN
\i sql/01_initial_setup.sql

-- Run as DATA_ADMIN  
\i sql/02_scd_load.sql
\i sql/03_semantic_layer.sql
\i sql/04_streamlit_ddl.sql

-- Initial data load
CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD();
```

## Architecture

```
SNOWFLAKE.ACCOUNT_USAGE (176 active views)
SNOWFLAKE.ORGANIZATION_USAGE (5 active views)
         │
         │ 3-Strategy Delta Load (6 AM & 6 PM daily)
         │  ├── APPEND_ONLY: Watermark-based delta (97 active views)
         │  ├── SOFT_DELETE_MUTABLE: Full SCD2 w/ temp table (61 active views)
         │  └── FULL_COMPARE: Hash comparison fallback (23 active views)
         ▼
┌─────────────────────────────────────────────────────────┐
│  TEMPORAL_ARCHIVE Database                              │
│  ├── ACCOUNT_USAGE Schema (176 SCD Type 2 archive tbl) │
│  ├── ORGANIZATION_USAGE Schema (5 active archive tables)│
│  ├── SEMANTIC Schema (10 semantic views + Cortex Agent) │
│  └── ARCHIVE Schema (procedures, tasks, registry, log)  │
│       ├── VIEW_REGISTRY (212 views, 181 active)         │
│       ├── WATERMARK_STATE (delta load tracking)         │
│       └── LOAD_LOG (per-view detail + summary rows)     │
│                                                         │
│  + WORM Backup Policy (7-year retention, immutable)     │
│  + Clustering Keys (7 largest tables)                   │
│  + Schema Evolution (auto-detect new source columns)    │
└─────────────────────────────────────────────────────────┘
```

## What Gets Deployed

| Component | Count | Description |
|-----------|-------|-------------|
| Archive Tables | 181 active | SCD Type 2 tables (31 deactivated reader/data-sharing/org-cost/secure views) |
| Semantic Views | 10 | Cost, security, storage, governance, tasks, BC/DR, query performance, organization analytics |
| Cortex Agent | 1 | SNOWFLAKEACCOUNTARCHIVE with 10 tools for natural language queries |
| Scheduled Tasks | 2 | Morning (6 AM) and evening (6 PM) SCD loads |
| Backup Policy | 1 | WORM-compliant with 7-year retention |

## Semantic Views

| View | Use Cases |
|------|-----------|
| `WAREHOUSE_COST_ANALYTICS` | Warehouse credits, query costs, user attribution |
| `SERVERLESS_COST_ANALYTICS` | Dynamic tables, tasks, pipes, auto-clustering costs |
| `COST_ANALYTICS` | General cost overview and trends |
| `SECURITY_ANALYTICS` | Login history, failed attempts, MFA adoption |
| `STORAGE_ANALYTICS` | Database/table storage, growth trends |
| `GOVERNANCE_ANALYTICS` | Users, roles, grants, access control |
| `TASK_ANALYTICS` | Task execution, failures, scheduling |
| `BCDR_ANALYTICS` | RPO/RTO metrics, hot tables, replication |
| `QUERY_PERFORMANCE_ANALYTICS` | Long-running queries, table access patterns, spill/queue alerts |
| `ORGANIZATION_ANALYTICS` | Cross-account usage, contract balances, org-wide warehouse/storage costs |

## Sample Agent Questions

```
"Which warehouses consumed the most credits last month?"
"Show failed login attempts this week"
"What are my hot tables with highest data churn?"
"Who are the top credit consumers by role?"
"What's my storage growth trend?"
"Show me long-running queries over 5 minutes"
"Which users accessed the CUSTOMERS table last week?"
"What queries have high partition scan percentages?"
"What is our remaining contract balance across all accounts?"
"Show me org-wide warehouse credit consumption by account"
```

## Repository Structure

```
├── sql/                        # Deployment SQL scripts
│   ├── 01_initial_setup.sql    # Database, warehouse, roles, backup policy
│   ├── 02_scd_load.sql         # SCD procedures and scheduled tasks
│   ├── 03_semantic_layer.sql   # 10 semantic views for Cortex Analyst
│   ├── 04_streamlit_ddl.sql    # Streamlit support objects
│   └── 05_streamlit_app.sql    # Streamlit app deployment
├── skill/                      # Cortex Code skill for self-service deployment
│   ├── SKILL.md                # Skill entry point
│   ├── config.template.yaml    # Configuration parameters
│   ├── templates/              # Parameterized SQL templates
│   └── scripts/                # Deployment automation
├── agent/                      # Cortex Agent configuration
├── src/                        # Streamlit application
└── docs/                       # Extended documentation
    ├── quickstart.md           # 20-30 min hands-on deployment guide
    ├── queries.md              # Sample analytical queries
    ├── skill-deployment.md     # Skill deployment guide
    ├── architecture.md         # Technical architecture details
    └── scd-design.md           # SCD Type 2 implementation details
```

## Documentation

| Document | Description |
|----------|-------------|
| **[Quickstart Guide](docs/quickstart.md)** | 20-30 minute hands-on tutorial for first-time deployment |
| [Sample Queries](docs/queries.md) | Ready-to-use SQL queries for cost, security, compliance |
| [Skill Deployment](docs/skill-deployment.md) | How to deploy using Cortex Code skill |
| [Architecture](docs/architecture.md) | Technical design and data flow |
| [SCD Design](docs/scd-design.md) | SCD Type 2 implementation details |

## Requirements

- **Snowflake Edition**: Business Critical or higher (for RETENTION LOCK)
- **Role**: ACCOUNTADMIN for initial setup
- **Features**: Cortex Analyst and Cortex Agents enabled

## Key Design Principles

1. **Native Execution** - All operations run within Snowflake (Tasks + Backup Policy)
2. **Immutability First** - WORM backup policy ensures audit compliance
3. **3-Strategy Delta Loading** - APPEND_ONLY (watermark), SOFT_DELETE_MUTABLE (temp table SCD2), FULL_COMPARE (hash fallback)
4. **Hash-Based CDC** - Deterministic change detection via `SHA2(TO_JSON(OBJECT_CONSTRUCT(*)), 256)`
5. **Schema Evolution** - Auto-detect and add new columns when Snowflake updates ACCOUNT_USAGE views
6. **Per-View Logging** - Detail rows with RUN_ID grouping for fast debugging of partial failures
7. **AI-Ready** - Semantic views optimized for Cortex Analyst
8. **Self-Service** - Parameterized skill for easy deployment

## Performance

| Metric | Baseline | Optimized | Improvement |
|--------|----------|-----------|-------------|
| Runtime | 2302s (38 min) | 968s (16.1 min) | **58% faster** |
| Views Processed | 212 (all) | 181 (active) | 31 deactivated |
| Strategy | Full compare only | 3-strategy delta | 97 watermark + 61 temp table + 23 hash |
| Table Layout | SCD columns last | SCD columns first | No column list overhead |
| Warehouse | LARGE Standard Gen2 | LARGE Standard Gen2 | Auto-suspend 60s |
| Clustering | None | 7 largest tables | `(_IS_CURRENT, _LOADED_AT)` |
| Schema Evolution | Manual | Automatic | Auto-detect new columns |
| Logging | Summary only | Per-view detail | RUN_ID grouping |

## Recent Updates (September 2026)

**Registry modernization** — Added 71 new ACCOUNT_USAGE views that Snowflake introduced since this repo was first built (Cortex Agent/AI/Guardrails usage, Semantic View metadata, Data Movement policies, Storage Lifecycle policies, Trust Center findings, Postgres/Iceberg/Openflow usage, dbt project execution, and more). Registry now covers all 181 current ACCOUNT_USAGE views. Deprecated views (SNAPSHOTS/SNAPSHOT_SETS/SNAPSHOT_STORAGE_USAGE, CORTEX_FUNCTIONS_QUERY_USAGE_HISTORY) are intentionally excluded in favor of their renamed replacements.

**Semantic view correctness** — Fixed a critical bug where every semantic view instructed Cortex Analyst to filter on `_IS_CURRENT = TRUE` but never exposed that column as a queryable dimension, causing all aggregates to double-count SCD history versions. Every table across all 10 semantic views now exposes an `is_current` dimension. Also fixed nonexistent column references (`DYNAMIC_TABLE_REFRESH_HISTORY.ID`), nullable primary keys (`TASK_ANALYTICS`), and incorrect composite keys.

**Organization analytics activation** — The 5 ORGANIZATION_USAGE views required by `ORGANIZATION_ANALYTICS` are now active by default (previously all 21 org views were deactivated, which caused the semantic view creation to fail on fresh deploys). They return 0 rows safely on non-ORGADMIN accounts.

**Skill template sync** — Regenerated `skill/templates/02_scd_load.sql` from the current reference implementation (was a stale copy of an old single-strategy version missing watermarks, 3-strategy delta load, and all new views). Fixed `deploy.py` to execute `CREATE OR REPLACE AGENT` via SQL DDL instead of printing a stale "use REST API" message.

**Bug fixes** — `EXTERNAL_ACCESS_HISTORY` watermark (was using `QUERY_ID`, not a timestamp), `CALLER_GRANTS_TO_ROLES` (nonexistent view registered as active), duplicate `LOAD_LOG` DDL across three scripts consolidated to one, wrong column names in `queries.md` sample queries, warehouse size defaults corrected to LARGE Gen2 throughout, `GENERATION = '2'` added to skill template.

## References

- [Snowflake Backups](https://docs.snowflake.com/en/user-guide/backups)
- [Backup Policy](https://docs.snowflake.com/en/sql-reference/sql/create-backup-policy)
- [Semantic Views](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view)
- [Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [ACCOUNT_USAGE Views](https://docs.snowflake.com/en/sql-reference/account-usage)
