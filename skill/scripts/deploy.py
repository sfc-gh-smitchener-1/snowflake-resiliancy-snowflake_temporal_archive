#!/usr/bin/env python3
"""
Temporal Archive Deployment Script

This script deploys the Temporal Archive solution to a Snowflake account.
It reads configuration from config.yaml and executes parameterized SQL scripts.

Usage:
    python deploy.py --config config.yaml --connection default
    python deploy.py --config config.yaml --connection default --dry-run
    python deploy.py --config config.yaml --connection default --step 01_initial_setup
"""

import argparse
import os
import re
import sys
import json
import yaml
from pathlib import Path
from typing import Dict, Any, Optional, List

# Try to import snowflake connector
try:
    import snowflake.connector
    from snowflake.connector import DictCursor
    HAS_SNOWFLAKE = True
except ImportError:
    HAS_SNOWFLAKE = False
    print("Warning: snowflake-connector-python not installed. Use --dry-run mode.")


class TemporalArchiveDeployer:
    """Deploys Temporal Archive to Snowflake with parameterized configuration."""
    
    # Deployment steps in order
    STEPS = [
        ("01_initial_setup", "Infrastructure Setup (database, warehouse, roles, backup policy)"),
        ("02_scd_load", "SCD Type 2 Load Infrastructure (procedures, tasks)"),
        ("03_semantic_layer", "Semantic Views for Cortex Analyst"),
        ("04_streamlit_ddl", "Streamlit Support Objects"),
        ("05_agent", "Cortex Intelligence Agent"),
    ]
    
    def __init__(self, config_path: str, connection_name: str = "default", dry_run: bool = False):
        self.config_path = config_path
        self.connection_name = connection_name
        self.dry_run = dry_run
        self.config: Dict[str, Any] = {}
        self.conn = None
        self.base_dir = Path(__file__).parent.parent
        
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file."""
        config_file = Path(self.config_path)
        if not config_file.exists():
            raise FileNotFoundError(f"Configuration file not found: {self.config_path}")
        
        with open(config_file, 'r') as f:
            self.config = yaml.safe_load(f)
        
        # Set defaults
        defaults = {
            'database_name': 'TEMPORAL_ARCHIVE',
            'warehouse_name': 'TEMPORAL_ARCHIVE_WH',
            'warehouse_size': 'XSMALL',
            'warehouse_auto_suspend_seconds': 60,
            'warehouse_min_clusters': 1,
            'warehouse_max_clusters': 1,
            'admin_role': 'DATA_ADMIN',
            'reader_role': 'TEMPORAL_ARCHIVE_READER',
            'writer_role': 'TEMPORAL_ARCHIVE_WRITER',
            'archive_admin_role': 'TEMPORAL_ARCHIVE_ADMIN',
            'archive_schema': 'ARCHIVE',
            'account_usage_schema': 'ACCOUNT_USAGE',
            'organization_usage_schema': 'ORGANIZATION_USAGE',
            'data_sharing_schema': 'DATA_SHARING_USAGE',
            'reader_account_schema': 'READER_ACCOUNT_USAGE',
            'semantic_schema': 'SEMANTIC',
            'agents_schema': 'AGENTS',
            'streamlit_schema': 'STREAMLIT',
            'backup_retention_days': 2555,
            'backup_schedule_minutes': 1440,
            'morning_load_hour': 6,
            'evening_load_hour': 18,
            'timezone': 'America/New_York',
            'agent_name': 'SNOWFLAKE_INTELLIGENCE',
            'agent_timeout_seconds': 900,
            'agent_token_budget': 400000,
            'query_timeout_seconds': 299,
            'streamlit_app_name': 'TEMPORAL_ARCHIVE_APP',
            'cortex_model': 'llama3.1-70b',
        }
        
        for key, value in defaults.items():
            if key not in self.config:
                self.config[key] = value
        
        # Derive backup policy name if not set
        if 'backup_policy_name' not in self.config:
            self.config['backup_policy_name'] = f"{self.config['database_name']}_WORM_BACKUP_POLICY"
        
        return self.config
    
    def get_template_vars(self) -> Dict[str, str]:
        """Get template variables for SQL substitution."""
        return {
            '{{DATABASE_NAME}}': self.config['database_name'],
            '{{WAREHOUSE_NAME}}': self.config['warehouse_name'],
            '{{WAREHOUSE_SIZE}}': self.config['warehouse_size'],
            '{{WAREHOUSE_AUTO_SUSPEND}}': str(self.config['warehouse_auto_suspend_seconds']),
            '{{WAREHOUSE_MIN_CLUSTERS}}': str(self.config['warehouse_min_clusters']),
            '{{WAREHOUSE_MAX_CLUSTERS}}': str(self.config['warehouse_max_clusters']),
            '{{ADMIN_ROLE}}': self.config['admin_role'],
            '{{READER_ROLE}}': self.config['reader_role'],
            '{{WRITER_ROLE}}': self.config['writer_role'],
            '{{ARCHIVE_ADMIN_ROLE}}': self.config['archive_admin_role'],
            '{{ARCHIVE_SCHEMA}}': self.config['archive_schema'],
            '{{ACCOUNT_USAGE_SCHEMA}}': self.config['account_usage_schema'],
            '{{ORGANIZATION_USAGE_SCHEMA}}': self.config['organization_usage_schema'],
            '{{DATA_SHARING_SCHEMA}}': self.config['data_sharing_schema'],
            '{{READER_ACCOUNT_SCHEMA}}': self.config['reader_account_schema'],
            '{{SEMANTIC_SCHEMA}}': self.config['semantic_schema'],
            '{{AGENTS_SCHEMA}}': self.config['agents_schema'],
            '{{STREAMLIT_SCHEMA}}': self.config['streamlit_schema'],
            '{{BACKUP_POLICY_NAME}}': self.config['backup_policy_name'],
            '{{BACKUP_RETENTION_DAYS}}': str(self.config['backup_retention_days']),
            '{{BACKUP_SCHEDULE_MINUTES}}': str(self.config['backup_schedule_minutes']),
            '{{MORNING_LOAD_HOUR}}': str(self.config['morning_load_hour']),
            '{{EVENING_LOAD_HOUR}}': str(self.config['evening_load_hour']),
            '{{TIMEZONE}}': self.config['timezone'],
            '{{AGENT_NAME}}': self.config['agent_name'],
            '{{AGENT_TIMEOUT_SECONDS}}': str(self.config['agent_timeout_seconds']),
            '{{AGENT_TOKEN_BUDGET}}': str(self.config['agent_token_budget']),
            '{{QUERY_TIMEOUT_SECONDS}}': str(self.config['query_timeout_seconds']),
            '{{STREAMLIT_APP_NAME}}': self.config['streamlit_app_name'],
            '{{CORTEX_MODEL}}': self.config['cortex_model'],
        }
    
    def render_template(self, sql_content: str) -> str:
        """Replace template variables in SQL content."""
        template_vars = self.get_template_vars()
        result = sql_content
        for var, value in template_vars.items():
            result = result.replace(var, value)
        return result
    
    def connect(self):
        """Establish Snowflake connection."""
        if not HAS_SNOWFLAKE:
            raise RuntimeError("snowflake-connector-python not installed")
        
        # Try to get connection from cortex config
        cortex_config_path = Path.home() / ".config" / "cortex" / "connections.yaml"
        
        if cortex_config_path.exists():
            with open(cortex_config_path, 'r') as f:
                connections = yaml.safe_load(f)
            
            if self.connection_name in connections:
                conn_config = connections[self.connection_name]
                self.conn = snowflake.connector.connect(
                    account=conn_config.get('account'),
                    user=conn_config.get('user'),
                    password=conn_config.get('password', ''),
                    authenticator=conn_config.get('authenticator', 'externalbrowser'),
                    warehouse=conn_config.get('warehouse'),
                    database=conn_config.get('database'),
                    role=conn_config.get('role'),
                )
                return
        
        # Fallback to environment variables
        self.conn = snowflake.connector.connect(
            account=os.environ.get('SNOWFLAKE_ACCOUNT'),
            user=os.environ.get('SNOWFLAKE_USER'),
            password=os.environ.get('SNOWFLAKE_PASSWORD', ''),
            authenticator=os.environ.get('SNOWFLAKE_AUTHENTICATOR', 'externalbrowser'),
        )
    
    def execute_sql(self, sql: str, description: str = "") -> List[Dict]:
        """Execute SQL statement and return results."""
        if self.dry_run:
            print(f"\n-- DRY RUN: {description}")
            print(sql[:500] + "..." if len(sql) > 500 else sql)
            return []
        
        if not self.conn:
            self.connect()
        
        cursor = self.conn.cursor(DictCursor)
        try:
            # Split on semicolons but handle $$ blocks
            statements = self._split_sql_statements(sql)
            results = []
            for stmt in statements:
                stmt = stmt.strip()
                if stmt and not stmt.startswith('--'):
                    cursor.execute(stmt)
                    try:
                        results.extend(cursor.fetchall())
                    except:
                        pass  # Statement didn't return results
            return results
        finally:
            cursor.close()
    
    def _split_sql_statements(self, sql: str) -> List[str]:
        """Split SQL into statements, handling $$ blocks."""
        # Simple approach: split on ; but not within $$ blocks
        statements = []
        current = ""
        in_dollar_block = False
        
        lines = sql.split('\n')
        for line in lines:
            if '$$' in line:
                if in_dollar_block:
                    current += line + '\n'
                    in_dollar_block = False
                    # End of procedure/function
                    if ';' in line.split('$$')[-1]:
                        statements.append(current)
                        current = ""
                else:
                    in_dollar_block = True
                    current += line + '\n'
            elif in_dollar_block:
                current += line + '\n'
            else:
                current += line + '\n'
                if ';' in line and not line.strip().startswith('--'):
                    statements.append(current)
                    current = ""
        
        if current.strip():
            statements.append(current)
        
        return statements
    
    def read_sql_template(self, filename: str) -> str:
        """Read SQL template from templates directory."""
        template_path = self.base_dir / "skill" / "templates" / filename
        if template_path.exists():
            with open(template_path, 'r') as f:
                return f.read()
        
        # Fall back to sql directory
        sql_path = self.base_dir / "sql" / filename
        if sql_path.exists():
            with open(sql_path, 'r') as f:
                return f.read()
        
        raise FileNotFoundError(f"SQL template not found: {filename}")
    
    def deploy_step(self, step_name: str) -> bool:
        """Deploy a single step."""
        print(f"\n{'='*60}")
        print(f"Deploying: {step_name}")
        print('='*60)
        
        try:
            if step_name == "01_initial_setup":
                return self._deploy_initial_setup()
            elif step_name == "02_scd_load":
                return self._deploy_scd_load()
            elif step_name == "03_semantic_layer":
                return self._deploy_semantic_layer()
            elif step_name == "04_streamlit_ddl":
                return self._deploy_streamlit()
            elif step_name == "05_agent":
                return self._deploy_agent()
            else:
                print(f"Unknown step: {step_name}")
                return False
        except Exception as e:
            print(f"ERROR: {e}")
            return False
    
    def _deploy_initial_setup(self) -> bool:
        """Deploy initial infrastructure."""
        sql = self.read_sql_template("01_initial_setup.sql")
        rendered = self.render_template(sql)
        self.execute_sql(rendered, "Initial Setup")
        print("✓ Infrastructure deployed")
        return True
    
    def _deploy_scd_load(self) -> bool:
        """Deploy SCD Type 2 load infrastructure."""
        sql = self.read_sql_template("02_scd_load.sql")
        rendered = self.render_template(sql)
        self.execute_sql(rendered, "SCD Load Infrastructure")
        print("✓ SCD load procedures and tasks deployed")
        return True
    
    def _deploy_semantic_layer(self) -> bool:
        """Deploy semantic views."""
        sql = self.read_sql_template("03_semantic_layer.sql")
        rendered = self.render_template(sql)
        self.execute_sql(rendered, "Semantic Views")
        print("✓ Semantic views deployed")
        return True
    
    def _deploy_streamlit(self) -> bool:
        """Deploy Streamlit support objects."""
        sql = self.read_sql_template("04_streamlit_ddl.sql")
        rendered = self.render_template(sql)
        self.execute_sql(rendered, "Streamlit Support")
        print("✓ Streamlit support objects deployed")
        return True
    
    def _deploy_agent(self) -> bool:
        """Deploy Cortex Intelligence Agent."""
        # Read agent config template
        agent_config_path = self.base_dir / "agent" / "snowflake_intelligence_agent.json"
        if not agent_config_path.exists():
            print("Warning: Agent config not found, skipping agent deployment")
            return True
        
        with open(agent_config_path, 'r') as f:
            agent_config = json.load(f)
        
        # Update config with parameterized values
        db = self.config['database_name']
        schema = self.config['semantic_schema']
        wh = self.config['warehouse_name']
        
        # Update tool_resources with correct database/schema/warehouse
        for tool_name, resource in agent_config.get('tool_resources', {}).items():
            if 'semantic_view' in resource:
                # Replace TEMPORAL_ARCHIVE.SEMANTIC with configured values
                old_view = resource['semantic_view']
                view_name = old_view.split('.')[-1]  # Get just the view name
                resource['semantic_view'] = f"{db}.{schema}.{view_name}"
            if 'execution_environment' in resource:
                resource['execution_environment']['warehouse'] = wh
        
        # Create the agent using SQL
        agent_spec_json = json.dumps(agent_config, indent=2)
        
        # Create agent schema if not exists
        sql = f"""
        CREATE SCHEMA IF NOT EXISTS {db}.{self.config['agents_schema']};
        GRANT USAGE ON SCHEMA {db}.{self.config['agents_schema']} TO ROLE {self.config['admin_role']};
        GRANT CREATE AGENT ON SCHEMA {db}.{self.config['agents_schema']} TO ROLE {self.config['admin_role']};
        """
        self.execute_sql(sql, "Create agents schema")
        
        print(f"✓ Agent schema created: {db}.{self.config['agents_schema']}")
        print(f"Note: Agent creation requires REST API - use the agent spec at:")
        print(f"  {agent_config_path}")
        print(f"  Run: cortex agent create --config agent/snowflake_intelligence_agent.json")
        return True
    
    def deploy_all(self) -> bool:
        """Deploy all steps in order."""
        print("\n" + "="*60)
        print("TEMPORAL ARCHIVE DEPLOYMENT")
        print("="*60)
        print(f"Configuration: {self.config_path}")
        print(f"Connection: {self.connection_name}")
        print(f"Database: {self.config['database_name']}")
        print(f"Warehouse: {self.config['warehouse_name']}")
        print(f"Dry Run: {self.dry_run}")
        print("="*60)
        
        features = self.config.get('features', {})
        
        for step_name, description in self.STEPS:
            # Check if step should be skipped based on features
            if step_name == "03_semantic_layer" and not features.get('create_semantic_views', True):
                print(f"\nSkipping {step_name} (disabled in config)")
                continue
            if step_name == "04_streamlit_ddl" and not features.get('create_streamlit_objects', True):
                print(f"\nSkipping {step_name} (disabled in config)")
                continue
            if step_name == "05_agent" and not features.get('create_agent', True):
                print(f"\nSkipping {step_name} (disabled in config)")
                continue
            
            success = self.deploy_step(step_name)
            if not success:
                print(f"\nDeployment failed at step: {step_name}")
                return False
        
        print("\n" + "="*60)
        print("✓ DEPLOYMENT COMPLETE")
        print("="*60)
        
        # Run initial load if configured
        if features.get('run_initial_load', True) and not self.dry_run:
            print("\nRunning initial SCD load...")
            self.execute_sql(
                f"CALL {self.config['database_name']}.{self.config['archive_schema']}.RUN_SCD_LOAD();",
                "Initial SCD Load"
            )
            print("✓ Initial load complete")
        
        return True
    
    def close(self):
        """Close connection."""
        if self.conn:
            self.conn.close()


def main():
    parser = argparse.ArgumentParser(description="Deploy Temporal Archive to Snowflake")
    parser.add_argument('--config', '-c', required=True, help='Path to config.yaml')
    parser.add_argument('--connection', default='default', help='Snowflake connection name')
    parser.add_argument('--dry-run', action='store_true', help='Print SQL without executing')
    parser.add_argument('--step', help='Deploy only a specific step')
    parser.add_argument('--list-steps', action='store_true', help='List available deployment steps')
    
    args = parser.parse_args()
    
    if args.list_steps:
        print("Available deployment steps:")
        for step_name, description in TemporalArchiveDeployer.STEPS:
            print(f"  {step_name}: {description}")
        return 0
    
    deployer = TemporalArchiveDeployer(
        config_path=args.config,
        connection_name=args.connection,
        dry_run=args.dry_run
    )
    
    try:
        deployer.load_config()
        
        if args.step:
            success = deployer.deploy_step(args.step)
        else:
            success = deployer.deploy_all()
        
        return 0 if success else 1
    
    except Exception as e:
        print(f"ERROR: {e}")
        return 1
    
    finally:
        deployer.close()


if __name__ == "__main__":
    sys.exit(main())
