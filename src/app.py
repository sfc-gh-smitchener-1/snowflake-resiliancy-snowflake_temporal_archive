# ============================================================================
# SNOWFLAKE TEMPORAL ARCHIVE - Analytics Dashboard
# ============================================================================
# 
# A Streamlit application for exploring historical ACCOUNT_USAGE data with:
#   1. Archive Explorer - Browse archived Snowflake metadata
#   2. Cost Analytics - Warehouse and query cost analysis
#   3. Security Auditing - Login patterns and access compliance
#   4. Cortex Analyst - Natural language queries via Snowflake Cortex
#   5. Operations Dashboard - Task status and backup health
#
# Reference: https://docs.snowflake.com/en/user-guide/backups
#
# This app runs in Streamlit in Snowflake (SiS).
# ============================================================================

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

# ============================================================================
# PAGE CONFIGURATION
# ============================================================================

st.set_page_config(
    page_title="Temporal Archive",
    page_icon="🏛️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ============================================================================
# STYLING
# ============================================================================

st.markdown("""
<style>
    .stApp {
        background: linear-gradient(180deg, #FFFFFF 0%, #F0F9FF 100%);
    }
    
    [data-testid="stSidebar"] {
        background: linear-gradient(180deg, #1E3A5F 0%, #0D2137 100%);
    }
    
    [data-testid="stSidebar"] * {
        color: white !important;
    }
    
    .main-header {
        background: linear-gradient(135deg, #29B5E8 0%, #1E3A5F 100%);
        padding: 1.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 1.5rem;
        color: white;
        box-shadow: 0 4px 20px rgba(41, 181, 232, 0.3);
    }
    
    .main-header h1 { margin: 0; font-size: 1.75rem; font-weight: 700; }
    .main-header p { margin: 0.5rem 0 0 0; opacity: 0.9; font-size: 0.95rem; }
    
    .metric-card {
        background: white;
        border-radius: 12px;
        padding: 1.25rem;
        border-left: 4px solid #29B5E8;
        box-shadow: 0 2px 8px rgba(0,0,0,0.06);
        margin-bottom: 0.5rem;
    }
    
    .status-healthy { border-left-color: #18794E; }
    .status-warning { border-left-color: #AD5700; }
    .status-critical { border-left-color: #CD2B31; }
    
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
</style>
""", unsafe_allow_html=True)

# ============================================================================
# SESSION MANAGEMENT
# ============================================================================

@st.cache_resource
def get_session():
    """Get Snowflake session"""
    return get_active_session()

# ============================================================================
# DATA FUNCTIONS
# ============================================================================

@st.cache_data(ttl=60)
def get_archive_summary():
    """Get summary of archived data"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT * FROM TEMPORAL_ARCHIVE.STREAMLIT.VW_ARCHIVE_SUMMARY
        """).to_pandas()
        return df
    except Exception as e:
        st.warning(f"Could not load archive summary: {str(e)}")
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_archive_inventory():
    """Get detailed archive table inventory"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT * FROM TEMPORAL_ARCHIVE.STREAMLIT.VW_ARCHIVE_INVENTORY
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_semantic_views():
    """Get available semantic views"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT * FROM TEMPORAL_ARCHIVE.STREAMLIT.VW_SEMANTIC_VIEWS
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

@st.cache_data(ttl=30)
def get_load_history():
    """Get recent SCD load history"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT * FROM TEMPORAL_ARCHIVE.STREAMLIT.VW_LOAD_HISTORY
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

def sample_archive_table(schema: str, table_name: str, limit: int = 100):
    """Sample data from an archive table"""
    session = get_session()
    try:
        df = session.sql(f"""
            SELECT * 
            FROM TEMPORAL_ARCHIVE.{schema}.{table_name}
            WHERE "_IS_CURRENT" = TRUE
            LIMIT {limit}
        """).to_pandas()
        return df
    except Exception as e:
        return None

def execute_sql(sql: str):
    """Execute SQL and return DataFrame"""
    session = get_session()
    try:
        return session.sql(sql).to_pandas(), None
    except Exception as e:
        return None, str(e)

# ============================================================================
# CORTEX INTEGRATION
# ============================================================================

def call_cortex_complete(prompt: str, semantic_view: str):
    """Use Cortex COMPLETE to generate SQL from natural language"""
    session = get_session()
    
    try:
        # Get underlying table info for the semantic view
        config = session.sql(f"""
            SELECT VIEW_SQL 
            FROM TEMPORAL_ARCHIVE.SEMANTIC.SEMANTIC_CONFIG 
            WHERE VIEW_NAME = '{semantic_view}'
              AND IS_ACTIVE = TRUE
        """).to_pandas()
        
        if config.empty:
            return None, "Semantic view not found"
        
        view_sql = config['VIEW_SQL'].iloc[0]
        
        # Extract table reference
        import re
        table_match = re.search(r'AS\s+(TEMPORAL_ARCHIVE\.\w+\.\w+)', view_sql)
        
        if not table_match:
            return None, "Could not find underlying table"
        
        primary_table = table_match.group(1)
        
        # Get column info
        sample_df = session.sql(f"SELECT * FROM {primary_table} LIMIT 1").to_pandas()
        columns = list(sample_df.columns)
        columns_str = ', '.join(columns[:30])
        
        # Build prompt for Cortex
        escaped_prompt = prompt.replace("'", "''")
        
        system_prompt = f"""Generate a Snowflake SQL query.

TABLE: {primary_table}
COLUMNS: {columns_str}

Question: {escaped_prompt}

IMPORTANT:
- Use SELECT with specific columns or aggregations
- Table name is exactly: {primary_table}
- Filter with "_IS_CURRENT" = TRUE for current records
- Add LIMIT 100 at the end
- Return ONLY SQL, no explanations"""

        # Call Cortex
        result = session.sql(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                'llama3.1-70b',
                '{system_prompt.replace("'", "''")}'
            ) AS response
        """).to_pandas()
        
        if not result.empty and result['RESPONSE'].iloc[0]:
            sql = result['RESPONSE'].iloc[0].strip()
            
            # Clean up SQL
            if '```' in sql:
                parts = sql.split('```')
                for part in parts:
                    if 'SELECT' in part.upper():
                        sql = part.strip()
                        if sql.lower().startswith('sql'):
                            sql = sql[3:].strip()
                        break
            
            if ';' in sql:
                sql = sql.split(';')[0] + ';'
            
            return {
                "sql": sql,
                "table": primary_table
            }, None
        else:
            return None, "Could not generate SQL"
            
    except Exception as e:
        return None, f"Error: {str(e)}"

# ============================================================================
# SIDEBAR
# ============================================================================

def render_sidebar():
    """Render sidebar navigation"""
    with st.sidebar:
        st.markdown("""
        <div style="text-align: center; padding: 1rem 0 1.5rem 0;">
            <div style="font-size: 3rem; margin-bottom: 0.5rem;">🏛️</div>
            <h2 style="color: white; font-size: 1.2rem; margin: 0;">Temporal Archive</h2>
            <p style="color: #29B5E8; font-size: 0.85rem;">ACCOUNT_USAGE History</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.divider()
        
        # Navigation
        page = st.radio(
            "Navigation",
            ["🏠 Dashboard", "🔍 Archive Explorer", "💰 Cost Analytics", 
             "🔒 Security Audit", "🤖 Cortex Analyst", "⚙️ Operations", "ℹ️ About"],
            label_visibility="collapsed"
        )
        
        st.divider()
        
        # Archive stats
        st.markdown("### 📊 Archive Status")
        summary = get_archive_summary()
        if not summary.empty:
            total_tables = summary['TABLE_COUNT'].sum()
            total_rows = summary['TOTAL_ROWS'].sum()
            st.markdown(f"**Tables:** {int(total_tables)}")
            st.markdown(f"**Total Rows:** {int(total_rows):,}")
        
        st.divider()
        
        st.markdown("""
        <small style="color: #94A3B8;">
        WORM Backup: 7 years<br/>
        Ref: docs.snowflake.com/en/user-guide/backups
        </small>
        """, unsafe_allow_html=True)
        
        return page

# ============================================================================
# PAGE: DASHBOARD
# ============================================================================

def render_dashboard():
    """Render main dashboard"""
    st.markdown("""
    <div class="main-header">
        <h1>🏛️ Temporal Archive Dashboard</h1>
        <p>Historical ACCOUNT_USAGE data with 7-year WORM-compliant retention</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Archive Overview
    st.markdown("### 📊 Archive Overview")
    
    summary = get_archive_summary()
    
    if not summary.empty:
        cols = st.columns(len(summary))
        for i, row in summary.iterrows():
            with cols[i]:
                st.markdown(f"""
                <div class="metric-card">
                    <strong>{row['SOURCE_SCHEMA']}</strong>
                    <div style="font-size: 1.5rem; font-weight: 700;">{int(row['TABLE_COUNT'])}</div>
                    <small style="color: #64748B;">tables • {int(row['TOTAL_ROWS']):,} rows</small>
                </div>
                """, unsafe_allow_html=True)
    else:
        st.info("No archive data available. Run SCD load to populate archive tables.")
    
    st.divider()
    
    # Value Proposition
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 💡 Why Temporal Archive?")
        st.markdown("""
        | Without Archive | With Archive |
        |-----------------|--------------|
        | 1 year retention | **7+ years** |
        | Limited trends | **Multi-year analysis** |
        | No audit trail | **Immutable WORM** |
        | Point-in-time only | **Full evolution** |
        """)
    
    with col2:
        st.markdown("### 🔒 WORM Compliance")
        st.markdown("""
        - **Backup Policy**: RETENTION LOCK enabled
        - **Schedule**: Daily backups
        - **Retention**: 7 years (2555 days)
        - **Immutable**: Cannot be deleted by anyone
        - **Compliance**: SEC 17a-4, HIPAA, FINRA
        
        [Snowflake Backup Docs](https://docs.snowflake.com/en/user-guide/backups)
        """)
    
    st.divider()
    
    # Recent Load Activity
    st.markdown("### 📋 Recent Load Activity")
    history = get_load_history()
    if not history.empty:
        st.dataframe(history.head(10), use_container_width=True)
    else:
        st.info("No load history available yet.")

# ============================================================================
# PAGE: ARCHIVE EXPLORER
# ============================================================================

def render_explorer():
    """Render archive explorer"""
    st.markdown("""
    <div class="main-header">
        <h1>🔍 Archive Explorer</h1>
        <p>Browse historical Snowflake ACCOUNT_USAGE data</p>
    </div>
    """, unsafe_allow_html=True)
    
    inventory = get_archive_inventory()
    
    if not inventory.empty:
        # Schema filter
        schemas = inventory['SOURCE_SCHEMA'].unique().tolist()
        selected_schema = st.selectbox("Select Schema", schemas)
        
        # Filter tables
        schema_tables = inventory[inventory['SOURCE_SCHEMA'] == selected_schema]
        
        col1, col2 = st.columns([1, 2])
        
        with col1:
            st.markdown("### Tables")
            for _, row in schema_tables.iterrows():
                with st.expander(f"📋 {row['TABLE_NAME']}"):
                    st.markdown(f"**Rows:** {int(row['ROW_COUNT']):,}")
                    st.markdown(f"**Size:** {int(row['BYTES'] / 1024 / 1024):.2f} MB")
                    if st.button(f"Sample Data", key=f"sample_{row['TABLE_NAME']}"):
                        st.session_state.selected_table = row['TABLE_NAME']
                        st.session_state.selected_schema = selected_schema
        
        with col2:
            if 'selected_table' in st.session_state:
                st.markdown(f"### {st.session_state.selected_table}")
                
                limit = st.slider("Rows to sample", 10, 500, 100)
                
                with st.spinner("Loading data..."):
                    sample_df = sample_archive_table(
                        st.session_state.selected_schema,
                        st.session_state.selected_table,
                        limit
                    )
                    
                    if sample_df is not None:
                        st.success(f"Loaded {len(sample_df)} rows")
                        st.dataframe(sample_df, use_container_width=True)
                    else:
                        st.error("Could not load sample data")
            else:
                st.info("Select a table to view sample data")
    else:
        st.warning("No archive tables found. Run SCD load first.")

# ============================================================================
# PAGE: COST ANALYTICS
# ============================================================================

def render_cost_analytics():
    """Render cost analytics page"""
    st.markdown("""
    <div class="main-header">
        <h1>💰 Cost Analytics</h1>
        <p>Warehouse utilization and query cost optimization</p>
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown("### 📊 Sample Cost Queries")
    
    sample_queries = {
        "Warehouse Credits by Month": """
            SELECT 
                DATE_TRUNC('month', START_TIME) AS month,
                WAREHOUSE_NAME,
                SUM(CREDITS_USED) AS total_credits
            FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY_ARCHIVE
            WHERE "_IS_CURRENT" = TRUE
            GROUP BY 1, 2
            ORDER BY 1 DESC, 3 DESC
            LIMIT 100
        """,
        "Top Query Users": """
            SELECT 
                USER_NAME,
                COUNT(*) AS query_count,
                SUM(TOTAL_ELAPSED_TIME)/1000/60 AS total_minutes
            FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
            WHERE "_IS_CURRENT" = TRUE
            GROUP BY USER_NAME
            ORDER BY query_count DESC
            LIMIT 20
        """,
        "Query Type Distribution": """
            SELECT 
                QUERY_TYPE,
                COUNT(*) AS query_count,
                AVG(TOTAL_ELAPSED_TIME)/1000 AS avg_seconds
            FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.QUERY_HISTORY_ARCHIVE
            WHERE "_IS_CURRENT" = TRUE
            GROUP BY QUERY_TYPE
            ORDER BY query_count DESC
            LIMIT 20
        """
    }
    
    selected_query = st.selectbox("Select Analysis", list(sample_queries.keys()))
    
    st.code(sample_queries[selected_query], language="sql")
    
    if st.button("Run Query"):
        with st.spinner("Executing..."):
            result_df, error = execute_sql(sample_queries[selected_query])
            if error:
                st.error(f"Error: {error}")
            elif result_df is not None:
                st.success(f"Returned {len(result_df)} rows")
                st.dataframe(result_df, use_container_width=True)

# ============================================================================
# PAGE: SECURITY AUDIT
# ============================================================================

def render_security_audit():
    """Render security audit page"""
    st.markdown("""
    <div class="main-header">
        <h1>🔒 Security Audit</h1>
        <p>Login patterns, access compliance, and threat detection</p>
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown("### 🔐 Security Queries")
    
    security_queries = {
        "Failed Login Attempts": """
            SELECT 
                USER_NAME,
                CLIENT_IP,
                ERROR_CODE,
                ERROR_MESSAGE,
                EVENT_TIMESTAMP
            FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
            WHERE "_IS_CURRENT" = TRUE
              AND IS_SUCCESS = 'NO'
            ORDER BY EVENT_TIMESTAMP DESC
            LIMIT 100
        """,
        "Login by User (Last 30 Days)": """
            SELECT 
                USER_NAME,
                COUNT(*) AS login_count,
                SUM(CASE WHEN IS_SUCCESS = 'YES' THEN 1 ELSE 0 END) AS success_count,
                SUM(CASE WHEN IS_SUCCESS = 'NO' THEN 1 ELSE 0 END) AS failure_count
            FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.LOGIN_HISTORY_ARCHIVE
            WHERE "_IS_CURRENT" = TRUE
            GROUP BY USER_NAME
            ORDER BY login_count DESC
            LIMIT 50
        """,
        "Users Without MFA": """
            SELECT 
                NAME AS user_name,
                EMAIL,
                DEFAULT_ROLE,
                LAST_SUCCESS_LOGIN,
                HAS_MFA
            FROM TEMPORAL_ARCHIVE.ACCOUNT_USAGE.USERS_ARCHIVE
            WHERE "_IS_CURRENT" = TRUE
              AND (HAS_MFA = 'false' OR HAS_MFA IS NULL)
              AND DISABLED = 'false'
            ORDER BY LAST_SUCCESS_LOGIN DESC
            LIMIT 50
        """
    }
    
    selected_query = st.selectbox("Select Audit", list(security_queries.keys()))
    
    st.code(security_queries[selected_query], language="sql")
    
    if st.button("Run Audit Query"):
        with st.spinner("Executing..."):
            result_df, error = execute_sql(security_queries[selected_query])
            if error:
                st.error(f"Error: {error}")
            elif result_df is not None:
                st.success(f"Returned {len(result_df)} rows")
                st.dataframe(result_df, use_container_width=True)

# ============================================================================
# PAGE: CORTEX ANALYST
# ============================================================================

def render_cortex_page():
    """Render Cortex Analyst interface"""
    st.markdown("""
    <div class="main-header">
        <h1>🤖 Cortex Analyst</h1>
        <p>Natural language queries on historical ACCOUNT_USAGE data</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Get semantic views
    sem_views = get_semantic_views()
    
    if not sem_views.empty:
        # View selector
        view_options = sem_views['VIEW_NAME'].tolist()
        selected_view = st.selectbox("Select Analysis Type", view_options)
        
        # Show view description
        view_info = sem_views[sem_views['VIEW_NAME'] == selected_view].iloc[0]
        st.caption(view_info['DESCRIPTION'])
        
        st.divider()
        
        # Sample questions
        st.markdown("### 💡 Sample Questions")
        sample_questions = [
            "Show total credits by warehouse for the last year",
            "Which users have the most failed login attempts?",
            "What is the query count by type?",
            "Show storage usage trend",
            "List users who haven't logged in recently"
        ]
        
        cols = st.columns(3)
        for i, q in enumerate(sample_questions[:3]):
            with cols[i]:
                if st.button(f"💬 {q[:30]}...", key=f"sample_{i}"):
                    st.session_state.cortex_question = q
        
        st.divider()
        
        # Question input
        question = st.text_input(
            "Ask a question",
            value=st.session_state.get('cortex_question', ''),
            placeholder="e.g., Show warehouse credit usage by month"
        )
        
        if st.button("🚀 Ask Cortex", type="primary"):
            if question:
                with st.spinner("Generating SQL with Cortex..."):
                    result, error = call_cortex_complete(question, selected_view)
                    
                    if error:
                        st.error(error)
                    elif result:
                        st.markdown("### Generated SQL")
                        st.code(result['sql'], language="sql")
                        
                        if st.button("▶️ Execute Query"):
                            with st.spinner("Running query..."):
                                df, sql_error = execute_sql(result['sql'])
                                if sql_error:
                                    st.error(f"SQL Error: {sql_error}")
                                elif df is not None:
                                    st.success(f"Returned {len(df)} rows")
                                    st.dataframe(df, use_container_width=True)
            else:
                st.warning("Please enter a question")
    else:
        st.warning("No semantic views available. Run BUILD_SEMANTIC_LAYER() first.")

# ============================================================================
# PAGE: ABOUT
# ============================================================================

def render_about():
    """Render about page"""
    st.markdown("""
    <div class="main-header">
        <h1>ℹ️ About Temporal Archive</h1>
        <p>Snowflake ACCOUNT_USAGE historical preservation with WORM compliance</p>
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown("""
    ### 🎯 Purpose
    
    The **Snowflake Temporal Archive** preserves the complete history of `SNOWFLAKE.ACCOUNT_USAGE` 
    views using SCD Type 2 tables, extending retention from 1 year to **7+ years** with 
    WORM-compliant immutable backups.
    
    ### 🏗️ Architecture
    
    | Component | Purpose |
    |-----------|---------|
    | **SCD Type 2 Tables** | Capture every change with full history |
    | **Backup Policy** | RETENTION LOCK for WORM compliance |
    | **Semantic Views** | Enable natural language queries |
    | **Streamlit App** | Self-service analytics interface |
    
    ### 📊 Key Views Archived
    
    - **QUERY_HISTORY** - Query execution and cost
    - **WAREHOUSE_METERING_HISTORY** - Credit consumption
    - **LOGIN_HISTORY** - Authentication events
    - **USERS** - User lifecycle
    - **ROLES** - Privilege hierarchy
    - **DATABASES/TABLES** - Object inventory
    
    ### 🔒 WORM Compliance
    
    ```sql
    CREATE BACKUP POLICY TEMPORAL_ARCHIVE_WORM_BACKUP_POLICY
        WITH RETENTION LOCK
        SCHEDULE = '1440 MINUTE'
        EXPIRE_AFTER_DAYS = 2555;
    ```
    
    ### 📚 Reference
    
    [Snowflake Backup Documentation](https://docs.snowflake.com/en/user-guide/backups)
    """)

# ============================================================================
# PAGE: OPERATIONS
# ============================================================================

def run_scd_load():
    """Execute the SCD load procedure"""
    session = get_session()
    try:
        result = session.sql("CALL TEMPORAL_ARCHIVE.ARCHIVE.RUN_SCD_LOAD()").collect()
        if result:
            return result[0][0], None
        return None, "No result returned"
    except Exception as e:
        return None, str(e)

def get_task_history():
    """Get recent task execution history"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT 
                NAME,
                STATE,
                SCHEDULED_TIME,
                COMPLETED_TIME,
                ERROR_MESSAGE
            FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
                SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
                RESULT_LIMIT => 20
            ))
            WHERE DATABASE_NAME = 'TEMPORAL_ARCHIVE'
            ORDER BY SCHEDULED_TIME DESC
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

def render_operations():
    """Render operations page with SCD load button"""
    st.markdown("""
    <div class="main-header">
        <h1>⚙️ Operations</h1>
        <p>Run SCD loads on demand and monitor task execution</p>
    </div>
    """, unsafe_allow_html=True)
    
    # SCD Load Section
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.markdown("### 🚀 Run SCD Load On Demand")
        st.markdown("""
        Click the button below to manually trigger an SCD Type 2 load for all registered tables.
        This will:
        - Read from SNOWFLAKE.ACCOUNT_USAGE views
        - Compare with existing archive data using row hashes
        - Close changed records (set `_IS_CURRENT = FALSE`)
        - Insert new/changed records as current versions
        """)
        
        st.warning("**Note:** This operation may take several minutes depending on data volume.")
        
        if st.button("🔄 Run SCD Load Now", type="primary", use_container_width=True):
            with st.spinner("Running SCD load... This may take a few minutes."):
                result, error = run_scd_load()
                
                if error:
                    st.error(f"Error: {error}")
                elif result:
                    import json
                    result_dict = json.loads(result) if isinstance(result, str) else result
                    
                    st.success("SCD Load completed successfully!")
                    
                    # Display results
                    col_a, col_b, col_c, col_d = st.columns(4)
                    with col_a:
                        st.metric("Tables Processed", result_dict.get('tables_processed', 0))
                    with col_b:
                        st.metric("Rows Updated", result_dict.get('total_updated', 0))
                    with col_c:
                        st.metric("Rows Inserted", result_dict.get('total_inserted', 0))
                    with col_d:
                        st.metric("Errors", result_dict.get('error_count', 0))
                    
                    # Show detailed results
                    if 'table_results' in result_dict:
                        st.markdown("#### Detailed Results")
                        st.json(result_dict['table_results'])
    
    with col2:
        st.markdown("### 📋 Quick Actions")
        
        if st.button("🔄 Refresh Stats", use_container_width=True):
            st.cache_data.clear()
            st.rerun()
        
        st.markdown("---")
        st.markdown("### 📊 Task Schedule")
        st.markdown("""
        | Task | Schedule |
        |------|----------|
        | Morning Load | 6:00 AM ET |
        | Evening Load | 6:00 PM ET |
        """)
    
    st.divider()
    
    # Load History
    st.markdown("### 📜 Recent Load History")
    history = get_load_history()
    if not history.empty:
        st.dataframe(history, use_container_width=True)
    else:
        st.info("No load history available yet.")
    
    st.divider()
    
    # Task Execution History
    st.markdown("### ⏱️ Task Execution History (Last 7 Days)")
    task_history = get_task_history()
    if not task_history.empty:
        st.dataframe(task_history, use_container_width=True)
    else:
        st.info("No task execution history available.")
    
    st.divider()
    
    # Registry
    st.markdown("### 📋 Table Registry")
    session = get_session()
    try:
        registry_df = session.sql("""
            SELECT 
                SOURCE_SCHEMA,
                SOURCE_VIEW,
                TARGET_TABLE,
                PRIMARY_KEY_COLUMNS,
                IS_ACTIVE
            FROM TEMPORAL_ARCHIVE.ARCHIVE.TABLE_REGISTRY
            ORDER BY SOURCE_SCHEMA, SOURCE_VIEW
        """).to_pandas()
        
        if not registry_df.empty:
            st.dataframe(registry_df, use_container_width=True)
        else:
            st.info("No tables registered in the registry.")
    except Exception as e:
        st.error(f"Could not load registry: {e}")


# ============================================================================
# MAIN
# ============================================================================

def main():
    """Main application entry point"""
    page = render_sidebar()
    
    if page == "🏠 Dashboard":
        render_dashboard()
    elif page == "🔍 Archive Explorer":
        render_explorer()
    elif page == "💰 Cost Analytics":
        render_cost_analytics()
    elif page == "🔒 Security Audit":
        render_security_audit()
    elif page == "🤖 Cortex Analyst":
        render_cortex_page()
    elif page == "⚙️ Operations":
        render_operations()
    elif page == "ℹ️ About":
        render_about()

if __name__ == "__main__":
    main()
