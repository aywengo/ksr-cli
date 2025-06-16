# Migrating Schemas with ID and Version Preservation

This guide explains how to migrate schemas between Schema Registry instances while preserving schema IDs and version numbers. This is crucial for maintaining consistency and avoiding ID conflicts in environments where schema IDs are referenced directly.

## Overview

Preserving schema IDs and versions during migration is important for:
- Maintaining consistency across environments
- Avoiding breaking changes in applications that reference schema IDs
- Preserving the complete evolution history of schemas
- Ensuring compatibility with serialized data
- Supporting disaster recovery scenarios

## Prerequisites

- ksr-cli installed and configured
- Access to both source and target Schema Registry instances
- Understanding of Schema Registry modes (READWRITE, READONLY, IMPORT)
- Appropriate permissions to change registry modes

## The IMPORT Mode

Schema Registry's IMPORT mode is the key to preserving IDs:
- **READWRITE** (default): New schemas get auto-generated IDs
- **READONLY**: No new schemas can be registered
- **IMPORT**: Allows registration with specific schema IDs

## Using the Migration Script

The `migrate-with-ids.sh` script automates the process of migrating schemas while preserving IDs and versions.

### Basic Usage

```bash
# Migrate all subjects from one registry to another
./scripts/migrate-with-ids.sh \
  --source-registry http://source-registry:8081 \
  --target-registry http://target-registry:8081

# Migrate a specific subject
./scripts/migrate-with-ids.sh \
  --source-registry http://source-registry:8081 \
  --target-registry http://target-registry:8081 \
  --subject user-events

# Migrate between contexts
./scripts/migrate-with-ids.sh \
  --source-registry http://registry:8081 \
  --target-registry http://registry:8081 \
  --source-context production \
  --target-context disaster-recovery
```

### With Authentication

```bash
# Basic authentication
./scripts/migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --source-auth "user:password" \
  --target-auth "user:password"

# API key authentication
./scripts/migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --source-auth "source-api-key" \
  --target-auth "target-api-key"
```

### Advanced Options

```bash
# Dry run - see what would be migrated
./scripts/migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --dry-run

# Force overwrite existing subjects
./scripts/migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --subject user-events \
  --force

# Custom backup directory
./scripts/migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --backup-dir /backup/schemas

# Verbose output for debugging
./scripts/migrate-with-ids.sh \
  --source-registry http://source:8081 \
  --target-registry http://target:8081 \
  --verbose
```

## Manual Migration Process

If you prefer to migrate manually or need custom logic, here's the step-by-step process:

### 1. Set Target Registry to IMPORT Mode

```bash
# Check current mode
ksr-cli mode get --registry-url http://target-registry:8081

# Set to IMPORT mode
ksr-cli mode set IMPORT --registry-url http://target-registry:8081
```

### 2. Export Schemas with Metadata

```bash
# Export a single subject with all versions
ksr-cli export subject user-events \
  --registry-url http://source-registry:8081 \
  --all-versions \
  --include-config \
  -o json > user-events.json

# Export all subjects
ksr-cli export subjects \
  --registry-url http://source-registry:8081 \
  --all-versions \
  --include-config \
  -o json > all-schemas.json
```

### 3. Extract Schema Information

```bash
# View schema IDs and versions
jq '.versions[] | {version: .version, id: .id, schema: .schema | fromjson | .name}' user-events.json
```

### 4. Register Schemas with Preserved IDs

When the target is in IMPORT mode, you need to use the Schema Registry API directly to specify the schema ID:

```bash
# Function to register schema with specific ID
register_with_id() {
  local subject=$1
  local schema=$2
  local schema_id=$3
  local registry=$4
  
  curl -X POST \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    -d "{
      \"schema\": \"$schema\",
      \"schemaType\": \"AVRO\",
      \"id\": $schema_id
    }" \
    "$registry/subjects/$subject/versions"
}

# Example usage
schema=$(jq -r '.versions[0].schema' user-events.json)
schema_id=$(jq -r '.versions[0].id' user-events.json)
register_with_id "user-events" "$schema" "$schema_id" "http://target-registry:8081"
```

### 5. Restore Original Mode

```bash
# Set back to READWRITE mode
ksr-cli mode set READWRITE --registry-url http://target-registry:8081
```

## Verification

### Verify Schema IDs

```bash
# Compare schema IDs between source and target
echo "Comparing schema IDs for user-events:"

# Get from source
echo -n "Source: "
ksr-cli schema get user-events \
  --registry-url http://source-registry:8081 \
  -o json | jq -r '.id'

# Get from target
echo -n "Target: "
ksr-cli schema get user-events \
  --registry-url http://target-registry:8081 \
  -o json | jq -r '.id'
```

### Verify All Versions

```bash
# Function to verify all versions
verify_versions() {
  local subject=$1
  local source_registry=$2
  local target_registry=$3
  
  echo "Verifying versions for $subject"
  
  # Get versions from source
  source_versions=$(ksr-cli schema versions "$subject" \
    --registry-url "$source_registry" \
    -o json | jq -r '.[]' | sort)
  
  # Get versions from target
  target_versions=$(ksr-cli schema versions "$subject" \
    --registry-url "$target_registry" \
    -o json | jq -r '.[]' | sort)
  
  if [[ "$source_versions" == "$target_versions" ]]; then
    echo "✓ All versions match"
  else
    echo "✗ Version mismatch"
    echo "Source versions: $(echo $source_versions | tr '\n' ' ')"
    echo "Target versions: $(echo $target_versions | tr '\n' ' ')"
  fi
}

# Usage
verify_versions "user-events" \
  "http://source-registry:8081" \
  "http://target-registry:8081"
```

## Use Cases

### 1. Disaster Recovery Setup

```bash
#!/bin/bash
# Setup disaster recovery replica with identical IDs

PRIMARY="http://primary-registry:8081"
DR_SITE="http://dr-registry:8081"

# Initial full sync
./scripts/migrate-with-ids.sh \
  --source-registry "$PRIMARY" \
  --target-registry "$DR_SITE" \
  --backup-dir /backup/dr-sync-$(date +%Y%m%d)

# Verify sync
./scripts/compare-contexts.sh \
  --source-registry "$PRIMARY" \
  --target-registry "$DR_SITE" \
  --output json \
  --output-file dr-sync-report.json
```

### 2. Environment Promotion with ID Preservation

```bash
#!/bin/bash
# Promote schemas from staging to production preserving IDs

# First, validate schemas are ready for promotion
echo "Validating schemas for promotion..."
./scripts/compare-contexts.sh \
  --source-registry http://staging:8081 \
  --target-registry http://prod:8081 \
  --output text

# If validation passes, migrate with ID preservation
echo "Migrating schemas to production..."
./scripts/migrate-with-ids.sh \
  --source-registry http://staging:8081 \
  --target-registry http://prod:8081 \
  --source-auth "$STAGING_API_KEY" \
  --target-auth "$PROD_API_KEY"
```

### 3. Selective Migration with ID Preservation

```bash
#!/bin/bash
# Migrate only specific subjects preserving IDs

SUBJECTS=("user-events" "order-events" "payment-events")

for subject in "${SUBJECTS[@]}"; do
  echo "Migrating $subject..."
  ./scripts/migrate-with-ids.sh \
    --source-registry http://source:8081 \
    --target-registry http://target:8081 \
    --subject "$subject"
done
```

## Troubleshooting

### Common Issues

1. **"Subject already exists" error**
   ```bash
   # Use --force flag to overwrite
   ./scripts/migrate-with-ids.sh ... --force
   
   # Or manually delete the subject first
   ksr-cli subject delete my-subject --registry-url http://target:8081
   ```

2. **"ID already in use" error**
   - This happens when a schema with the same ID already exists
   - Check if the schema is already registered under a different subject
   - May need to clean the target registry before migration

3. **"Registry not in IMPORT mode" error**
   ```bash
   # Manually set IMPORT mode
   ksr-cli mode set IMPORT --registry-url http://target:8081
   ```

4. **Version gaps after migration**
   - This is expected if some versions were deleted in the source
   - Schema Registry preserves version numbers, including gaps

### Debugging

```bash
# Enable verbose logging
export KSR_LOG_LEVEL=debug

# Run migration with verbose flag
./scripts/migrate-with-ids.sh ... --verbose

# Check specific schema ID
curl -u user:pass http://registry:8081/schemas/ids/123

# List all schemas with their IDs
curl -u user:pass http://registry:8081/subjects | \
  jq -r '.[]' | \
  while read subject; do
    echo -n "$subject: "
    curl -s -u user:pass "http://registry:8081/subjects/$subject/versions/latest" | \
      jq -r '.id'
  done
```

## Best Practices

1. **Always backup before migration**
   - The script creates automatic backups
   - Keep backups for rollback purposes

2. **Test in non-production first**
   - Use --dry-run to preview changes
   - Migrate to a test environment first

3. **Verify after migration**
   - Use compare-contexts.sh to verify
   - Check that IDs match exactly
   - Test application compatibility

4. **Handle mode changes carefully**
   - Don't leave registry in IMPORT mode
   - Script automatically restores original mode
   - Monitor mode changes in production

5. **Plan for ID conflicts**
   - Ensure target registry is clean or use --force
   - Document ID mappings if conflicts occur
   - Consider ID reservation strategies

## Security Considerations

1. **Protect IMPORT mode**
   - Limit who can change registry modes
   - Audit mode changes
   - Use READONLY mode when not migrating

2. **Secure credentials**
   ```bash
   # Use environment variables for sensitive data
   export SOURCE_AUTH="api-key-here"
   export TARGET_AUTH="api-key-here"
   
   ./scripts/migrate-with-ids.sh \
     --source-auth "$SOURCE_AUTH" \
     --target-auth "$TARGET_AUTH" ...
   ```

3. **Validate schemas post-migration**
   - Ensure schemas weren't tampered with
   - Compare checksums if needed
   - Test with sample data

## Conclusion

Migrating schemas with ID preservation is essential for maintaining consistency across Schema Registry instances. The provided script automates this process while ensuring safety through backups and validation. Always test thoroughly in non-production environments before migrating production schemas.
