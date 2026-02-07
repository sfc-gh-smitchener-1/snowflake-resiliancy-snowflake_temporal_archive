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
from datetime import datetime, time as dt_time
import logging
import json

# Import _snowflake for Cortex Analyst REST API
try:
    import _snowflake
    HAS_SNOWFLAKE_API = True
except ImportError:
    HAS_SNOWFLAKE_API = False

# Optional pytz import - fallback to UTC if not available
try:
    import pytz
    HAS_PYTZ = True
except ImportError:
    HAS_PYTZ = False

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================================================
# SECURITY HELPERS
# ============================================================================

import re

def validate_identifier(identifier: str) -> bool:
    """Validate that a string is a safe Snowflake identifier.
    
    Prevents SQL injection by ensuring identifiers only contain safe characters.
    
    Args:
        identifier: The schema, table, or column name to validate.
        
    Returns:
        True if the identifier is safe, False otherwise.
    """
    if not identifier:
        return False
    # Allow alphanumeric, underscores, and must start with letter or underscore
    pattern = r'^[A-Za-z_][A-Za-z0-9_]*$'
    return bool(re.match(pattern, identifier))

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

# Session cache timeout in seconds (refresh session periodically)
SESSION_CACHE_TTL = 300  # 5 minutes

@st.cache_resource(ttl=SESSION_CACHE_TTL)
def get_session():
    """Get Snowflake session with automatic refresh on timeout.
    
    The session is cached for SESSION_CACHE_TTL seconds to balance
    performance with session freshness. If the session expires or
    becomes invalid, it will be automatically refreshed on next call.
    
    Returns:
        Active Snowflake session.
    """
    try:
        session = get_active_session()
        # Validate session is working with a simple query
        session.sql("SELECT 1").collect()
        logger.info("Snowflake session initialized successfully")
        return session
    except Exception as e:
        logger.error(f"Failed to initialize Snowflake session: {e}")
        raise

def validate_session() -> bool:
    """Validate that the current session is still active.
    
    Returns:
        True if session is valid, False otherwise.
    """
    try:
        session = get_session()
        session.sql("SELECT 1").collect()
        return True
    except Exception as e:
        logger.warning(f"Session validation failed: {e}")
        # Clear the cached session to force refresh
        get_session.clear()
        return False

# ============================================================================
# DATA FUNCTIONS
# ============================================================================

@st.cache_data(ttl=60)
def get_archive_summary() -> pd.DataFrame:
    """Get summary of archived data.
    
    Returns:
        DataFrame with archive summary by schema.
    """
    session = get_session()
    try:
        df = session.sql("""
            SELECT * FROM TEMPORAL_ARCHIVE.STREAMLIT.VW_ARCHIVE_SUMMARY
        """).to_pandas()
        logger.info(f"Archive summary loaded: {len(df)} rows")
        return df
    except Exception as e:
        logger.error(f"Error loading archive summary: {e}")
        st.error(f"Could not load archive summary: {str(e)}")
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_archive_inventory():
    """Get detailed archive table inventory"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT * FROM TEMPORAL_ARCHIVE.STREAMLIT.VW_ARCHIVE_INVENTORY
        """).to_pandas()
        logger.info(f"Archive inventory loaded: {len(df)} rows")
        return df
    except Exception as e:
        logger.error(f"Error loading archive inventory: {e}")
        st.error(f"Could not load archive inventory: {str(e)}")
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_semantic_views() -> pd.DataFrame:
    """Get available native Snowflake semantic views for Cortex Analyst.
    
    Returns:
        DataFrame with semantic view information, or empty DataFrame if unavailable.
    """
    session = get_session()
    try:
        # Get semantic views from INFORMATION_SCHEMA
        # Column names: CATALOG, SCHEMA, NAME, OWNER, CREATED, COMMENT
        df = session.sql("""
            SELECT 
                NAME AS SEMANTIC_VIEW_NAME,
                COMMENT AS DESCRIPTION,
                CREATED AS CREATED_AT
            FROM TEMPORAL_ARCHIVE.INFORMATION_SCHEMA.SEMANTIC_VIEWS
            WHERE SCHEMA = 'SEMANTIC'
            ORDER BY NAME
        """).to_pandas()
        return df
    except Exception as e:
        error_msg = str(e).lower()
        if "does not exist" in error_msg or "not found" in error_msg:
            logger.warning("INFORMATION_SCHEMA.SEMANTIC_VIEWS not available - semantic views may not be created yet")
        else:
            logger.error(f"Error fetching semantic views: {e}")
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

def sample_archive_table(schema: str, table_name: str, limit: int = 100) -> pd.DataFrame | None:
    """Sample data from an archive table.
    
    Args:
        schema: The schema name (validated for safety).
        table_name: The table name (validated for safety).
        limit: Maximum rows to return.
        
    Returns:
        DataFrame with sample data, or None if error/invalid input.
    """
    # Validate identifiers to prevent SQL injection
    if not validate_identifier(schema):
        logger.error(f"Invalid schema identifier: {schema}")
        return None
    if not validate_identifier(table_name):
        logger.error(f"Invalid table identifier: {table_name}")
        return None
    if not isinstance(limit, int) or limit < 1 or limit > 10000:
        limit = 100  # Default to safe value
    
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
# CORTEX ANALYST INTEGRATION
# ============================================================================

def call_cortex_analyst(prompt: str, semantic_view: str) -> tuple[dict | None, str | None]:
    """Use Cortex Analyst REST API with native Snowflake Semantic Views.
    
    Args:
        prompt: Natural language question to ask.
        semantic_view: Name of the semantic view to query against.
        
    Returns:
        Tuple of (result_dict, None) on success or (None, error_message) on failure.
    """
    if not HAS_SNOWFLAKE_API:
        return None, "Cortex Analyst API not available in this environment"
    
    try:
        # Build the fully qualified semantic view name
        semantic_view_fqn = f"TEMPORAL_ARCHIVE.SEMANTIC.{semantic_view}"
        
        # Build the request payload for Cortex Analyst REST API
        request_body = {
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": prompt
                        }
                    ]
                }
            ],
            "semantic_view": semantic_view_fqn
        }
        
        # Call the Cortex Analyst REST API
        response = _snowflake.send_snow_api_request(
            "POST",
            "/api/v2/cortex/analyst/message",
            {},  # headers
            {},  # params
            request_body,
            None,  # request_guid
            60000  # timeout_ms
        )
        
        # Parse response - handle both dict and string responses
        response_body = None
        
        # Check if response is already a dict or needs JSON parsing
        if isinstance(response, dict):
            # Response might have message directly or in "content" field
            if "message" in response:
                response_body = response
            elif "content" in response:
                content = response.get("content")
                if isinstance(content, str):
                    response_body = json.loads(content)
                elif isinstance(content, dict):
                    response_body = content
            # Check status code if present
            status_code = response.get("status_code", 200)
            if status_code != 200 and "message" not in response:
                return None, f"Cortex Analyst error (status {status_code}): {response}"
        elif isinstance(response, str):
            response_body = json.loads(response)
        
        if not response_body:
            return None, f"Unexpected response format: {type(response)}"
        
        # Extract message content
        message = response_body.get("message", response_body)
        
        # Handle case where message is the response_body itself
        if "content" in message and "role" in message:
            content_list = message.get("content", [])
        elif "content" in response_body:
            content_list = response_body.get("content", [])
        else:
            content_list = []
        
        sql_statement = None
        explanation = None
        suggestions = []
        
        for content in content_list:
            if isinstance(content, dict):
                content_type = content.get("type")
                if content_type == "sql":
                    sql_statement = content.get("statement", "")
                elif content_type == "text":
                    explanation = content.get("text", "")
                elif content_type == "suggestions":
                    suggestions = content.get("suggestions", [])
        
        if sql_statement:
            return {
                "sql": sql_statement,
                "explanation": explanation,
                "semantic_view": semantic_view_fqn,
                "suggestions": suggestions
            }, None
        elif suggestions:
            return {
                "suggestions": suggestions,
                "explanation": explanation,
                "semantic_view": semantic_view_fqn
            }, None
        elif explanation:
            return {
                "explanation": explanation,
                "semantic_view": semantic_view_fqn
            }, None
        else:
            return None, f"Cortex Analyst returned no usable content: {response_body}"
            
    except json.JSONDecodeError as e:
        return None, f"Failed to parse Cortex Analyst response: {e}"
    except Exception as e:
        error_msg = str(e)
        # Provide helpful error messages
        if "does not exist" in error_msg.lower():
            return None, f"Semantic view '{semantic_view}' not found. Run 03_semantic_layer.sql first."
        elif "not authorized" in error_msg.lower() or "permission" in error_msg.lower():
            return None, "Not authorized to use Cortex Analyst. Ensure your role has SNOWFLAKE.CORTEX_USER database role."
        else:
            return None, f"Cortex Analyst error: {error_msg}"

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
    
    # Debug info (expandable)
    with st.expander("🔧 Debug Info", expanded=False):
        try:
            session = get_session()
            ctx = session.sql("SELECT CURRENT_ROLE() as role, CURRENT_DATABASE() as db, CURRENT_SCHEMA() as schema, CURRENT_WAREHOUSE() as wh").to_pandas()
            st.write("**Session Context:**")
            st.dataframe(ctx, use_container_width=True)
        except Exception as e:
            st.error(f"Session error: {e}")
    
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
    """Render Cortex Analyst interface with native Snowflake Semantic Views"""
    st.markdown("""
    <div class="main-header">
        <h1>🤖 Cortex Analyst</h1>
        <p>Natural language queries powered by Snowflake Semantic Views</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Get semantic views
    sem_views = get_semantic_views()
    
    if not sem_views.empty:
        # View selector with friendly names
        view_options = sem_views['SEMANTIC_VIEW_NAME'].tolist()
        
        # Create friendly display names
        friendly_names = {
            'COST_ANALYTICS': '💰 Cost Analytics - Credits, queries, and warehouse usage',
            'SECURITY_ANALYTICS': '🔐 Security Analytics - Logins, users, and access patterns',
            'STORAGE_ANALYTICS': '📦 Storage Analytics - Database and table storage trends',
            'GOVERNANCE_ANALYTICS': '👥 Governance Analytics - Users, roles, and permissions'
        }
        
        display_options = [friendly_names.get(v, v) for v in view_options]
        selected_idx = st.selectbox(
            "Select Analysis Domain", 
            range(len(view_options)),
            format_func=lambda i: display_options[i]
        )
        selected_view = view_options[selected_idx]
        
        # Show view description
        view_info = sem_views[sem_views['SEMANTIC_VIEW_NAME'] == selected_view].iloc[0]
        if view_info['DESCRIPTION']:
            st.caption(view_info['DESCRIPTION'])
        
        st.divider()
        
        # Sample questions based on selected semantic view
        st.markdown("### 💡 Sample Questions")
        
        # Domain-specific sample questions
        if selected_view == 'COST_ANALYTICS':
            sample_questions = [
                "What are the total credits by warehouse?",
                "Which users run the most expensive queries?",
                "Show credit usage trend by month",
                "What is the average query duration by warehouse size?"
            ]
        elif selected_view == 'SECURITY_ANALYTICS':
            sample_questions = [
                "Show failed login attempts by user",
                "Which IP addresses have the most login failures?",
                "What percentage of users have MFA enabled?",
                "Show login patterns by client type"
            ]
        elif selected_view == 'STORAGE_ANALYTICS':
            sample_questions = [
                "Show storage growth trend over time",
                "Which databases use the most storage?",
                "What is the total failsafe storage?",
                "Show average daily storage by month"
            ]
        elif selected_view == 'GOVERNANCE_ANALYTICS':
            sample_questions = [
                "List all active users with their default roles",
                "Which users don't have MFA enabled?",
                "Show role assignments by owner",
                "How many users are disabled?"
            ]
        else:
            sample_questions = [
                "Show a summary of the data",
                "What are the key metrics?",
                "Show trends over time"
            ]
        
        cols = st.columns(2)
        for i, q in enumerate(sample_questions[:4]):
            with cols[i % 2]:
                if st.button(f"💬 {q}", key=f"sample_{i}", use_container_width=True):
                    st.session_state.cortex_question = q
        
        st.divider()
        
        # Question input
        question = st.text_input(
            "Ask a question in natural language",
            value=st.session_state.get('cortex_question', ''),
            placeholder=f"e.g., {sample_questions[0]}"
        )
        
        col1, col2 = st.columns([1, 4])
        with col1:
            ask_button = st.button("🚀 Ask Cortex", type="primary", use_container_width=True)
        
        if ask_button:
            if question:
                with st.spinner("Cortex Analyst is analyzing your question..."):
                    result, error = call_cortex_analyst(question, selected_view)
                    
                    if error:
                        st.error(error)
                    elif result:
                        # Show explanation if available
                        if result.get('explanation'):
                            st.info(result['explanation'])
                        
                        st.markdown("### Generated SQL")
                        st.code(result['sql'], language="sql")
                        
                        # Store the SQL for execution
                        st.session_state.generated_sql = result['sql']
                        st.session_state.show_execute = True
            else:
                st.warning("Please enter a question")
        
        # Execute button (persistent after generation)
        if st.session_state.get('show_execute') and st.session_state.get('generated_sql'):
            st.divider()
            if st.button("▶️ Execute Query", type="secondary"):
                with st.spinner("Running query..."):
                    df, sql_error = execute_sql(st.session_state.generated_sql)
                    if sql_error:
                        st.error(f"SQL Error: {sql_error}")
                    elif df is not None:
                        st.success(f"Returned {len(df)} rows")
                        st.dataframe(df, use_container_width=True)
                        
                        # Download option
                        csv = df.to_csv(index=False)
                        st.download_button(
                            "📥 Download CSV",
                            csv,
                            "cortex_results.csv",
                            "text/csv"
                        )
    else:
        st.warning("""
        **No Semantic Views Found**
        
        To enable Cortex Analyst, run the following in Snowflake:
        
        ```sql
        -- Run as DATA_ADMIN
        USE ROLE DATA_ADMIN;
        
        -- Execute the semantic layer script
        -- This creates native Snowflake Semantic Views
        ```
        
        See `sql/03_semantic_layer.sql` for the complete setup.
        """)

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

def get_task_schedule_info():
    """Get task schedule info including last/next run times"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT 
                NAME,
                STATE,
                SCHEDULE,
                LAST_COMMITTED_ON,
                -- Calculate next scheduled time based on CRON
                CASE 
                    WHEN NAME LIKE '%MORNING%' THEN 
                        CASE 
                            WHEN CURRENT_TIME() < '06:00:00' THEN 
                                CONVERT_TIMEZONE('America/New_York', CURRENT_TIMESTAMP())::DATE || ' 06:00:00'
                            ELSE 
                                DATEADD('day', 1, CONVERT_TIMEZONE('America/New_York', CURRENT_TIMESTAMP())::DATE) || ' 06:00:00'
                        END
                    WHEN NAME LIKE '%EVENING%' THEN 
                        CASE 
                            WHEN CURRENT_TIME() < '18:00:00' THEN 
                                CONVERT_TIMEZONE('America/New_York', CURRENT_TIMESTAMP())::DATE || ' 18:00:00'
                            ELSE 
                                DATEADD('day', 1, CONVERT_TIMEZONE('America/New_York', CURRENT_TIMESTAMP())::DATE) || ' 18:00:00'
                        END
                END AS NEXT_SCHEDULED_TIME_ET
            FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
                SCHEDULED_TIME_RANGE_START => DATEADD('day', -30, CURRENT_TIMESTAMP()),
                RESULT_LIMIT => 100
            ))
            WHERE DATABASE_NAME = 'TEMPORAL_ARCHIVE'
              AND SCHEMA_NAME = 'ARCHIVE'
              AND NAME IN ('TASK_SCD_LOAD_MORNING', 'TASK_SCD_LOAD_EVENING')
            QUALIFY ROW_NUMBER() OVER (PARTITION BY NAME ORDER BY SCHEDULED_TIME DESC) = 1
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

def get_task_status():
    """Get current task status with schedule parsing"""
    session = get_session()
    try:
        df = session.sql("""
            SHOW TASKS IN SCHEMA TEMPORAL_ARCHIVE.ARCHIVE
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

def get_last_load_info():
    """Get info about the last successful load"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT 
                LOAD_TIMESTAMP AS LAST_LOAD_TIME,
                ROWS_UPDATED,
                ROWS_INSERTED,
                STATUS,
                DURATION_SECONDS
            FROM TEMPORAL_ARCHIVE.ARCHIVE.LOAD_LOG
            ORDER BY LOAD_TIMESTAMP DESC
            LIMIT 1
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

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

def get_discovered_views_summary():
    """Get summary of discovered views and their archive status"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT 
                v.TABLE_SCHEMA AS SCHEMA_NAME,
                COUNT(v.TABLE_NAME) AS TOTAL_VIEWS,
                COUNT(t.TABLE_NAME) AS ARCHIVED_VIEWS,
                COUNT(v.TABLE_NAME) - COUNT(t.TABLE_NAME) AS PENDING_VIEWS
            FROM SNOWFLAKE.INFORMATION_SCHEMA.VIEWS v
            LEFT JOIN TEMPORAL_ARCHIVE.INFORMATION_SCHEMA.TABLES t
                ON t.TABLE_SCHEMA = v.TABLE_SCHEMA
                AND t.TABLE_NAME = v.TABLE_NAME || '_ARCHIVE'
            WHERE v.TABLE_SCHEMA IN ('ACCOUNT_USAGE', 'ORGANIZATION_USAGE')
            GROUP BY v.TABLE_SCHEMA
            ORDER BY v.TABLE_SCHEMA
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

def get_archive_table_list():
    """Get list of archive tables with row counts"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT 
                TABLE_SCHEMA,
                TABLE_NAME,
                ROW_COUNT,
                BYTES,
                CREATED
            FROM TEMPORAL_ARCHIVE.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_NAME LIKE '%_ARCHIVE'
            ORDER BY TABLE_SCHEMA, TABLE_NAME
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

def render_operations():
    """Render operations page with SCD load button and task schedule info"""
    st.markdown("""
    <div class="main-header">
        <h1>⚙️ Operations</h1>
        <p>Run SCD loads on demand and monitor task execution</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Task Schedule Status Section
    st.markdown("### 📅 Task Schedule Status")
    
    col_sched1, col_sched2, col_sched3 = st.columns(3)
    
    # Get last load info
    last_load = get_last_load_info()
    
    with col_sched1:
        st.markdown("""
        <div class="metric-card">
            <strong>⏰ Morning Task</strong>
            <div style="font-size: 1.2rem;">6:00 AM ET Daily</div>
            <small>TASK_SCD_LOAD_MORNING</small>
        </div>
        """, unsafe_allow_html=True)
    
    with col_sched2:
        st.markdown("""
        <div class="metric-card">
            <strong>🌙 Evening Task</strong>
            <div style="font-size: 1.2rem;">6:00 PM ET Daily</div>
            <small>TASK_SCD_LOAD_EVENING</small>
        </div>
        """, unsafe_allow_html=True)
    
    with col_sched3:
        if not last_load.empty:
            last_time = last_load.iloc[0]['LAST_LOAD_TIME']
            last_status = last_load.iloc[0]['STATUS']
            status_color = "#22C55E" if last_status == "SUCCESS" else "#EF4444"
            st.markdown(f"""
            <div class="metric-card">
                <strong>📊 Last Load</strong>
                <div style="font-size: 1rem;">{last_time}</div>
                <small style="color: {status_color};">{last_status}</small>
            </div>
            """, unsafe_allow_html=True)
        else:
            st.markdown("""
            <div class="metric-card">
                <strong>📊 Last Load</strong>
                <div style="font-size: 1rem;">No loads yet</div>
                <small>Run your first load below</small>
            </div>
            """, unsafe_allow_html=True)
    
    # Next scheduled runs based on current time
    # Uses pytz if available, otherwise falls back to UTC-based calculation
    
    try:
        if HAS_PYTZ:
            et_tz = pytz.timezone('America/New_York')
            now_et = datetime.now(et_tz)
        else:
            # Fallback: assume UTC-5 for ET (approximate)
            from datetime import timezone, timedelta
            et_offset = timezone(timedelta(hours=-5))
            now_et = datetime.now(et_offset)
            et_tz = et_offset
        
        today_et = now_et.date()
        
        morning_time = datetime.combine(today_et, dt_time(6, 0))
        evening_time = datetime.combine(today_et, dt_time(18, 0))
        
        if HAS_PYTZ:
            morning_time = et_tz.localize(morning_time)
            evening_time = et_tz.localize(evening_time)
        else:
            morning_time = morning_time.replace(tzinfo=et_tz)
            evening_time = evening_time.replace(tzinfo=et_tz)
        
        # Calculate next morning run
        if now_et.time() >= dt_time(6, 0):
            next_morning = morning_time + pd.Timedelta(days=1)
        else:
            next_morning = morning_time
        
        # Calculate next evening run
        if now_et.time() >= dt_time(18, 0):
            next_evening = evening_time + pd.Timedelta(days=1)
        else:
            next_evening = evening_time
        
        # Determine which is truly next
        if next_morning < next_evening:
            next_run = next_morning
            next_run_name = "Morning Load"
        else:
            next_run = next_evening
            next_run_name = "Evening Load"
        
        # Calculate time until next run
        time_until = next_run - now_et
        hours_until = int(time_until.total_seconds() // 3600)
        mins_until = int((time_until.total_seconds() % 3600) // 60)
        
        st.info(f"**Next Scheduled Run:** {next_run_name} at {next_run.strftime('%Y-%m-%d %H:%M')} ET (in {hours_until}h {mins_until}m)")
    except Exception as e:
        st.info("**Next Scheduled Run:** Morning (6 AM ET) or Evening (6 PM ET) - check task status below")
    
    st.divider()
    
    # SCD Load Section
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.markdown("### 🚀 Run SCD Load On Demand")
        st.markdown("""
        Click the button below to manually trigger an SCD Type 2 load. The process **dynamically discovers**
        ALL views from SNOWFLAKE.ACCOUNT_USAGE and SNOWFLAKE.ORGANIZATION_USAGE at runtime.
        
        **What happens:**
        - Queries SNOWFLAKE.INFORMATION_SCHEMA.VIEWS to discover all available views
        - Creates target archive tables automatically if they don't exist
        - Uses surrogate key (`_ARCHIVE_ID`) - no PK mappings needed
        - Uses row hash (`SHA2(OBJECT_CONSTRUCT(*))`) for change detection
        - Performs SCD Type 2 merge/insert for EVERY view
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
                    col_a, col_b, col_c, col_d, col_e = st.columns(5)
                    with col_a:
                        st.metric("Views Processed", result_dict.get('views_processed', 0))
                    with col_b:
                        st.metric("Successful", result_dict.get('success_count', 0))
                    with col_c:
                        st.metric("Rows Updated", result_dict.get('total_updated', 0))
                    with col_d:
                        st.metric("Rows Inserted", result_dict.get('total_inserted', 0))
                    with col_e:
                        st.metric("Errors", result_dict.get('error_count', 0))
                    
                    # Show detailed results
                    if 'table_results' in result_dict:
                        with st.expander("📋 Detailed Results", expanded=False):
                            st.json(result_dict['table_results'])
    
    with col2:
        st.markdown("### 📋 Quick Actions")
        
        if st.button("🔄 Refresh Page", use_container_width=True):
            st.cache_data.clear()
            st.rerun()
        
        st.markdown("---")
        
        # View discovery summary
        st.markdown("### 📊 View Discovery")
        summary = get_discovered_views_summary()
        if not summary.empty:
            for _, row in summary.iterrows():
                st.markdown(f"""
                **{row['SCHEMA_NAME']}**  
                {row['ARCHIVED_VIEWS']}/{row['TOTAL_VIEWS']} views archived
                """)
        else:
            st.info("Unable to load summary")
    
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
    
    # Archive Tables
    st.markdown("### 📦 Archive Tables")
    st.markdown("""
    All views are automatically discovered and archived using surrogate keys. 
    No PK mapping required - the system uses row hashing for change detection.
    """)
    
    archive_tables = get_archive_table_list()
    if not archive_tables.empty:
        # Add filter
        schema_filter = st.selectbox(
            "Filter by Schema",
            options=["All"] + list(archive_tables['TABLE_SCHEMA'].unique()),
            key="archive_schema_filter"
        )
        
        if schema_filter != "All":
            archive_tables = archive_tables[archive_tables['TABLE_SCHEMA'] == schema_filter]
        
        # Format bytes
        archive_tables['SIZE_MB'] = (archive_tables['BYTES'] / 1024 / 1024).round(2)
        display_df = archive_tables[['TABLE_SCHEMA', 'TABLE_NAME', 'ROW_COUNT', 'SIZE_MB', 'CREATED']]
        
        st.dataframe(display_df, use_container_width=True)
        st.caption(f"Showing {len(archive_tables)} archive tables")
    else:
        st.info("No archive tables found. Run SCD load to create them.")


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
