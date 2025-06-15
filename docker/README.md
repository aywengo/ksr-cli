# Docker Development Environment

This docker-compose setup provides a local development environment for testing the ksr-cli with:

- **Apache Kafka** (KRaft mode) on `localhost:39092`
- **Schema Registry** on `localhost:38081`
- **AKHQ** (Kafka management UI) on `localhost:38080`

## Quick Start

1. Start the services:
   ```bash
   docker-compose up -d
   ```

2. Wait for all services to be healthy:
   ```bash
   docker-compose ps
   ```

3. Configure ksr-cli to use the local Schema Registry:
   ```bash
   ksr-cli config set registry-url http://localhost:38081
   ```

## Service Details

### Kafka (KRaft Mode)
- **External Port**: `39092`
- **Internal Port**: `29092`
- **Mode**: KRaft (no Zookeeper required)
- **Cluster ID**: `MkU3OEVBNTcwNTJENDM2Qk`

### Schema Registry
- **Port**: `38081`
- **Bootstrap Server**: `kafka:29092`
- **Health Check**: `http://localhost:38081/subjects`

### AKHQ
- **Port**: `38080`
- **Access**: Open `http://localhost:38080` in your browser
- **Features**:
  - View and manage Kafka topics
  - Browse Schema Registry subjects
  - Monitor consumer groups
  - Send messages to topics

## Common Tasks

### Create a test topic
```bash
docker exec -it kafka kafka-topics --create \
  --topic test-topic \
  --bootstrap-server localhost:29092 \
  --partitions 3 \
  --replication-factor 1
```

### Register a schema
```bash
ksr-cli create schema test-subject --file examples/user.avsc
```

### View logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f schema-registry
```

### Stop services
```bash
docker-compose down

# Remove volumes (careful - this deletes all data)
docker-compose down -v
```

## Troubleshooting

### Services not starting
Check the logs for specific error messages:
```bash
docker-compose logs kafka
docker-compose logs schema-registry
docker-compose logs akhq
```

### Port conflicts
If you get port binding errors, you can modify the ports in `docker-compose.yml`:
- Change `39092:39092` to another port for Kafka
- Change `38081:38081` to another port for Schema Registry
- Change `38080:8080` to another port for AKHQ

### Health checks failing
The services have health checks with retry logic. Initial startup may take 1-2 minutes. You can monitor the health status with:
```bash
docker-compose ps
```

## Advanced Configuration

### Custom Kafka Configuration
Add environment variables to the `kafka` service in `docker-compose.yml`:
```yaml
environment:
  KAFKA_LOG_RETENTION_HOURS: 168
  KAFKA_LOG_SEGMENT_BYTES: 1073741824
```

### Schema Registry Configuration
Add environment variables to the `schema-registry` service:
```yaml
environment:
  SCHEMA_REGISTRY_AVRO_COMPATIBILITY_LEVEL: backward
```

### AKHQ Configuration
The AKHQ configuration is embedded in the `AKHQ_CONFIGURATION` environment variable. You can modify it to add authentication, change themes, or configure additional features.

## Network Details

All services are connected via the `ksr-cli-network` bridge network, allowing them to communicate using service names (e.g., `kafka:29092`).
