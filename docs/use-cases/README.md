# ksr-cli Use Cases Documentation

This directory contains detailed documentation for common use cases when working with ksr-cli and Kafka Schema Registry.

## Available Use Cases

### 1. [Comparing Schema Registry Contexts](./compare-schema-registry-contexts.md)

Learn how to:
- Compare schemas between different contexts in the same registry
- Compare schemas across different Schema Registry instances
- Generate comparison reports
- Use tools like `jq`, `diff`, and `vimdiff` for schema analysis
- Automate schema drift detection

### 2. [Migrating Schemas Between Contexts](./migrate-schemas-between-contexts.md)

Comprehensive guide for:
- Migrating schemas within the same Schema Registry (different contexts)
- Cross-registry schema migration
- Bulk migration strategies
- Migration validation and rollback procedures
- Performance optimization for large-scale migrations

## Prerequisites

Before working with these use cases, ensure you have:

1. **ksr-cli installed** - Follow the [installation guide](../../README.md#installation)
2. **Schema Registry access** - Proper credentials and network access
3. **Command-line tools**:
   - `jq` - For JSON processing
   - `diff` - For comparing files
   - `curl` - For direct API calls (troubleshooting)
   - `parallel` (optional) - For parallel processing

## Configuration Examples

### Multiple Registry Configuration

Create a configuration file for working with multiple registries:

```yaml
# ~/.ksr-cli-multi.yaml
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
```

### Using Command-Line Flags

```bash
# Basic authentication
ksr-cli subjects list \
  --registry-url http://registry.example.com:8081 \
  --user myuser \
  --pass mypass

# API key authentication
ksr-cli subjects list \
  --registry-url http://registry.example.com:8081 \
  --api-key your-api-key

# Working with contexts
ksr-cli subjects list \
  --registry-url http://registry.example.com:8081 \
  --context production
```

## Common Patterns

### Export and Backup

```bash
# Export all schemas with versions
ksr-cli export subjects --all-versions -f backup-$(date +%Y%m%d).json

# Export specific context
ksr-cli export subjects --context production --all-versions -f prod-backup.json

# Export to directory structure
ksr-cli export subjects --directory ./schema-backups/
```

### Schema Validation

```bash
# Check compatibility before registration
ksr-cli compatibility check my-subject --file new-schema.avsc

# Validate schema format
jq -e . schema.json > /dev/null 2>&1 && echo "Valid JSON" || echo "Invalid JSON"
```

### Monitoring and Health Checks

```bash
# Check registry connectivity
ksr-cli check --registry-url http://registry.example.com:8081

# Get registry mode
ksr-cli mode get -o json | jq -r '.mode'

# Count schemas
ksr-cli subjects list -o json | jq '. | length'
```

## Best Practices

1. **Always test in non-production environments first**
2. **Create backups before any migration or bulk operation**
3. **Use version control for schema definitions**
4. **Implement proper authentication and authorization**
5. **Monitor schema registry health and performance**
6. **Document schema changes and migrations**
7. **Use consistent naming conventions for subjects**
8. **Implement CI/CD pipelines for schema management**

## Troubleshooting

### Enable Debug Logging

```bash
export KSR_LOG_LEVEL=debug
ksr-cli subjects list
```

### Verbose Output

```bash
ksr-cli subjects list --verbose
```

### Direct API Testing

```bash
# Test with curl
curl -u "user:pass" http://registry.example.com:8081/subjects

# Test with API key
curl -H "Authorization: Bearer $API_KEY" http://registry.example.com:8081/subjects
```

## Contributing

If you have additional use cases or improvements to existing documentation:

1. Fork the repository
2. Create a feature branch
3. Add your use case documentation
4. Submit a pull request

## Support

For questions or issues:
- Check the [main README](../../README.md)
- Open an [issue](https://github.com/aywengo/ksr-cli/issues)
- Join the [discussions](https://github.com/aywengo/ksr-cli/discussions)
