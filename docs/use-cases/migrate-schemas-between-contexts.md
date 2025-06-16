# Migrating Schemas Between Contexts

This guide provides comprehensive instructions for migrating schemas between contexts within the same Schema Registry instance or across different Schema Registry instances using ksr-cli.

## Prerequisites

- ksr-cli installed and configured
- Access to source and target Schema Registry instances
- Appropriate permissions (read from source, write to target)
- Understanding of Schema Registry contexts and compatibility modes

## Overview

Schema migration is essential for:
- Promoting schemas from development to production
- Synchronizing schemas across data centers
- Backing up and restoring schemas
- Consolidating multiple registries
- Disaster recovery

## Migration Strategies

### 1. Simple Migration (Same Registry, Different Contexts)

#### Basic Subject Migration

```bash
#!/bin/bash
# migrate-subject.sh

SOURCE_CONTEXT="dev"
TARGET_CONTEXT="prod"
SUBJECT="user-events"

# Export from source context
echo "Exporting $SUBJECT from $SOURCE_CONTEXT..."
ksr-cli export subject "$SUBJECT" \
  --context "$SOURCE_CONTEXT" \
  --all-versions \
  -o json > "${SUBJECT}-export.json"

# Prepare for import
echo "Preparing to import to $TARGET_CONTEXT..."

# Check if target context exists
if ! ksr-cli contexts list -o json | jq -r '.[]' | grep -q "^$TARGET_CONTEXT$"; then
  echo "Creating context: $TARGET_CONTEXT"
  ksr-cli contexts create "$TARGET_CONTEXT"
fi

# Import to target context
echo "Importing $SUBJECT to $TARGET_CONTEXT..."

# Extract schema versions and register them
jq -r '.versions[] | @json' "${SUBJECT}-export.json" | while read -r version; do
  version_data=$(echo "$version" | jq -r '.')
  version_num=$(echo "$version_data" | jq -r '.version')
  schema=$(echo "$version_data" | jq -r '.schema')
  
  echo "Registering version $version_num..."
  echo "$schema" > temp-schema.json
  
  ksr-cli schema register "$SUBJECT" \
    --context "$TARGET_CONTEXT" \
    --file temp-schema.json
done

rm -f temp-schema.json
echo "✅ Migration complete!"
```

#### Bulk Context Migration

```bash
#!/bin/bash
# migrate-context.sh

SOURCE_CONTEXT="$1"
TARGET_CONTEXT="$2"
REGISTRY_URL="${3:-http://localhost:8081}"

if [[ -z "$SOURCE_CONTEXT" || -z "$TARGET_CONTEXT" ]]; then
  echo "Usage: $0 <source-context> <target-context> [registry-url]"
  exit 1
fi

echo "🚀 Starting migration from $SOURCE_CONTEXT to $TARGET_CONTEXT"

# Create target context if it doesn't exist
if ! ksr-cli contexts list --registry-url "$REGISTRY_URL" -o json | \
     jq -r '.[]' | grep -q "^$TARGET_CONTEXT$"; then
  echo "Creating target context: $TARGET_CONTEXT"
  ksr-cli contexts create "$TARGET_CONTEXT" --registry-url "$REGISTRY_URL"
fi

# Export all subjects from source context
echo "Exporting all subjects from $SOURCE_CONTEXT..."
ksr-cli export subjects \
  --context "$SOURCE_CONTEXT" \
  --registry-url "$REGISTRY_URL" \
  --all-versions \
  --include-config \
  -o json > "${SOURCE_CONTEXT}-full-export.json"

# Get list of subjects
subjects=$(jq -r '.subjects | keys[]' "${SOURCE_CONTEXT}-full-export.json")
total=$(echo "$subjects" | wc -l | tr -d ' ')
current=0

echo "Found $total subjects to migrate"

# Migrate each subject
while IFS= read -r subject; do
  ((current++))
  echo -e "\n[$current/$total] Migrating subject: $subject"
  
  # Extract subject data
  subject_data=$(jq -r ".subjects[\"$subject\"]" "${SOURCE_CONTEXT}-full-export.json")
  
  # Set compatibility if different from default
  compatibility=$(echo "$subject_data" | jq -r '.config.compatibilityLevel // "BACKWARD"')
  if [[ "$compatibility" != "BACKWARD" ]]; then
    echo "  Setting compatibility: $compatibility"
    ksr-cli config set \
      --subject "$subject" \
      --context "$TARGET_CONTEXT" \
      --registry-url "$REGISTRY_URL" \
      --compatibility "$compatibility"
  fi
  
  # Register all versions
  echo "$subject_data" | jq -r '.versions[] | @json' | while read -r version; do
    version_data=$(echo "$version" | jq -r '.')
    version_num=$(echo "$version_data" | jq -r '.version')
    schema=$(echo "$version_data" | jq -r '.schema')
    schema_type=$(echo "$version_data" | jq -r '.schemaType // "AVRO"')
    
    echo "  Registering version $version_num (type: $schema_type)..."
    echo "$schema" > "temp-${subject}-v${version_num}.json"
    
    ksr-cli schema register "$subject" \
      --context "$TARGET_CONTEXT" \
      --registry-url "$REGISTRY_URL" \
      --schema-type "$schema_type" \
      --file "temp-${subject}-v${version_num}.json"
    
    rm -f "temp-${subject}-v${version_num}.json"
  done
done <<< "$subjects"

echo -e "\n✅ Migration completed successfully!"
echo "Migrated $total subjects from $SOURCE_CONTEXT to $TARGET_CONTEXT"
```

### 2. Cross-Registry Migration

#### Single Subject Cross-Registry Migration

```bash
#!/bin/bash
# cross-registry-migrate.sh

migrate_subject_cross_registry() {
  local subject=$1
  local source_registry=$2
  local target_registry=$3
  local source_context=${4:-"."}
  local target_context=${5:-"."}
  local source_auth=${6:-""}
  local target_auth=${7:-""}
  
  echo "Migrating $subject"
  echo "  From: $source_registry (context: $source_context)"
  echo "  To: $target_registry (context: $target_context)"
  
  # Build auth flags
  source_auth_flags=""
  target_auth_flags=""
  
  if [[ -n "$source_auth" ]]; then
    if [[ "$source_auth" == *":"* ]]; then
      IFS=':' read -r user pass <<< "$source_auth"
      source_auth_flags="--user $user --pass $pass"
    else
      source_auth_flags="--api-key $source_auth"
    fi
  fi
  
  if [[ -n "$target_auth" ]]; then
    if [[ "$target_auth" == *":"* ]]; then
      IFS=':' read -r user pass <<< "$target_auth"
      target_auth_flags="--user $user --pass $pass"
    else
      target_auth_flags="--api-key $target_auth"
    fi
  fi
  
  # Export from source
  echo "Exporting schema..."
  eval ksr-cli export subject "$subject" \
    --registry-url "$source_registry" \
    --context "$source_context" \
    $source_auth_flags \
    --all-versions \
    --include-config \
    -o json > "${subject}-export.json"
  
  # Check if export was successful
  if [[ ! -s "${subject}-export.json" ]] || ! jq -e . "${subject}-export.json" > /dev/null 2>&1; then
    echo "❌ Failed to export subject $subject"
    return 1
  fi
  
  # Set target to IMPORT mode if preserving IDs
  echo "Setting target registry to IMPORT mode..."
  eval ksr-cli mode set IMPORT \
    --registry-url "$target_registry" \
    --context "$target_context" \
    $target_auth_flags || true
  
  # Get configuration
  compatibility=$(jq -r '.config.compatibilityLevel // "BACKWARD"' "${subject}-export.json")
  
  # Set compatibility on target
  if [[ "$compatibility" != "BACKWARD" ]]; then
    echo "Setting compatibility: $compatibility"
    eval ksr-cli config set \
      --subject "$subject" \
      --context "$target_context" \
      --registry-url "$target_registry" \
      $target_auth_flags \
      --compatibility "$compatibility"
  fi
  
  # Register all versions with preserved IDs
  jq -r '.versions[] | @json' "${subject}-export.json" | while read -r version; do
    version_data=$(echo "$version" | jq -r '.')
    version_num=$(echo "$version_data" | jq -r '.version')
    schema_id=$(echo "$version_data" | jq -r '.id')
    schema=$(echo "$version_data" | jq -r '.schema')
    schema_type=$(echo "$version_data" | jq -r '.schemaType // "AVRO"')
    
    echo "Registering version $version_num (ID: $schema_id)..."
    echo "$schema" > "temp-schema.json"
    
    # In IMPORT mode, the schema ID should be preserved
    eval ksr-cli schema register "$subject" \
      --context "$target_context" \
      --registry-url "$target_registry" \
      $target_auth_flags \
      --schema-type "$schema_type" \
      --file "temp-schema.json"
  done
  
  # Set target back to READWRITE mode
  echo "Setting target registry back to READWRITE mode..."
  eval ksr-cli mode set READWRITE \
    --registry-url "$target_registry" \
    --context "$target_context" \
    $target_auth_flags || true
  
  rm -f "temp-schema.json" "${subject}-export.json"
  echo "✅ Successfully migrated $subject"
}

# Usage example
migrate_subject_cross_registry \
  "user-events" \
  "http://source-registry.example.com:8081" \
  "http://target-registry.example.com:8081" \
  "production" \
  "production" \
  "source-api-key" \
  "target-api-key"
```

#### Full Registry Migration

```bash
#!/bin/bash
# full-registry-migration.sh

SOURCE_REGISTRY="$1"
TARGET_REGISTRY="$2"
SOURCE_AUTH="${3:-""}"
TARGET_AUTH="${4:-""}"
BATCH_SIZE=10

if [[ -z "$SOURCE_REGISTRY" || -z "$TARGET_REGISTRY" ]]; then
  echo "Usage: $0 <source-registry> <target-registry> [source-auth] [target-auth]"
  echo "Auth can be 'user:pass' or 'api-key'"
  exit 1
fi

echo "🚀 Full Registry Migration"
echo "Source: $SOURCE_REGISTRY"
echo "Target: $TARGET_REGISTRY"
echo "Batch size: $BATCH_SIZE"

# Build auth flags
source_auth_flags=""
target_auth_flags=""

if [[ -n "$SOURCE_AUTH" ]]; then
  if [[ "$SOURCE_AUTH" == *":"* ]]; then
    IFS=':' read -r user pass <<< "$SOURCE_AUTH"
    source_auth_flags="--user $user --pass $pass"
  else
    source_auth_flags="--api-key $SOURCE_AUTH"
  fi
fi

if [[ -n "$TARGET_AUTH" ]]; then
  if [[ "$TARGET_AUTH" == *":"* ]]; then
    IFS=':' read -r user pass <<< "$TARGET_AUTH"
    target_auth_flags="--user $user --pass $pass"
  else
    target_auth_flags="--api-key $TARGET_AUTH"
  fi
fi

# Test connections
echo -e "\n🔍 Testing connections..."
if ! eval ksr-cli check --registry-url "$SOURCE_REGISTRY" $source_auth_flags; then
  echo "❌ Cannot connect to source registry"
  exit 1
fi

if ! eval ksr-cli check --registry-url "$TARGET_REGISTRY" $target_auth_flags; then
  echo "❌ Cannot connect to target registry"
  exit 1
fi

# Get all contexts from source
echo -e "\n📋 Getting contexts from source registry..."
contexts=$(eval ksr-cli contexts list \
  --registry-url "$SOURCE_REGISTRY" \
  $source_auth_flags \
  -o json | jq -r '.[]')

if [[ -z "$contexts" ]]; then
  contexts="."
fi

total_contexts=$(echo "$contexts" | wc -l | tr -d ' ')
echo "Found $total_contexts context(s)"

# Create migration directory
migration_dir="migration-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$migration_dir"
cd "$migration_dir"

# Export global configuration
echo -e "\n⚙️  Exporting global configuration..."
eval ksr-cli config get \
  --registry-url "$SOURCE_REGISTRY" \
  $source_auth_flags \
  -o json > global-config.json

global_compat=$(jq -r '.compatibilityLevel // "BACKWARD"' global-config.json)

# Set global configuration on target
echo "Setting global compatibility on target: $global_compat"
eval ksr-cli config set \
  --registry-url "$TARGET_REGISTRY" \
  $target_auth_flags \
  --compatibility "$global_compat"

# Process each context
context_num=0
while IFS= read -r context; do
  ((context_num++))
  echo -e "\n🔄 Processing context [$context_num/$total_contexts]: $context"
  
  # Create context directory
  context_dir="context-${context//\//_}"
  mkdir -p "$context_dir"
  
  # Create context on target if needed
  if [[ "$context" != "." ]]; then
    echo "Creating context on target: $context"
    eval ksr-cli contexts create "$context" \
      --registry-url "$TARGET_REGISTRY" \
      $target_auth_flags || true
  fi
  
  # Export all subjects from context
  echo "Exporting all subjects from context..."
  eval ksr-cli export subjects \
    --context "$context" \
    --registry-url "$SOURCE_REGISTRY" \
    $source_auth_flags \
    --all-versions \
    --include-config \
    -o json > "$context_dir/full-export.json"
  
  # Get subjects
  subjects=$(jq -r '.subjects | keys[]' "$context_dir/full-export.json" 2>/dev/null || echo "")
  
  if [[ -z "$subjects" ]]; then
    echo "No subjects found in context $context"
    continue
  fi
  
  total_subjects=$(echo "$subjects" | wc -l | tr -d ' ')
  echo "Found $total_subjects subjects in context $context"
  
  # Set target to IMPORT mode
  echo "Setting target to IMPORT mode..."
  eval ksr-cli mode set IMPORT \
    --registry-url "$TARGET_REGISTRY" \
    --context "$context" \
    $target_auth_flags || true
  
  # Process subjects in batches
  subject_num=0
  batch_subjects=""
  batch_count=0
  
  while IFS= read -r subject; do
    ((subject_num++))
    ((batch_count++))
    
    batch_subjects+="$subject"
    
    if [[ $batch_count -eq $BATCH_SIZE ]] || [[ $subject_num -eq $total_subjects ]]; then
      echo -e "\n📦 Processing batch (subjects $((subject_num - batch_count + 1))-$subject_num of $total_subjects)"
      
      # Process subjects in current batch
      while IFS= read -r batch_subject; do
        echo -n "  Migrating $batch_subject... "
        
        # Extract subject data
        subject_data=$(jq -r ".subjects[\"$batch_subject\"]" "$context_dir/full-export.json")
        
        # Set compatibility if needed
        compatibility=$(echo "$subject_data" | jq -r '.config.compatibilityLevel // null')
        if [[ "$compatibility" != "null" ]] && [[ "$compatibility" != "$global_compat" ]]; then
          eval ksr-cli config set \
            --subject "$batch_subject" \
            --context "$context" \
            --registry-url "$TARGET_REGISTRY" \
            $target_auth_flags \
            --compatibility "$compatibility" 2>/dev/null
        fi
        
        # Register all versions
        echo "$subject_data" | jq -r '.versions[] | @json' | while read -r version; do
          version_data=$(echo "$version" | jq -r '.')
          schema=$(echo "$version_data" | jq -r '.schema')
          schema_type=$(echo "$version_data" | jq -r '.schemaType // "AVRO"')
          
          echo "$schema" > "temp-schema.json"
          
          eval ksr-cli schema register "$batch_subject" \
            --context "$context" \
            --registry-url "$TARGET_REGISTRY" \
            $target_auth_flags \
            --schema-type "$schema_type" \
            --file "temp-schema.json" 2>/dev/null
          
          rm -f "temp-schema.json"
        done
        
        echo "✓"
      done <<< "$batch_subjects"
      
      # Reset batch
      batch_subjects=""
      batch_count=0
    else
      batch_subjects+=$'\n'
    fi
  done <<< "$subjects"
  
  # Set target back to READWRITE mode
  echo "Setting target back to READWRITE mode..."
  eval ksr-cli mode set READWRITE \
    --registry-url "$TARGET_REGISTRY" \
    --context "$context" \
    $target_auth_flags || true
    
done <<< "$contexts"

cd ..
echo -e "\n✅ Migration completed!"
echo "Migration data saved in: $migration_dir"

# Generate summary report
echo -e "\n📊 Generating migration summary..."
cat > "$migration_dir/migration-summary.txt" << EOF
Migration Summary
================
Date: $(date)
Source: $SOURCE_REGISTRY
Target: $TARGET_REGISTRY
Contexts migrated: $total_contexts

Details:
EOF

while IFS= read -r context; do
  context_dir="$migration_dir/context-${context//\//_}"
  if [[ -f "$context_dir/full-export.json" ]]; then
    subject_count=$(jq -r '.subjects | keys | length' "$context_dir/full-export.json" 2>/dev/null || echo 0)
    echo "- Context '$context': $subject_count subjects" >> "$migration_dir/migration-summary.txt"
  fi
done <<< "$contexts"

echo -e "\nSummary saved to: $migration_dir/migration-summary.txt"
```

### 3. Selective Migration with Filtering

```bash
#!/bin/bash
# selective-migration.sh

# Migrate only subjects matching a pattern
migrate_filtered() {
  local pattern=$1
  local source_registry=$2
  local target_registry=$3
  local source_context=${4:-"."}
  local target_context=${5:-"."}
  
  echo "Migrating subjects matching pattern: $pattern"
  
  # Get matching subjects
  subjects=$(ksr-cli subjects list \
    --registry-url "$source_registry" \
    --context "$source_context" \
    -o json | jq -r '.[]' | grep -E "$pattern")
  
  total=$(echo "$subjects" | wc -l | tr -d ' ')
  echo "Found $total matching subjects"
  
  # Migrate each matching subject
  current=0
  while IFS= read -r subject; do
    ((current++))
    echo -e "\n[$current/$total] Migrating: $subject"
    
    # Export subject
    ksr-cli export subject "$subject" \
      --registry-url "$source_registry" \
      --context "$source_context" \
      --all-versions \
      -o json > "${subject}.json"
    
    # Import to target
    # ... (use import logic from previous examples)
    
  done <<< "$subjects"
}

# Example: Migrate only subjects ending with '-events'
migrate_filtered ".*-events$" \
  "http://source.example.com:8081" \
  "http://target.example.com:8081"
```

## Migration Validation

### Post-Migration Validation Script

```bash
#!/bin/bash
# validate-migration.sh

validate_migration() {
  local source_registry=$1
  local target_registry=$2
  local context=${3:-"."}
  local detailed=${4:-false}
  
  echo "🔍 Validating migration"
  echo "Source: $source_registry"
  echo "Target: $target_registry"
  echo "Context: $context"
  
  # Get subjects from both registries
  source_subjects=$(ksr-cli subjects list \
    --registry-url "$source_registry" \
    --context "$context" \
    -o json | jq -r '.[]' | sort)
    
  target_subjects=$(ksr-cli subjects list \
    --registry-url "$target_registry" \
    --context "$context" \
    -o json | jq -r '.[]' | sort)
  
  # Count subjects
  source_count=$(echo "$source_subjects" | wc -l | tr -d ' ')
  target_count=$(echo "$target_subjects" | wc -l | tr -d ' ')
  
  echo -e "\n📊 Subject count:"
  echo "  Source: $source_count"
  echo "  Target: $target_count"
  
  if [[ $source_count -ne $target_count ]]; then
    echo "❌ Subject count mismatch!"
    
    echo -e "\nMissing in target:"
    comm -23 <(echo "$source_subjects") <(echo "$target_subjects")
    
    echo -e "\nExtra in target:"
    comm -13 <(echo "$source_subjects") <(echo "$target_subjects")
  else
    echo "✅ Subject count matches"
  fi
  
  if [[ "$detailed" == "true" ]]; then
    echo -e "\n🔍 Detailed validation:"
    
    # Validate each subject
    while IFS= read -r subject; do
      if [[ -z "$subject" ]]; then continue; fi
      
      echo -n "  Checking $subject... "
      
      # Get latest version from both
      source_schema=$(ksr-cli schema get "$subject" \
        --registry-url "$source_registry" \
        --context "$context" \
        -o json | jq -r '.schema' | jq -S .)
        
      target_schema=$(ksr-cli schema get "$subject" \
        --registry-url "$target_registry" \
        --context "$context" \
        -o json 2>/dev/null | jq -r '.schema' | jq -S .)
      
      if [[ "$source_schema" == "$target_schema" ]]; then
        echo "✅"
      else
        echo "❌ Schema mismatch"
      fi
    done <<< "$source_subjects"
  fi
  
  echo -e "\n✅ Validation complete"
}

# Usage
validate_migration \
  "http://source.example.com:8081" \
  "http://target.example.com:8081" \
  "." \
  true
```

## Best Practices

### 1. Pre-Migration Checklist

```bash
#!/bin/bash
# pre-migration-check.sh

pre_migration_check() {
  echo "📋 Pre-Migration Checklist"
  
  # Check source connectivity
  echo -n "✓ Source registry accessible... "
  if ksr-cli check --registry-url "$SOURCE_REGISTRY" > /dev/null 2>&1; then
    echo "YES"
  else
    echo "NO - Cannot proceed"
    exit 1
  fi
  
  # Check target connectivity
  echo -n "✓ Target registry accessible... "
  if ksr-cli check --registry-url "$TARGET_REGISTRY" > /dev/null 2>&1; then
    echo "YES"
  else
    echo "NO - Cannot proceed"
    exit 1
  fi
  
  # Check target mode
  echo -n "✓ Target registry mode... "
  mode=$(ksr-cli mode get --registry-url "$TARGET_REGISTRY" -o json | jq -r '.mode')
  echo "$mode"
  
  # Check disk space
  echo -n "✓ Sufficient disk space... "
  available=$(df -h . | awk 'NR==2 {print $4}')
  echo "$available available"
  
  # Estimate migration size
  echo -n "✓ Estimating migration size... "
  subject_count=$(ksr-cli subjects list \
    --registry-url "$SOURCE_REGISTRY" \
    -o json | jq '. | length')
  echo "$subject_count subjects"
  
  echo -e "\n✅ Pre-migration checks passed"
}
```

### 2. Migration with Rollback

```bash
#!/bin/bash
# migration-with-rollback.sh

# Create rollback point
create_rollback() {
  local registry=$1
  local context=$2
  local backup_dir="rollback-$(date +%Y%m%d-%H%M%S)"
  
  mkdir -p "$backup_dir"
  
  echo "Creating rollback point in $backup_dir..."
  ksr-cli export subjects \
    --registry-url "$registry" \
    --context "$context" \
    --all-versions \
    --include-config \
    -o json > "$backup_dir/backup.json"
  
  echo "$backup_dir"
}

# Perform rollback
rollback() {
  local backup_dir=$1
  local registry=$2
  local context=$3
  
  echo "⚠️  Performing rollback from $backup_dir..."
  
  # Clear existing schemas
  subjects=$(ksr-cli subjects list \
    --registry-url "$registry" \
    --context "$context" \
    -o json | jq -r '.[]')
  
  while IFS= read -r subject; do
    echo "Removing $subject..."
    ksr-cli subject delete "$subject" \
      --registry-url "$registry" \
      --context "$context"
  done <<< "$subjects"
  
  # Restore from backup
  # ... (use import logic)
  
  echo "✅ Rollback complete"
}
```

### 3. Monitoring Migration Progress

```bash
#!/bin/bash
# monitor-migration.sh

# Function to monitor migration progress
monitor_progress() {
  local source_total=$1
  local pid=$2
  local target_registry=$3
  local context=$4
  
  while kill -0 $pid 2>/dev/null; do
    current=$(ksr-cli subjects list \
      --registry-url "$target_registry" \
      --context "$context" \
      -o json 2>/dev/null | jq '. | length' || echo 0)
    
    percentage=$((current * 100 / source_total))
    echo -ne "\rProgress: [$percentage%] $current/$source_total subjects"
    
    sleep 5
  done
  
  echo -e "\n✅ Migration process completed"
}
```

## Troubleshooting

### Common Issues and Solutions

1. **Schema ID Conflicts**
   ```bash
   # Set IMPORT mode before migration
   ksr-cli mode set IMPORT --registry-url "$TARGET_REGISTRY"
   # Perform migration
   # Set back to READWRITE mode
   ksr-cli mode set READWRITE --registry-url "$TARGET_REGISTRY"
   ```

2. **Compatibility Violations**
   ```bash
   # Temporarily set compatibility to NONE
   ksr-cli config set --compatibility NONE --registry-url "$TARGET_REGISTRY"
   # Perform migration
   # Restore original compatibility
   ksr-cli config set --compatibility BACKWARD --registry-url "$TARGET_REGISTRY"
   ```

3. **Authentication Failures**
   ```bash
   # Test authentication
   curl -u "$USERNAME:$PASSWORD" "$REGISTRY_URL/subjects"
   # Or with API key
   curl -H "Authorization: Bearer $API_KEY" "$REGISTRY_URL/subjects"
   ```

## Performance Optimization

### Parallel Migration

```bash
#!/bin/bash
# parallel-migration.sh

# Use GNU parallel for faster migration
export -f migrate_single_subject

subjects=$(ksr-cli subjects list -o json | jq -r '.[]')
echo "$subjects" | parallel -j 10 migrate_single_subject {} "$SOURCE" "$TARGET"
```

## Conclusion

Migrating schemas between contexts requires careful planning and execution. The scripts and techniques provided here can be adapted to your specific requirements. Always test migrations in a non-production environment first and maintain backups before performing any migration operations.
