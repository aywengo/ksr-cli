# Comparing Schema Registry Contexts

This guide demonstrates how to compare schemas and configurations across different contexts within the same Schema Registry or between different Schema Registry instances using ksr-cli.

## Prerequisites

- ksr-cli installed and configured
- Access to one or more Schema Registry instances
- Basic understanding of Schema Registry contexts
- Command-line tools: `jq`, `diff`, or `vimdiff` (optional but recommended)

## Overview

Comparing Schema Registry contexts is essential for:
- Ensuring consistency across environments (dev, staging, production)
- Validating schema synchronization after migrations
- Auditing schema differences between teams or projects
- Troubleshooting schema-related issues

## Basic Context Comparison

### Comparing Contexts in the Same Registry

#### 1. List Available Contexts

```bash
# List all contexts in the default registry
ksr-cli contexts list

# List contexts in a specific registry
ksr-cli contexts list --registry-url http://registry1.example.com:8081
```

#### 2. Compare Subjects Between Contexts

```bash
# Export subjects from two different contexts
ksr-cli subjects list --context dev -o json > dev-subjects.json
ksr-cli subjects list --context prod -o json > prod-subjects.json

# Compare using diff
diff dev-subjects.json prod-subjects.json

# Or use jq for prettier output
jq -s '.[0] - .[1]' dev-subjects.json prod-subjects.json > missing-in-prod.json
jq -s '.[1] - .[0]' dev-subjects.json prod-subjects.json > missing-in-dev.json
```

#### 3. Compare Specific Schemas

```bash
# Function to compare schemas between contexts
compare_schema() {
  local subject=$1
  local context1=$2
  local context2=$3
  
  echo "Comparing schema: $subject"
  
  # Get schemas from both contexts
  ksr-cli schema get "$subject" --context "$context1" -o json > "${subject}-${context1}.json"
  ksr-cli schema get "$subject" --context "$context2" -o json > "${subject}-${context2}.json"
  
  # Extract just the schema definition
  jq -r '.schema' "${subject}-${context1}.json" | jq . > "${subject}-${context1}-schema.json"
  jq -r '.schema' "${subject}-${context2}.json" | jq . > "${subject}-${context2}-schema.json"
  
  # Compare
  diff -u "${subject}-${context1}-schema.json" "${subject}-${context2}-schema.json"
}

# Usage
compare_schema "user-events" "dev" "prod"
```

### Comparing Contexts Across Different Registries

#### 1. Configure Multiple Registries

```bash
# Create configuration for multiple registries
cat > ~/.ksr-cli-multi.yaml << EOF
default-registry: prod
registries:
  dev:
    url: http://dev-registry.example.com:8081
    username: dev-user
    password: dev-pass
  staging:
    url: http://staging-registry.example.com:8081
    api-key: staging-api-key
  prod:
    url: http://prod-registry.example.com:8081
    api-key: prod-api-key
EOF
```

#### 2. Compare Schemas Between Registries

```bash
#!/bin/bash
# compare-registries.sh

REGISTRY1_URL=$1
REGISTRY2_URL=$2
CONTEXT1=${3:-"."}
CONTEXT2=${4:-"."}

echo "Comparing registries:"
echo "  Registry 1: $REGISTRY1_URL (context: $CONTEXT1)"
echo "  Registry 2: $REGISTRY2_URL (context: $CONTEXT2)"

# Export schemas from both registries
ksr-cli export subjects \
  --registry-url "$REGISTRY1_URL" \
  --context "$CONTEXT1" \
  --all-versions \
  -o json > registry1-export.json

ksr-cli export subjects \
  --registry-url "$REGISTRY2_URL" \
  --context "$CONTEXT2" \
  --all-versions \
  -o json > registry2-export.json

# Compare using jq
echo -e "\n📊 Summary:"
echo -n "Registry 1 subjects: "
jq '.subjects | length' registry1-export.json
echo -n "Registry 2 subjects: "
jq '.subjects | length' registry2-export.json

# Find differences
echo -e "\n🔍 Differences:"
jq -r '.subjects | keys[]' registry1-export.json | sort > subjects1.txt
jq -r '.subjects | keys[]' registry2-export.json | sort > subjects2.txt

echo -e "\nSubjects only in Registry 1:"
comm -23 subjects1.txt subjects2.txt

echo -e "\nSubjects only in Registry 2:"
comm -13 subjects1.txt subjects2.txt

echo -e "\nCommon subjects with differences:"
comm -12 subjects1.txt subjects2.txt | while read subject; do
  schema1=$(jq -r ".subjects[\"$subject\"].versions[-1].schema" registry1-export.json | jq -S .)
  schema2=$(jq -r ".subjects[\"$subject\"].versions[-1].schema" registry2-export.json | jq -S .)
  
  if [ "$schema1" != "$schema2" ]; then
    echo "  - $subject"
  fi
done
```

#### 3. Detailed Schema Comparison

```bash
#!/bin/bash
# detailed-compare.sh

compare_schema_detailed() {
  local subject=$1
  local registry1=$2
  local registry2=$3
  local context1=${4:-"."}
  local context2=${5:-"."}
  
  echo "=== Comparing $subject ==="
  
  # Get all versions from both registries
  versions1=$(ksr-cli schema versions "$subject" \
    --registry-url "$registry1" \
    --context "$context1" \
    -o json | jq -r '.[]')
    
  versions2=$(ksr-cli schema versions "$subject" \
    --registry-url "$registry2" \
    --context "$context2" \
    -o json | jq -r '.[]')
  
  echo "Registry 1 versions: $(echo $versions1 | tr '\n' ' ')"
  echo "Registry 2 versions: $(echo $versions2 | tr '\n' ' ')"
  
  # Compare latest versions
  echo -e "\n📋 Comparing latest versions:"
  
  ksr-cli schema get "$subject" \
    --registry-url "$registry1" \
    --context "$context1" \
    -o json | jq -r '.schema' | jq -S . > tmp1.json
    
  ksr-cli schema get "$subject" \
    --registry-url "$registry2" \
    --context "$context2" \
    -o json | jq -r '.schema' | jq -S . > tmp2.json
  
  if diff -q tmp1.json tmp2.json > /dev/null; then
    echo "✅ Latest versions are identical"
  else
    echo "❌ Latest versions differ:"
    diff -u tmp1.json tmp2.json | head -20
  fi
  
  # Compare configurations
  echo -e "\n⚙️  Comparing configurations:"
  
  config1=$(ksr-cli config get --subject "$subject" \
    --registry-url "$registry1" \
    --context "$context1" \
    -o json | jq -r '.compatibilityLevel // "BACKWARD"')
    
  config2=$(ksr-cli config get --subject "$subject" \
    --registry-url "$registry2" \
    --context "$context2" \
    -o json | jq -r '.compatibilityLevel // "BACKWARD"')
  
  echo "Registry 1 compatibility: $config1"
  echo "Registry 2 compatibility: $config2"
  
  if [ "$config1" != "$config2" ]; then
    echo "⚠️  Compatibility settings differ!"
  fi
  
  rm -f tmp1.json tmp2.json
}

# Usage
compare_schema_detailed "user-events" \
  "http://registry1.example.com:8081" \
  "http://registry2.example.com:8081" \
  "team-a" \
  "team-b"
```

## Advanced Comparison Techniques

### 1. Visual Diff with vimdiff

```bash
# Export and compare with vimdiff
export_and_diff() {
  local subject=$1
  local context1=$2
  local context2=$3
  
  ksr-cli schema get "$subject" --context "$context1" -o json | \
    jq -r '.schema' | jq . > "${subject}-${context1}.json"
    
  ksr-cli schema get "$subject" --context "$context2" -o json | \
    jq -r '.schema' | jq . > "${subject}-${context2}.json"
  
  vimdiff "${subject}-${context1}.json" "${subject}-${context2}.json"
}
```

### 2. HTML Diff Report

```bash
#!/bin/bash
# generate-diff-report.sh

generate_html_report() {
  local registry1=$1
  local registry2=$2
  local output="schema-comparison-report.html"
  
  cat > "$output" << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Schema Registry Comparison Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    .different { background-color: #ffcccc; }
    .missing { background-color: #ffffcc; }
    .identical { background-color: #ccffcc; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
  </style>
</head>
<body>
  <h1>Schema Registry Comparison Report</h1>
  <p>Generated: $(date)</p>
  <table>
    <tr>
      <th>Subject</th>
      <th>Registry 1</th>
      <th>Registry 2</th>
      <th>Status</th>
    </tr>
EOF

  # Get all subjects from both registries
  subjects1=$(ksr-cli subjects list --registry-url "$registry1" -o json | jq -r '.[]')
  subjects2=$(ksr-cli subjects list --registry-url "$registry2" -o json | jq -r '.[]')
  all_subjects=$(echo -e "$subjects1\n$subjects2" | sort -u)
  
  while read -r subject; do
    if [[ -z "$subject" ]]; then continue; fi
    
    status="identical"
    v1="-"
    v2="-"
    
    # Check if subject exists in registry1
    if echo "$subjects1" | grep -q "^$subject$"; then
      v1=$(ksr-cli schema get "$subject" --registry-url "$registry1" -o json | jq -r '.version')
    fi
    
    # Check if subject exists in registry2
    if echo "$subjects2" | grep -q "^$subject$"; then
      v2=$(ksr-cli schema get "$subject" --registry-url "$registry2" -o json | jq -r '.version')
    fi
    
    # Determine status
    if [ "$v1" = "-" ] || [ "$v2" = "-" ]; then
      status="missing"
    elif [ "$v1" != "$v2" ]; then
      status="different"
    fi
    
    echo "    <tr class=\"$status\">" >> "$output"
    echo "      <td>$subject</td>" >> "$output"
    echo "      <td>Version: $v1</td>" >> "$output"
    echo "      <td>Version: $v2</td>" >> "$output"
    echo "      <td>$status</td>" >> "$output"
    echo "    </tr>" >> "$output"
  done <<< "$all_subjects"
  
  cat >> "$output" << 'EOF'
  </table>
</body>
</html>
EOF

  echo "Report generated: $output"
}

# Usage
generate_html_report \
  "http://registry1.example.com:8081" \
  "http://registry2.example.com:8081"
```

### 3. JSON Patch Format

```bash
# Generate JSON patch between schemas
generate_patch() {
  local subject=$1
  local source_registry=$2
  local target_registry=$3
  
  # Get schemas
  source_schema=$(ksr-cli schema get "$subject" \
    --registry-url "$source_registry" \
    -o json | jq -r '.schema' | jq .)
    
  target_schema=$(ksr-cli schema get "$subject" \
    --registry-url "$target_registry" \
    -o json | jq -r '.schema' | jq .)
  
  # Generate patch using jd (JSON diff tool)
  echo "$source_schema" > source.json
  echo "$target_schema" > target.json
  
  # Install jd if not available: go install github.com/josephburnett/jd@latest
  jd -f patch source.json target.json
  
  rm -f source.json target.json
}
```

## Best Practices

1. **Regular Comparisons**: Schedule regular comparisons between environments to catch drift early
2. **Version Control**: Store comparison results in version control for historical tracking
3. **Automation**: Integrate comparison scripts into CI/CD pipelines
4. **Alerting**: Set up alerts for unexpected schema differences
5. **Documentation**: Document any intentional differences between environments

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   ```bash
   # Use appropriate authentication for each registry
   ksr-cli subjects list \
     --registry-url http://secure-registry.example.com:8081 \
     --api-key "$API_KEY"
   ```

2. **Context Not Found**
   ```bash
   # List available contexts first
   ksr-cli contexts list --registry-url http://registry.example.com:8081
   ```

3. **Large Schema Exports**
   ```bash
   # For large registries, export in batches
   subjects=$(ksr-cli subjects list -o json | jq -r '.[]')
   for subject in $subjects; do
     ksr-cli export subject "$subject" -f "exports/$subject.json"
   done
   ```

## Conclusion

Comparing Schema Registry contexts is crucial for maintaining consistency across environments. The techniques shown here can be adapted to your specific needs and integrated into your schema management workflows.
