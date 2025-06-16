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

## Installation

1. Make scripts executable:
```bash
chmod +x scripts/*.sh
```

2. Ensure dependencies are installed:
- ksr-cli
- jq
- bash 4.0+
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

### 2. Regular Sync Monitoring

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

### 3. Multi-Environment Comparison

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

### 4. Generate Comparison Matrix

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

## Tips and Best Practices

1. **Use verbose mode** for troubleshooting:
   ```bash
   ./compare-contexts.sh -s http://dev:8081 -t http://prod:8081 -v
   ```

2. **Save reports** for historical tracking:
   ```bash
   REPORT_DATE=$(date +%Y%m%d-%H%M%S)
   ./compare-contexts.sh ... -f "reports/comparison-$REPORT_DATE.html"
   ```

3. **Use exit codes** in automation:
   - Exit code 0: Contexts are identical
   - Exit code 1: Differences found

4. **Combine with other tools**:
   ```bash
   # Use with jq for custom analysis
   ./compare-contexts.sh ... -o json | jq '.subjects | to_entries | map(select(.value.status == "different"))[].key'
   ```

5. **Monitor specific subjects**:
   ```bash
   # Check if specific critical subjects are in sync
   ./compare-contexts.sh ... -o json | jq '.subjects["critical-events"].status'
   ```

## Contributing

When adding new scripts:
1. Include comprehensive help/usage information
2. Use consistent error handling and exit codes
3. Support common authentication methods
4. Provide examples in this README
5. Test with various Schema Registry configurations
