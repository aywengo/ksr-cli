# ksr-cli - Kafka Schema Registry CLI

[![Release](https://img.shields.io/github/v/release/aywengo/ksr-cli)](https://github.com/aywengo/ksr-cli/releases)
[![Go Version](https://img.shields.io/badge/go-1.21+-blue.svg)](https://golang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive command-line interface for managing Kafka Schema Registry. Built with Go for cross-platform compatibility and distributed via Homebrew and APT repositories.

## Features

- ✅ **Cross-platform support** - Works on macOS, Linux, and Windows
- ✅ **Multiple output formats** - JSON, YAML, and formatted tables
- ✅ **Configuration management** - File-based configuration with environment variable support
- ✅ **Shell completion** - Bash, Zsh, and Fish completion scripts
- ✅ **Authentication support** - Basic auth and API key authentication
- ✅ **Schema operations** - Get, create, delete, and manage schemas
- ✅ **Compatibility checking** - Validate schema compatibility
- ✅ **Import/Export functionality** - Backup, migrate, and synchronize Schema Registry instances
- ✅ **Context-aware operations** - Multi-tenant Schema Registry support with configurable default context
- ✅ **Integration testing** - Comprehensive test suite with Docker-based test environment
- ✅ **Package distribution** - Available via Homebrew and APT repositories

## Installation

### Homebrew (macOS and Linux)

```bash
# Install ksr-cli
brew install aywengo/tap/ksr-cli

# Verify installation
ksr-cli --version
```

### APT (Ubuntu/Debian)

```bash
# Download the latest .deb package
wget https://github.com/aywengo/ksr-cli/releases/latest/download/ksr-cli_0.1.1_amd64.deb

# Install the package
sudo dpkg -i ksr-cli_0.1.1_amd64.deb

# Verify installation
ksr-cli --version
```

### Manual Installation

Download the appropriate binary for your platform from the [releases page](https://github.com/aywengo/ksr-cli/releases):

```bash
# Linux AMD64
wget https://github.com/aywengo/ksr-cli/releases/latest/download/ksr-cli-linux-amd64.tar.gz
tar xzf ksr-cli-linux-amd64.tar.gz
chmod +x ksr-cli
sudo mv ksr-cli /usr/local/bin/

# macOS Intel
wget https://github.com/aywengo/ksr-cli/releases/latest/download/ksr-cli-darwin-amd64.tar.gz
tar xzf ksr-cli-darwin-amd64.tar.gz
chmod +x ksr-cli
sudo mv ksr-cli /usr/local/bin/

# macOS Apple Silicon
wget https://github.com/aywengo/ksr-cli/releases/latest/download/ksr-cli-darwin-arm64.tar.gz
tar xzf ksr-cli-darwin-arm64.tar.gz
chmod +x ksr-cli
sudo mv ksr-cli /usr/local/bin/

# Windows
# Download ksr-cli-windows-amd64.tar.gz from releases page
# Extract and add to PATH
```

### Build from Source

```bash
git clone https://github.com/aywengo/ksr-cli.git
cd ksr-cli
make build
sudo make install
```

## Quick Start

1. **Check connection to Schema Registry:**
   ```bash
   ksr-cli check
   ```

2. **Set your Schema Registry URL (if not using default localhost:8081):**
   ```bash
   # Using environment variable
   export KSR_REGISTRY_URL=http://your-registry:8081
   
   # Or create a config file
   echo "registry-url: http://your-registry:8081" > ~/.ksr-cli.yaml
   ```

3. **List all subjects:**
   ```bash
   ksr-cli subjects list
   ```

4. **Get a schema:**
   ```bash
   ksr-cli schema get my-subject
   ```

## Usage

### Available Commands

**Connection Check:**
- `ksr-cli check` - Verify connection to Schema Registry

**Schema Operations:**
- `ksr-cli subjects list` - List all subjects
- `ksr-cli schema get SUBJECT [--version VERSION]` - Get schema for a subject
- `ksr-cli schema register SUBJECT --file schema.avsc` - Register a new schema
- `ksr-cli schema delete SUBJECT [--version VERSION]` - Delete a schema
- `ksr-cli subject delete SUBJECT` - Delete a subject and all its schemas
- `ksr-cli compatibility check SUBJECT --file schema.avsc` - Check schema compatibility

**Configuration Management:**
- `ksr-cli config get [--subject SUBJECT]` - Get global or subject configuration
- `ksr-cli config set [--subject SUBJECT] --compatibility LEVEL` - Set compatibility level

**Mode Management:**
- `ksr-cli mode get [--subject SUBJECT]` - Get mode (READWRITE/READONLY/IMPORT)
- `ksr-cli mode set MODE [--subject SUBJECT]` - Set mode

**Context Operations:**
- `ksr-cli contexts list` - List available contexts
- All commands support `--context` flag for multi-tenant environments

**Import/Export Operations:**
- `ksr-cli export subjects [--all-versions] [-f backup.json]` - Export schemas
- `ksr-cli export subject SUBJECT [--all-versions] [-f subject.json]` - Export specific subject
- `ksr-cli import subjects --file backup.json` - Import schemas (future release)

### Configuration

ksr-cli can be configured through multiple methods (in order of precedence):
1. Command-line flags
2. Environment variables (prefixed with `KSR_`)
3. Configuration file (`~/.ksr-cli.yaml`)

**Configuration File Example:**
```yaml
registry-url: http://localhost:8081
output: table  # json, yaml, or table
context: production  # default context
timeout: 30s
insecure: false

# Authentication (optional)
auth:
  username: myuser
  password: mypass
  # OR use API key
  api-key: your-api-key
```

**Environment Variables:**
```bash
export KSR_REGISTRY_URL=http://localhost:8081
export KSR_OUTPUT=json
export KSR_CONTEXT=production
export KSR_USERNAME=myuser
export KSR_PASSWORD=mypass
```

### Working with Schemas

```bash
# List all subjects
ksr-cli subjects list

# Get latest schema for a subject
ksr-cli schema get my-subject

# Get specific schema version
ksr-cli schema get my-subject --version 2

# Register a new schema from file
ksr-cli schema register my-subject --file schema.avsc

# Register a JSON schema
ksr-cli schema register my-subject --file schema.json --type JSON

# Check if a new schema is compatible
ksr-cli compatibility check my-subject --file new-schema.avsc

# Delete a specific version
ksr-cli schema delete my-subject --version 1

# Delete entire subject
ksr-cli subject delete my-subject
```

### Compatibility Management

```bash
# Get global compatibility level
ksr-cli config get

# Set global compatibility
ksr-cli config set --compatibility BACKWARD

# Get subject-specific compatibility
ksr-cli config get --subject my-subject

# Set subject-specific compatibility
ksr-cli config set --subject my-subject --compatibility NONE

# Available compatibility levels:
# - BACKWARD (default)
# - BACKWARD_TRANSITIVE
# - FORWARD
# - FORWARD_TRANSITIVE
# - FULL
# - FULL_TRANSITIVE
# - NONE
```

### Schema Registry Modes

```bash
# Get current mode
ksr-cli mode get

# Set to read-only mode
ksr-cli mode set READONLY

# Set back to normal mode
ksr-cli mode set READWRITE

# Set import mode (for importing with specific IDs)
ksr-cli mode set IMPORT

# Set mode for specific subject
ksr-cli mode set --subject my-subject READONLY
```

### Context Support (Multi-tenant)

```bash
# List available contexts
ksr-cli contexts list

# Use specific context for a command
ksr-cli subjects list --context production

# Set default context in config
echo "context: production" >> ~/.ksr-cli.yaml

# Export schemas from one context
ksr-cli export subjects --context production -f prod-backup.json

# Work with different contexts
ksr-cli schema get my-subject --context development
ksr-cli schema get my-subject --context staging
ksr-cli schema get my-subject --context production
```

### Import/Export

```bash
# Export all subjects (latest versions)
ksr-cli export subjects -f backup.json

# Export all subjects with all versions
ksr-cli export subjects --all-versions -f full-backup.json

# Export specific subject
ksr-cli export subject my-subject -f my-subject.json

# Export to directory (one file per subject)
ksr-cli export subjects --directory ./schemas/

# Export in YAML format
ksr-cli export subjects --output yaml -f backup.yaml

# Include/exclude configurations
ksr-cli export subjects --include-config=false -f schemas-only.json
```

### Output Formats

```bash
# Table format (default)
ksr-cli subjects list

# JSON format
ksr-cli subjects list --output json

# YAML format
ksr-cli subjects list --output yaml

# Pretty-printed JSON
ksr-cli subjects list -o json | jq .
```

## Shell Completion

Enable shell completion for better CLI experience:

```bash
# Bash
ksr-cli completion bash > /etc/bash_completion.d/ksr-cli

# Zsh
ksr-cli completion zsh > "${fpath[1]}/_ksr-cli"

# Fish
ksr-cli completion fish > ~/.config/fish/completions/ksr-cli.fish

# PowerShell
ksr-cli completion powershell > ksr-cli.ps1
# Then add to your profile: . ./ksr-cli.ps1
```

## Advanced Usage

### Scripting Examples

**Backup all schemas:**
```bash
#!/bin/bash
BACKUP_DIR="schema-backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Export all schemas with versions
ksr-cli export subjects --all-versions -f "$BACKUP_DIR/all-schemas.json"

# Also export individual subjects
for subject in $(ksr-cli subjects list -o json | jq -r '.[]'); do
  ksr-cli export subject "$subject" --all-versions -f "$BACKUP_DIR/$subject.json"
done
```

**Check compatibility before deployment:**
```bash
#!/bin/bash
SUBJECT="my-service-value"
SCHEMA_FILE="schemas/my-service.avsc"

if ksr-cli compatibility check "$SUBJECT" --file "$SCHEMA_FILE"; then
  echo "✅ Schema is compatible"
  ksr-cli schema register "$SUBJECT" --file "$SCHEMA_FILE"
else
  echo "❌ Schema is NOT compatible"
  exit 1
fi
```

**Monitor Schema Registry:**
```bash
#!/bin/bash
# Check if Schema Registry is accessible
if ! ksr-cli check > /dev/null 2>&1; then
  echo "❌ Schema Registry is not accessible"
  exit 1
fi

# Get registry mode
MODE=$(ksr-cli mode get -o json | jq -r .mode)
if [ "$MODE" != "READWRITE" ]; then
  echo "⚠️  Registry is in $MODE mode"
fi

# Count subjects
COUNT=$(ksr-cli subjects list -o json | jq '. | length')
echo "📊 Total subjects: $COUNT"
```

## Troubleshooting

### Connection Issues

```bash
# Test connection with verbose output
ksr-cli check

# Check with custom URL
KSR_REGISTRY_URL=http://localhost:8081 ksr-cli check

# Ignore SSL certificate errors (development only!)
ksr-cli check --insecure
```

### Authentication

```bash
# Basic authentication via URL
export KSR_REGISTRY_URL=http://user:pass@localhost:8081

# Basic authentication via config
cat >> ~/.ksr-cli.yaml << EOF
auth:
  username: myuser
  password: mypass
EOF

# API key authentication
cat >> ~/.ksr-cli.yaml << EOF
auth:
  api-key: your-api-key
EOF
```

### Debug Output

```bash
# Enable debug logging
export KSR_LOG_LEVEL=debug
ksr-cli subjects list

# Verbose curl-like output
ksr-cli subjects list --verbose
```

## Development

### Prerequisites

- Go 1.21 or later
- Make
- Docker and Docker Compose (for integration tests)

### Building

```bash
# Clone the repository
git clone https://github.com/aywengo/ksr-cli.git
cd ksr-cli

# Install dependencies
make deps

# Build binary
make build

# Run tests
make test

# Run linting
make lint

# Build for all platforms
make build-all
```

### Running Integration Tests

```bash
# Run integration test suite
cd tests
./run-integration-tests.sh

# The test suite will:
# 1. Start Kafka and Schema Registry in Docker
# 2. Run integration tests
# 3. Clean up containers
```

### Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure:
- All tests pass (`make test`)
- Code is properly formatted (`make fmt`)
- Linting passes (`make lint`)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Cobra](https://github.com/spf13/cobra) for the CLI framework
- [Viper](https://github.com/spf13/viper) for configuration management
- [go-pretty](https://github.com/jedib0t/go-pretty) for table formatting
- [testcontainers-go](https://github.com/testcontainers/testcontainers-go) for integration testing

## Support

- 🐛 [Report Issues](https://github.com/aywengo/ksr-cli/issues)
- 💡 [Request Features](https://github.com/aywengo/ksr-cli/issues/new?labels=enhancement)
- 💬 [Discussions](https://github.com/aywengo/ksr-cli/discussions)
- 📖 [Wiki](https://github.com/aywengo/ksr-cli/wiki)

---

Made with ❤️ by [Roman Melnyk](https://github.com/aywengo) for the Kafka community
