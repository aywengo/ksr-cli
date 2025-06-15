# Test Environment for ksr-cli

This directory contains scripts and utilities for managing a local test environment for ksr-cli development and comprehensive integration testing.

## Quick Start

### Automated Integration Tests

```bash
# Run complete integration test suite (RECOMMENDED)
bash tests/run-integration-tests.sh

# The test suite automatically:
# 1. Builds ksr-cli from source
# 2. Starts Docker Compose test environment
# 3. Configures CLI for test environment
# 4. Loads test schemas from tests/test-data/schemas/
# 5. Runs comprehensive integration tests
# 6. Cleans up test environment
```

### Running Individual Test Suites

```bash
# Start test environment manually first
./tests/start-test-env.sh

# Run specific test suites
cd tests/integration/
bash test_create_commands.sh
bash test_get_commands.sh
bash test_check_commands.sh
bash test_config_commands.sh
bash test_context_operations.sh
bash test_schema_evolution.sh
bash test_export_commands.sh
bash test_import_commands.sh
bash test_import_export_integration.sh
bash test_all_versions_flag.sh

# Or run all test suites together
bash test_comprehensive.sh

# Run just the import/export tests
bash ../run-import-export-tests.sh

# Stop test environment when done
./tests/stop-test-env.sh
```

### Manual Test Environment

```bash
# Start the test environment manually
./tests/start-test-env.sh

# Check status
./tests/check-test-env.sh

# Stop the environment
./tests/stop-test-env.sh
```

## Integration Test Framework

### run-integration-tests.sh

The main integration test runner that provides end-to-end testing:

**Features:**
- **Automated build** - Runs `make build` to ensure latest CLI version
- **Environment management** - Starts/stops Docker Compose automatically
- **Service health checks** - Waits for Kafka and Schema Registry to be ready
- **CLI configuration** - Sets up test-specific configuration
- **Schema loading** - Registers test schemas from `tests/test-data/schemas/`
- **Test execution** - Runs all test scripts in `tests/integration/`
- **Cleanup** - Removes containers and networks after tests

**Test Environment:**
- **Kafka** (KRaft mode) on port 39092
- **Schema Registry** on port 38081
- **AKHQ UI** on port 38080
- **Test data** in `tests/test-data/schemas/`

### Integration Test Coverage

The integration tests validate:

#### Core Functionality
- ✅ Schema registration and retrieval
- ✅ Subject listing and management
- ✅ Version management
- ✅ Configuration management
- ✅ Compatibility checking
- ✅ Schema evolution scenarios
- ✅ Error handling and edge cases

#### Context-Aware Operations
- ✅ Default context configuration
- ✅ Context persistence across commands
- ✅ Context override via flags
- ✅ Multi-context operations
- ✅ Context isolation
- ✅ Cross-context operations

#### CLI Features
- ✅ Configuration file management
- ✅ Multiple output formats (table, json, yaml)
- ✅ Error handling
- ✅ Command-line argument parsing
- ✅ Authentication configuration
- ✅ Schema type support (AVRO, JSON)

#### Comprehensive Test Suites

**tests/integration/test_basic.sh:**
- Basic schema registration
- Context configuration
- CLI configuration persistence
- Subject listing functionality

**tests/integration/test_create_commands.sh:**
- Schema creation from files, inline JSON, and stdin
- Different schema types (AVRO, JSON)
- Context-specific schema creation
- Error handling for invalid schemas and missing files
- Schema versioning

**tests/integration/test_get_commands.sh:**
- Subject listing and retrieval
- Schema retrieval by version and subject
- Version listing
- Configuration retrieval (global and subject-specific)
- Output format testing (JSON, YAML, table)
- Context-specific operations
- Error handling for non-existent resources

**tests/integration/test_check_commands.sh:**
- Schema compatibility checking
- Compatible and incompatible schema detection
- Inline schema and file-based compatibility
- Context-specific compatibility checks
- Different schema type compatibility
- Error handling and validation

**tests/integration/test_config_commands.sh:**
- Configuration initialization
- Setting and getting all configuration values
- Authentication credentials management
- Output format configuration
- Context configuration
- Error handling for invalid values
- Configuration persistence

**tests/integration/test_context_operations.sh:**
- Multi-context schema operations
- Context isolation verification
- Default context behavior
- Context override functionality
- Cross-context operations
- Context-specific compatibility checks
- Schema evolution within contexts

**tests/integration/test_schema_evolution.sh:**
- Schema version management
- Backward compatibility preservation
- Compatible schema evolution
- Incompatible schema rejection
- Version-specific operations
- Multiple evolution steps
- Complex schema type evolution

**tests/integration/test_export_commands.sh:**
- Subject and schema export functionality
- Export to stdout, files, and directories
- Export with and without all versions
- Export format validation (JSON, YAML)
- Export metadata and configuration inclusion
- Context-specific exports
- Error handling for non-existent subjects

**tests/integration/test_import_commands.sh:**
- Subject and schema import functionality
- Import from files and directories
- Dry-run import validation
- Skip existing and force import options
- Cross-context import operations
- Import error handling and recovery
- Import summary validation

**tests/integration/test_import_export_integration.sh:**
- End-to-end backup and restore workflows
- Cross-context migration scenarios
- Export-import roundtrip data integrity
- Bulk operations and performance testing
- Error recovery and partial imports
- Configuration preservation during migration
- Directory-based backup strategies

**tests/integration/test_all_versions_flag.sh:**
- --all-versions flag functionality across commands
- Backward compatibility with --all flag
- Version count validation
- Export format compatibility with version flags
- JSON structure validation for multi-version exports
- Help documentation validation

**tests/integration/test_comprehensive.sh:**
- Orchestrates all individual test suites
- Provides comprehensive test reporting
- Summary of test results across all areas

### Test Data

**tests/test-data/schemas/:**
Contains sample Avro schemas used for testing:
- `order.avsc` - Order event schema
- `user.avsc` - User profile schema
- Additional schemas for comprehensive testing

### Docker Compose Environment

**tests/docker-compose.yml:**
Defines the test environment with:
- **Kafka** with KRaft mode (no Zookeeper required)
- **Schema Registry** with proper health checks
- **AKHQ** for manual inspection and debugging
- **Optimized startup** with proper service dependencies

## Manual Testing Examples

### Context-Aware Operations

```bash
# Start the environment
./tests/start-test-env.sh

# Configure ksr-cli for test environment
ksr-cli config init
ksr-cli config set registry-url http://localhost:38081

# Test default context operations
ksr-cli config set context production
ksr-cli get subjects  # Uses 'production' context

# Test context override
ksr-cli get subjects --context staging  # Uses 'staging' context

# Test context persistence
ksr-cli config get context  # Should show 'production'
```

### Schema Operations with Context

```bash
# Create test schema in specific context
echo '{
  "type": "record",
  "name": "User",
  "fields": [
    {"name": "id", "type": "long"},
    {"name": "name", "type": "string"},
    {"name": "email", "type": "string"}
  ]
}' > user.avsc

# Register schema with default context
ksr-cli create schema user-value --file user.avsc

# Register schema in specific context
ksr-cli create schema user-value --file user.avsc --context development

# List subjects in different contexts
ksr-cli get subjects --context production
ksr-cli get subjects --context development

# Get schema from specific context
ksr-cli get schemas user-value --context development
```

### Compatibility Testing with Context

```bash
# Create evolved schema
echo '{
  "type": "record",
  "name": "User",
  "fields": [
    {"name": "id", "type": "long"},
    {"name": "name", "type": "string"},
    {"name": "email", "type": "string"},
    {"name": "age", "type": ["null", "int"], "default": null}
  ]
}' > user-v2.avsc

# Check compatibility in specific context
ksr-cli check compatibility user-value --file user-v2.avsc --context production
```

## Scripts

### start-test-env.sh
Starts the Docker Compose environment with:
- Kafka (KRaft mode) on port 39092
- Schema Registry on port 38081  
- AKHQ on port 38080

The script will:
- Verify Docker and docker-compose are installed
- Start all services
- Wait for health checks to pass
- Display connection information

### stop-test-env.sh
Stops and cleans up the test environment.

Options:
- `-v, --volumes` - Remove volumes (deletes all data)
- `-i, --images` - Remove downloaded Docker images
- `-a, --all` - Remove everything (volumes and images)
- `-h, --help` - Show help message

Examples:
```bash
# Stop containers only (preserves data)
./tests/stop-test-env.sh

# Stop and remove all data
./tests/stop-test-env.sh --volumes

# Complete cleanup
./tests/stop-test-env.sh --all
```

### check-test-env.sh
Checks the status of the test environment:
- Container status
- Service health endpoints
- Connection URLs

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Go
        uses: actions/setup-go@v3
        with:
          go-version: 1.21
          
      - name: Run Integration Tests
        run: bash tests/run-integration-tests.sh
        
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: tests/results/
```

### Local Development Workflow

```bash
# Development cycle
make build                           # Build CLI
bash tests/run-integration-tests.sh  # Run full test suite

# Quick testing during development
./tests/start-test-env.sh           # Start environment
ksr-cli config set registry-url http://localhost:38081
# ... manual testing ...
./tests/stop-test-env.sh            # Cleanup
```

## Troubleshooting

### Integration Test Failures

**Build Failures:**
```bash
# Ensure Go dependencies are up to date
go mod tidy
make build
```

**Docker Issues:**
```bash
# Check Docker daemon
docker info

# Clean up Docker resources
docker system prune -f
```

**Port Conflicts:**
```bash
# Check what's using the ports
lsof -i :38081
lsof -i :39092

# Stop conflicting services or modify docker-compose.yml
```

**Service Health Check Failures:**
```bash
# Check service logs
docker-compose -f tests/docker-compose.yml logs kafka
docker-compose -f tests/docker-compose.yml logs schema-registry

# Restart with fresh state
./tests/stop-test-env.sh --volumes
./tests/start-test-env.sh
```

### Context-Related Issues

**Context Not Persisting:**
```bash
# Check configuration file location
ksr-cli config list

# Verify context is saved
ksr-cli config get context

# Reset configuration if needed
ksr-cli config reset
ksr-cli config init
```

**Context Override Not Working:**
```bash
# Verify flag syntax
ksr-cli get subjects --context my-context

# Check available contexts (if Schema Registry supports listing)
# Note: Context listing depends on Schema Registry configuration
```

## Advanced Testing

### Performance Testing

```bash
# Start environment
./tests/start-test-env.sh

# Register multiple schemas
for i in {1..100}; do
  ksr-cli create schema "test-subject-$i" --schema '{"type":"string"}'
done

# Measure retrieval performance
time ksr-cli get subjects
```

### Multi-Context Testing

```bash
# Test multiple contexts simultaneously
contexts=("production" "staging" "development")

for ctx in "${contexts[@]}"; do
  echo "Testing context: $ctx"
  ksr-cli config set context "$ctx"
  ksr-cli create schema "test-$ctx" --schema '{"type":"string"}'
  ksr-cli get subjects
done
```

### Error Condition Testing

```bash
# Test invalid schema
echo '{"invalid": json}' | ksr-cli create schema test-invalid

# Test non-existent subject
ksr-cli get schemas non-existent-subject

# Test invalid context
ksr-cli get subjects --context invalid-context
```
