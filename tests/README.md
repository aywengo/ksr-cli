# Test Environment for ksr-cli

This directory contains scripts and utilities for managing a local test environment for ksr-cli development and testing.

## Quick Start

```bash
# Start the test environment
./tests/start-test-env.sh

# Check status
./tests/check-test-env.sh

# Stop the environment
./tests/stop-test-env.sh
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

## Test Examples

### Basic Schema Operations

```bash
# Start the environment
./tests/start-test-env.sh

# Configure ksr-cli
ksr-cli config set registry-url http://localhost:38081

# Create a test schema
echo '{
  "type": "record",
  "name": "User",
  "fields": [
    {"name": "id", "type": "long"},
    {"name": "name", "type": "string"},
    {"name": "email", "type": "string"}
  ]
}' > user.avsc

# Register the schema
ksr-cli create schema user-value --file user.avsc

# List subjects
ksr-cli get subjects

# Get schema
ksr-cli get schemas user-value

# Check compatibility
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

ksr-cli check compatibility user-value --file user-v2.avsc
```

### Integration Testing

The test environment can be used for automated integration tests:

```bash
# In your test scripts
./tests/start-test-env.sh

# Run your tests
go test ./... -tags=integration

# Cleanup
./tests/stop-test-env.sh --volumes
```

## Troubleshooting

### Port Conflicts
If you get port binding errors, the ports might already be in use. Either:
1. Stop the conflicting services
2. Modify the ports in `docker-compose.yml`

### Slow Startup
Initial startup can take 1-2 minutes as Docker downloads images and services initialize. Subsequent starts are faster.

### Health Check Failures
If services fail health checks:
1. Check Docker logs: `docker-compose logs [service-name]`
2. Ensure Docker has enough resources allocated
3. Try stopping and starting again

### Connection Refused
If ksr-cli cannot connect:
1. Verify services are running: `./tests/check-test-env.sh`
2. Check the registry URL: `ksr-cli config get registry-url`
3. Ensure no firewall is blocking localhost connections

## Advanced Usage

### Custom Kafka Topics
```bash
# Create a topic
docker exec -it kafka kafka-topics --create \
  --topic test-events \
  --bootstrap-server localhost:29092 \
  --partitions 3 \
  --replication-factor 1

# List topics
docker exec -it kafka kafka-topics --list \
  --bootstrap-server localhost:29092
```

### Produce/Consume Messages
```bash
# Produce messages
docker exec -it kafka kafka-console-producer \
  --broker-list localhost:29092 \
  --topic test-events

# Consume messages
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:29092 \
  --topic test-events \
  --from-beginning
```

### Access AKHQ UI
Open http://localhost:38080 in your browser to:
- View and manage topics
- Browse Schema Registry
- Monitor consumer groups
- Send test messages

## CI/CD Integration

For GitHub Actions or other CI systems:

```yaml
- name: Start test environment
  run: ./tests/start-test-env.sh

- name: Run integration tests
  run: |
    ksr-cli config set registry-url http://localhost:38081
    go test ./... -tags=integration

- name: Stop test environment
  if: always()
  run: ./tests/stop-test-env.sh --volumes
```
