# ksr-cli Scripts

This directory contains utility scripts for working with Kafka Schema Registry using ksr-cli.

## Available Scripts

### compare-contexts.sh

A comprehensive script for comparing contexts between Schema Registry instances with detailed reporting.

**Features:**
- Subject-by-subject comparison
- Multiple output formats (text, JSON, HTML)
- Authentication support (basic auth and API keys)
- Detailed schema difference detection
- Compatibility setting comparison
- Version tracking
- Colored terminal output
- Exit codes for CI/CD integration

**Usage:**
```bash
# Basic usage
./compare-contexts.sh \
  --source-registry http://dev-registry:8081 \
  --target-registry http://prod-registry:8081

# With different contexts
./compare-contexts.sh \
  -s http://registry:8081 \
  -t http://registry:8081 \
  -sc development \
  -tc production

# With authentication
./compare-contexts.sh \
  -s http://dev-registry:8081 \
  -t http://prod-registry:8081 \
  -sa "dev-user:dev-pass" \
  -ta "prod-api-key"

# Generate HTML report
./compare-contexts.sh \
  -s http://dev-registry:8081 \
  -t http://prod-registry:8081 \
  -o html \
  -f comparison-report.html

# JSON output with detailed comparison
./compare-contexts.sh \
  -s http://dev-registry:8081 \
  -t http://prod-registry:8081 \
  -o json \
  -d \
  -f comparison.json
```

**Options:**
- `-s, --source-registry URL` - Source registry URL (required)
- `-t, --target-registry URL` - Target registry URL (required)
- `-sc, --source-context NAME` - Source context (default: ".")
- `-tc, --target-context NAME` - Target context (default: ".")
- `-sa, --source-auth AUTH` - Source authentication (user:pass or api-key)
- `-ta, --target-auth AUTH` - Target authentication (user:pass or api-key)
- `-o, --output FORMAT` - Output format: text, json, html (default: text)
- `-f, --output-file FILE` - Output file (default: stdout)
- `-d, --detailed` - Show detailed schema differences
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message

### compare-contexts-quick.sh

A simplified script for quick context comparison with minimal configuration.

**Features:**
- Simple command-line interface
- Quick overview of differences
- Colored terminal output
- Suitable for quick checks and CI/CD pipelines

**Usage:**
```bash
# Compare contexts in different registries
./compare-contexts-quick.sh http://dev-registry:8081 http://prod-registry:8081

# Compare different contexts in the same registry
./compare-contexts-quick.sh http://registry:8081 http://registry:8081 dev prod

# Use with CI/CD (exit code indicates differences)
if ./compare-contexts-quick.sh http://dev:8081 http://prod:8081; then
  echo "Contexts are identical"
else
  echo "Differences found"
  exit 1
fi
```

### migrate-with-ids.sh

A script for migrating schemas while preserving schema IDs and version numbers using IMPORT mode.

**Features:**
- Preserves schema IDs across migrations
- Maintains version history
- Automatic IMPORT mode management
- Backup creation before migration
- Dry-run mode for testing
- Force mode for overwriting
- Support for single or all subjects
- Authentication support

**Usage:**
```bash
# Migrate all subjects preserving IDs
./migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081

# Migrate specific subject
./migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --subject user-events

# With authentication
./migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --source-auth "user:password" \
  --target-auth "api-key"

# Dry run to see what would be migrated
./migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --dry-run

# Force overwrite existing subjects
./migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --force
```

**Options:**
- `-s, --source-registry URL` - Source registry URL (required)
- `-t, --target-registry URL` - Target registry URL (required)
- `-sc, --source-context NAME` - Source context (default: ".")
- `-tc, --target-context NAME` - Target context (default: ".")
- `-sa, --source-auth AUTH` - Source auth (user:pass or api-key)
- `-ta, --target-auth AUTH` - Target auth (user:pass or api-key)
- `-sub, --subject SUBJECT` - Specific subject to migrate (optional, default: all)
- `-d, --dry-run` - Show what would be migrated without making changes
- `-f, --force` - Force migration even if subject exists in target
- `-b, --backup-dir DIR` - Directory to store backups (default: ./migration-backups)
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message

### migrate-schemas-from-list.sh

A wrapper script around `migrate-with-ids.sh` that migrates specific schemas from a text file list, with validation and error handling.

**Features:**
- Reads schema list from a text file (one schema per line)
- Validates schema existence in source registry before migration
- Continues processing on validation errors with warnings
- Filters out comments and empty lines
- Removes duplicate entries automatically
- Detailed reporting of successful, failed, and skipped migrations
- Supports all migrate-with-ids.sh options

**Usage:**
```bash
# Create a schemas list file
cat > my-schemas.txt << EOF
user-events
product-catalog
order-processing
payment-notifications
# This is a comment - will be ignored
inventory-updates
EOF

# Migrate schemas from the list
./migrate-schemas-from-list.sh \
  --schemas my-schemas.txt \
  --source-registry http://source:8081 \
  --target-registry http://target:8081

# With authentication and dry-run
./migrate-schemas-from-list.sh \
  --schemas my-schemas.txt \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --source-auth "user:password" \
  --target-auth "api-key" \
  --dry-run \
  --verbose

# With force mode and custom backup directory
./migrate-schemas-from-list.sh \
  --schemas critical-schemas.txt \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --force \
  --backup-dir /backups/critical-migration
```

**Schema List File Format:**
```txt
# Comments start with # and are ignored
user-events
product-catalog
order-processing

# Empty lines are ignored too
payment-notifications
inventory-updates
```

**Options:**
- `--schemas FILE` - Text file containing list of schemas (one per line) (required)
- `-s, --source-registry URL` - Source registry URL (required)
- `-t, --target-registry URL` - Target registry URL (required)
- `-sc, --source-context NAME` - Source context (default: ".")
- `-tc, --target-context NAME` - Target context (default: ".")
- `-sa, --source-auth AUTH` - Source auth (user:pass or api-key)
- `-ta, --target-auth AUTH` - Target auth (user:pass or api-key)
- `-d, --dry-run` - Show what would be migrated without making changes
- `-f, --force` - Force migration even if subject exists in target
- `-b, --backup-dir DIR` - Directory to store backups (default: ./migration-backups)
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message

## Installation

1. Make scripts executable:
```bash
chmod +x scripts/*.sh
```

2. Ensure dependencies are installed:
- ksr-cli
- jq
- bash 4.0+
- curl (for migrate-with-ids.sh)
- comm, sort, grep (standard Unix tools)

## Use Cases

### 1. Pre-deployment Validation

Validate that development schemas match production before deployment:

```bash
./compare-contexts.sh \
  -s http://dev-registry:8081 \
  -t http://prod-registry:8081 \
  -o json \
  -f pre-deployment-check.json

if [[ $? -ne 0 ]]; then
  echo "Schema differences detected. Review pre-deployment-check.json"
  exit 1
fi
```

### 2. Disaster Recovery Setup

Set up a disaster recovery site with identical schema IDs:

```bash
# Initial setup - migrate all schemas preserving IDs
./migrate-with-ids.sh \
  --source-registry http://primary:8081 \
  --target-registry http://dr-site:8081 \
  --backup-dir /backup/dr-setup

# Verify migration
./compare-contexts.sh \
  --source-registry http://primary:8081 \
  --target-registry http://dr-site:8081 \
  --detailed
```

### 3. Regular Sync Monitoring

Schedule regular comparisons to detect schema drift:

```bash
#!/bin/bash
# cron job: 0 */6 * * * /path/to/monitor-schema-sync.sh

REPORT_DIR="/var/log/schema-registry/sync-reports"
mkdir -p "$REPORT_DIR"

./compare-contexts.sh \
  -s http://primary:8081 \
  -t http://secondary:8081 \
  -o html \
  -f "$REPORT_DIR/sync-report-$(date +%Y%m%d-%H%M%S).html"

if [[ $? -ne 0 ]]; then
  # Send alert
  mail -s "Schema Registry Sync Alert" admin@example.com < "$REPORT_DIR/latest.html"
fi
```

### 4. Multi-Environment Comparison

Compare schemas across multiple environments:

```bash
#!/bin/bash
ENVIRONMENTS=("dev" "staging" "prod")
BASE_URL="http://registry:8081"

for i in "${!ENVIRONMENTS[@]}"; do
  for j in "${!ENVIRONMENTS[@]}"; do
    if [[ $i -lt $j ]]; then
      echo "Comparing ${ENVIRONMENTS[$i]} vs ${ENVIRONMENTS[$j]}"
      ./compare-contexts-quick.sh \
        "$BASE_URL" "$BASE_URL" \
        "${ENVIRONMENTS[$i]}" "${ENVIRONMENTS[$j]}"
      echo
    fi
  done
done
```

### 5. Environment Cloning

Clone an entire environment with preserved IDs:

```bash
#!/bin/bash
# Clone production to a new test environment

SOURCE_ENV="http://prod-registry:8081"
TARGET_ENV="http://test-registry:8081"

# First, check what will be migrated
./migrate-with-ids.sh \
  --source-registry "$SOURCE_ENV" \
  --target-registry "$TARGET_ENV" \
  --dry-run

read -p "Proceed with migration? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  ./migrate-with-ids.sh \
    --source-registry "$SOURCE_ENV" \
    --target-registry "$TARGET_ENV" \
    --backup-dir /backup/env-clone-$(date +%Y%m%d)
fi
```

### 6. Selective Schema Migration

Migrate only specific critical schemas from a curated list:

```bash
#!/bin/bash
# selective-migration.sh - Migrate only critical production schemas

# Create list of critical schemas
cat > critical-schemas.txt << EOF
# Core business events
user-registration-events
order-processing-events
payment-events
inventory-updates

# Integration schemas
external-api-requests
webhook-notifications
audit-events
EOF

# First, do a dry run to verify what will be migrated
echo "=== DRY RUN - Critical Schemas Migration ==="
./migrate-schemas-from-list.sh \
  --schemas critical-schemas.txt \
  --source-registry http://prod-registry:8081 \
  --target-registry http://dr-registry:8081 \
  --source-auth "$PROD_API_KEY" \
  --target-auth "$DR_API_KEY" \
  --dry-run \
  --verbose

# Ask for confirmation
read -p "Proceed with migration? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "=== EXECUTING - Critical Schemas Migration ==="
  ./migrate-schemas-from-list.sh \
    --schemas critical-schemas.txt \
    --source-registry http://prod-registry:8081 \
    --target-registry http://dr-registry:8081 \
    --source-auth "$PROD_API_KEY" \
    --target-auth "$DR_API_KEY" \
    --backup-dir /backup/critical-migration-$(date +%Y%m%d) \
    --verbose
    
  # Verify migration success
  echo "=== VERIFICATION - Comparing migrated schemas ==="
  for schema in $(grep -v '^#' critical-schemas.txt | grep -v '^[[:space:]]*$'); do
    echo "Verifying $schema..."
    ./compare-contexts.sh \
      -s http://prod-registry:8081 \
      -t http://dr-registry:8081 \
      -sa "$PROD_API_KEY" \
      -ta "$DR_API_KEY" \
      -o json | jq -r ".subjects[\"$schema\"].status"
  done
fi
```

### 7. Generate Comparison Matrix

Create a comprehensive comparison matrix:

```bash
#!/bin/bash
# generate-comparison-matrix.sh

REGISTRIES=(
  "dev|http://dev:8081|dev-api-key"
  "staging|http://staging:8081|staging-api-key"
  "prod|http://prod:8081|prod-api-key"
)

OUTPUT_DIR="comparison-matrix-$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

for source in "${REGISTRIES[@]}"; do
  IFS='|' read -r src_name src_url src_auth <<< "$source"
  
  for target in "${REGISTRIES[@]}"; do
    IFS='|' read -r tgt_name tgt_url tgt_auth <<< "$target"
    
    if [[ "$src_name" != "$tgt_name" ]]; then
      echo "Comparing $src_name → $tgt_name"
      
      ./compare-contexts.sh \
        -s "$src_url" \
        -t "$tgt_url" \
        -sa "$src_auth" \
        -ta "$tgt_auth" \
        -o json \
        -f "$OUTPUT_DIR/${src_name}-to-${tgt_name}.json"
    fi
  done
done

# Generate summary report
echo "Generating summary..."
jq -s '.[0] as $results | 
  {summary: {comparisons: length, 
   total_differences: [.[] | .summary.different + .summary.missing_in_target + .summary.missing_in_source] | add}}' \
  "$OUTPUT_DIR"/*.json > "$OUTPUT_DIR/summary.json"
```

## Output Examples

### Text Output (Default)
```
Schema Registry Context Comparison Report
=========================================
Generated: Mon Jun 16 12:00:00 UTC 2025

Source Registry: http://dev-registry:8081 (context: .)
Target Registry: http://prod-registry:8081 (context: .)

Subjects only in source (2):
  - test-subject-1
  - test-subject-2

Common subjects comparison:
  user-events: ✓
    Source version: 3 (total versions: 3)
    Target version: 3 (total versions: 3)
    
  order-events: ✗
    Source version: 5 (total versions: 5)
    Target version: 4 (total versions: 4)
    Compatibility differs: NONE → BACKWARD
    Schema differences detected

Summary:
Total subjects compared: 10
  Identical: 7
  Different: 1
  Missing in target: 2
  Missing in source: 0
```

### JSON Output
```json
{
  "comparison": {
    "source": {
      "registry": "http://dev-registry:8081",
      "context": "."
    },
    "target": {
      "registry": "http://prod-registry:8081",
      "context": "."
    },
    "summary": {
      "total_subjects": 10,
      "identical": 7,
      "different": 1,
      "missing_in_target": 2,
      "missing_in_source": 0,
      "timestamp": "2025-06-16T12:00:00Z"
    },
    "subjects": {
      "user-events": {
        "status": "identical",
        "source_version": "3",
        "target_version": "3",
        "source_compatibility": "BACKWARD",
        "target_compatibility": "BACKWARD"
      }
    }
  }
}
```

### Migration Output
```
Schema Migration with ID Preservation
====================================
Source: http://source:8081 (context: .)
Target: http://target:8081 (context: .)

Testing connections...
  Source: ✓
  Target: ✓

Checking registry modes...
  Source mode: READWRITE
  Target mode: READWRITE

Target registry is not in IMPORT mode
Setting target registry to IMPORT mode to preserve schema IDs...

Backup directory: ./migration-backups/migration-20250616-120000

Getting subjects to migrate...
Found 5 subject(s) to migrate

Migrating subject: user-events
  Setting compatibility: FULL
  Version 1 (ID: 1001, Type: AVRO)
    ✓ Successfully registered with ID 1001
  Version 2 (ID: 1002, Type: AVRO)
    ✓ Successfully registered with ID 1002
  ✓ Subject migration complete

Restoring target registry mode to READWRITE

====================================
Migration Summary
====================================
Total subjects: 5
  Successful: 5
  Failed: 0

Backup location: ./migration-backups/migration-20250616-120000
```

### List Migration Output
```
Schema Migration from List
=========================
Schemas file: my-schemas.txt
Source: http://source:8081 (context: .)
Target: http://target:8081 (context: .)

Found 6 schema(s) to process from file

Processing schema: user-events
  ✓ Schema exists in source registry
  ✓ Migration successful

Processing schema: product-catalog
  ✓ Schema exists in source registry
  ✓ Migration successful

Processing schema: non-existent-schema
  ⚠ Warning: Schema 'non-existent-schema' does not exist in source registry - skipping

Processing schema: order-processing
  ✓ Schema exists in source registry
  ✓ Migration successful

=========================
Migration Summary
=========================
Total schemas in file: 6
  Successful migrations: 3
  Failed migrations: 0
  Skipped (not found): 1

Skipped schemas (not found in source):
non-existent-schema
```

## Tips and Best Practices

1. **Use verbose mode** for troubleshooting:
   ```bash
   ./compare-contexts.sh -s http://dev:8081 -t http://prod:8081 -v
   ./migrate-with-ids.sh -s http://source:8081 -t http://target:8081 -v
   ```

2. **Save reports** for historical tracking:
   ```bash
   REPORT_DATE=$(date +%Y%m%d-%H%M%S)
   ./compare-contexts.sh ... -f "reports/comparison-$REPORT_DATE.html"
   ```

3. **Use exit codes** in automation:
   - Exit code 0: Success (contexts identical or migration successful)
   - Exit code 1: Failure (differences found or migration failed)

4. **Always test migrations** with dry-run first:
   ```bash
   ./migrate-with-ids.sh ... --dry-run
   ./migrate-schemas-from-list.sh ... --dry-run
   ```

5. **Monitor specific subjects**:
   ```bash
   # Check if specific critical subjects are in sync
   ./compare-contexts.sh ... -o json | jq '.subjects["critical-events"].status'
   ```

6. **Backup before migration**:
   - migrate-with-ids.sh and migrate-schemas-from-list.sh automatically create backups
   - Store backups in a safe location
   - Test restore procedures

7. **Validate schema lists** before migration:
   ```bash
   # Check which schemas from your list exist in source
   ./migrate-schemas-from-list.sh --schemas my-list.txt ... --dry-run
   
   # Create schema lists dynamically
   ksr-cli subjects list --registry-url http://source:8081 | grep "^user-" > user-schemas.txt
   ```

## Security Best Practices

1. **Protect credentials**:
   ```bash
   # Use environment variables
   export SOURCE_AUTH="api-key-here"
   export TARGET_AUTH="api-key-here"
   
   ./migrate-with-ids.sh \
     --source-auth "$SOURCE_AUTH" \
     --target-auth "$TARGET_AUTH" ...
   ```

2. **Limit IMPORT mode exposure**:
   - Only use IMPORT mode during migrations
   - migrate-with-ids.sh automatically restores original mode
   - Monitor mode changes in production

3. **Audit migrations**:
   - Keep migration logs and backups
   - Document who performed migrations and when
   - Verify migrations with comparison scripts

## Contributing

When adding new scripts:
1. Include comprehensive help/usage information
2. Use consistent error handling and exit codes
3. Support common authentication methods
4. Provide examples in this README
5. Test with various Schema Registry configurations
6. Add dry-run mode for destructive operations
7. Create backups when appropriate
8. Use colored output for better readability
