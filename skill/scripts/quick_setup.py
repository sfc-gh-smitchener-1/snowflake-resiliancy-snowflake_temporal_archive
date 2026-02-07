#!/usr/bin/env python3
"""
Temporal Archive Quick Setup

Generates parameterized SQL from templates based on user configuration.
Outputs SQL that can be run directly in Snowflake Worksheets.

Usage:
    python quick_setup.py                    # Interactive mode
    python quick_setup.py --config config.yaml  # Use config file
    python quick_setup.py --defaults         # Use all defaults
"""

import argparse
import os
import sys
import json
from pathlib import Path
from typing import Dict, Any

# Default configuration
DEFAULTS = {
    'database_name': 'TEMPORAL_ARCHIVE',
    'warehouse_name': 'TEMPORAL_ARCHIVE_WH',
    'warehouse_size': 'XSMALL',
    'warehouse_auto_suspend': '60',
    'warehouse_min_clusters': '1',
    'warehouse_max_clusters': '1',
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
    'backup_retention_days': '2555',
    'backup_schedule_minutes': '1440',
    'morning_load_hour': '6',
    'evening_load_hour': '18',
    'timezone': 'America/New_York',
    'agent_name': 'SNOWFLAKE_INTELLIGENCE',
    'agent_timeout_seconds': '900',
    'agent_token_budget': '400000',
    'query_timeout_seconds': '299',
    'streamlit_app_name': 'TEMPORAL_ARCHIVE_APP',
    'cortex_model': 'llama3.1-70b',
}


def get_template_vars(config: Dict[str, Any]) -> Dict[str, str]:
    """Build template variable mapping."""
    # Derive backup policy name
    backup_policy = config.get('backup_policy_name', 
                               f"{config['database_name']}_WORM_BACKUP_POLICY")
    
    return {
        '{{DATABASE_NAME}}': config['database_name'],
        '{{WAREHOUSE_NAME}}': config['warehouse_name'],
        '{{WAREHOUSE_SIZE}}': config['warehouse_size'],
        '{{WAREHOUSE_AUTO_SUSPEND}}': str(config['warehouse_auto_suspend']),
        '{{WAREHOUSE_MIN_CLUSTERS}}': str(config['warehouse_min_clusters']),
        '{{WAREHOUSE_MAX_CLUSTERS}}': str(config['warehouse_max_clusters']),
        '{{ADMIN_ROLE}}': config['admin_role'],
        '{{READER_ROLE}}': config['reader_role'],
        '{{WRITER_ROLE}}': config['writer_role'],
        '{{ARCHIVE_ADMIN_ROLE}}': config['archive_admin_role'],
        '{{ARCHIVE_SCHEMA}}': config['archive_schema'],
        '{{ACCOUNT_USAGE_SCHEMA}}': config['account_usage_schema'],
        '{{ORGANIZATION_USAGE_SCHEMA}}': config['organization_usage_schema'],
        '{{DATA_SHARING_SCHEMA}}': config['data_sharing_schema'],
        '{{READER_ACCOUNT_SCHEMA}}': config['reader_account_schema'],
        '{{SEMANTIC_SCHEMA}}': config['semantic_schema'],
        '{{AGENTS_SCHEMA}}': config['agents_schema'],
        '{{STREAMLIT_SCHEMA}}': config['streamlit_schema'],
        '{{BACKUP_POLICY_NAME}}': backup_policy,
        '{{BACKUP_RETENTION_DAYS}}': str(config['backup_retention_days']),
        '{{BACKUP_SCHEDULE_MINUTES}}': str(config['backup_schedule_minutes']),
        '{{MORNING_LOAD_HOUR}}': str(config['morning_load_hour']),
        '{{EVENING_LOAD_HOUR}}': str(config['evening_load_hour']),
        '{{TIMEZONE}}': config['timezone'],
        '{{AGENT_NAME}}': config['agent_name'],
        '{{AGENT_TIMEOUT_SECONDS}}': str(config['agent_timeout_seconds']),
        '{{AGENT_TOKEN_BUDGET}}': str(config['agent_token_budget']),
        '{{QUERY_TIMEOUT_SECONDS}}': str(config['query_timeout_seconds']),
        '{{STREAMLIT_APP_NAME}}': config['streamlit_app_name'],
        '{{CORTEX_MODEL}}': config['cortex_model'],
    }


def render_template(content: str, template_vars: Dict[str, str]) -> str:
    """Replace template variables in content."""
    result = content
    for var, value in template_vars.items():
        result = result.replace(var, value)
    return result


def interactive_config() -> Dict[str, Any]:
    """Gather configuration interactively."""
    print("\n" + "="*60)
    print("TEMPORAL ARCHIVE CONFIGURATION")
    print("="*60)
    print("\nPress Enter to accept defaults (shown in brackets)\n")
    
    config = {}
    
    # Core settings
    config['database_name'] = input(f"Database name [{DEFAULTS['database_name']}]: ").strip() or DEFAULTS['database_name']
    config['warehouse_name'] = input(f"Warehouse name [{DEFAULTS['warehouse_name']}]: ").strip() or DEFAULTS['warehouse_name']
    config['warehouse_size'] = input(f"Warehouse size [{DEFAULTS['warehouse_size']}]: ").strip() or DEFAULTS['warehouse_size']
    config['admin_role'] = input(f"Admin role [{DEFAULTS['admin_role']}]: ").strip() or DEFAULTS['admin_role']
    
    # Use remaining defaults
    for key, value in DEFAULTS.items():
        if key not in config:
            config[key] = value
    
    # Derived names
    config['reader_role'] = f"{config['database_name']}_READER"
    config['writer_role'] = f"{config['database_name']}_WRITER"
    config['archive_admin_role'] = f"{config['database_name']}_ADMIN"
    
    print("\n" + "-"*60)
    print("Configuration Summary:")
    print(f"  Database: {config['database_name']}")
    print(f"  Warehouse: {config['warehouse_name']} ({config['warehouse_size']})")
    print(f"  Admin Role: {config['admin_role']}")
    print(f"  Backup Retention: {config['backup_retention_days']} days")
    print(f"  Load Schedule: {config['morning_load_hour']}:00 and {config['evening_load_hour']}:00 ({config['timezone']})")
    print("-"*60 + "\n")
    
    return config


def main():
    parser = argparse.ArgumentParser(description='Generate Temporal Archive deployment SQL')
    parser.add_argument('--config', '-c', help='Path to config.yaml')
    parser.add_argument('--defaults', '-d', action='store_true', help='Use all defaults')
    parser.add_argument('--output', '-o', help='Output directory for generated SQL')
    parser.add_argument('--step', choices=['01', '02', '03', '04', 'all'], default='all',
                       help='Which step to generate (01=setup, 02=scd, 03=semantic, 04=streamlit)')
    
    args = parser.parse_args()
    
    # Determine configuration
    if args.config:
        try:
            import yaml
            with open(args.config, 'r') as f:
                config = yaml.safe_load(f)
            # Merge with defaults
            for key, value in DEFAULTS.items():
                if key not in config:
                    config[key] = value
        except ImportError:
            print("Error: PyYAML not installed. Run: pip install pyyaml")
            sys.exit(1)
    elif args.defaults:
        config = DEFAULTS.copy()
    else:
        config = interactive_config()
    
    # Get template variables
    template_vars = get_template_vars(config)
    
    # Find templates directory
    script_dir = Path(__file__).parent
    templates_dir = script_dir / 'templates'
    
    if not templates_dir.exists():
        templates_dir = script_dir.parent / 'skill' / 'templates'
    
    if not templates_dir.exists():
        print(f"Error: Templates directory not found")
        sys.exit(1)
    
    # Output directory
    output_dir = Path(args.output) if args.output else script_dir / 'generated'
    output_dir.mkdir(exist_ok=True)
    
    # Steps to generate
    steps = ['01', '02', '03', '04'] if args.step == 'all' else [args.step]
    
    print(f"\nGenerating SQL for database: {config['database_name']}")
    print(f"Output directory: {output_dir}\n")
    
    for step in steps:
        template_file = templates_dir / f"{step}_*.sql"
        # Find matching template
        import glob
        matches = list(templates_dir.glob(f"{step}_*.sql"))
        
        if not matches:
            print(f"Warning: No template found for step {step}")
            continue
        
        template_path = matches[0]
        output_path = output_dir / template_path.name
        
        print(f"Processing: {template_path.name}")
        
        with open(template_path, 'r') as f:
            content = f.read()
        
        rendered = render_template(content, template_vars)
        
        with open(output_path, 'w') as f:
            f.write(rendered)
        
        print(f"  → Generated: {output_path}")
    
    # Generate agent config
    agent_template = templates_dir / 'agent_config.json'
    if agent_template.exists():
        with open(agent_template, 'r') as f:
            content = f.read()
        rendered = render_template(content, template_vars)
        output_path = output_dir / 'agent_config.json'
        with open(output_path, 'w') as f:
            f.write(rendered)
        print(f"  → Generated: {output_path}")
    
    print(f"\n{'='*60}")
    print("DEPLOYMENT INSTRUCTIONS")
    print('='*60)
    print(f"""
1. Run the generated SQL scripts in order in a Snowflake Worksheet:
   - {output_dir}/01_initial_setup.sql  (as ACCOUNTADMIN)
   - {output_dir}/02_scd_load.sql       (as {config['admin_role']})
   - {output_dir}/03_semantic_layer.sql (as {config['admin_role']})
   - {output_dir}/04_streamlit_ddl.sql  (as {config['admin_role']})

2. Create the Cortex Agent using the REST API:
   - Config file: {output_dir}/agent_config.json
   - Use create_or_alter_agent.py or Cortex Code skill

3. Run initial data load:
   CALL {config['database_name']}.{config['archive_schema']}.RUN_SCD_LOAD();

4. Verify deployment:
   SHOW SEMANTIC VIEWS IN SCHEMA {config['database_name']}.{config['semantic_schema']};
   SHOW TASKS IN SCHEMA {config['database_name']}.{config['archive_schema']};
""")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
