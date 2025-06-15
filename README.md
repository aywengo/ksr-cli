# ksr-cli - Kafka Schema Registry CLI

[![Build Status](https://github.com/aywengo/ksr-cli/workflows/Build/badge.svg)](https://github.com/aywengo/ksr-cli/actions)
[![Release](https://github.com/aywengo/ksr-cli/workflows/Release/badge.svg)](https://github.com/aywengo/ksr-cli/releases)
[![Go Report Card](https://goreportcard.com/badge/github.com/aywengo/ksr-cli)](https://goreportcard.com/report/github.com/aywengo/ksr-cli)
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
- ✅ **Context-aware operations** - Multi-tenant Schema Registry support with configurable default context
- ✅ **Integration testing** - Comprehensive test suite with Docker-based test environment
- ✅ **Package distribution** - Available via Homebrew and APT repositories

## Installation

### Homebrew (macOS and Linux)

```bash
# Add the tap
brew tap aywengo/ksr-cli

# Install ksr-cli
brew install ksr-cli
```

### APT (Ubuntu/Debian)

```bash
# Add the repository
curl -fsSL https://your-repo.com/gpg-key | sudo apt-key add -
echo "deb https://your-repo.com/apt stable main" | sudo tee /etc/apt/sources.list.d/ksr-cli.list

# Update and install
sudo apt update
sudo apt install ksr-cli
```

### Manual Installation

Download the appropriate binary for your platform from the [releases page](https://github.com/aywengo/ksr-cli/releases):

```bash
# Download and install (replace with actual version and platform)
curl -LO https://github.com/aywengo/ksr-cli/releases/download/v0.1.0/ksr-cli-linux-amd64.tar.gz
tar xzf ksr-cli-linux-amd64.tar.gz
sudo mv ksr-cli /usr/local/bin/
```

### Build from Source

```bash
git clone https://github.com/aywengo/ksr-cli.git
cd ksr-cli
make build
```

## Quick Start

1. **Initialize configuration:**
   ```bash
   ksr-cli config init
   ```

2. **Set your Schema Registry URL:**
   ```bash
   ksr-cli config set registry-url http://localhost:8081
   ```

3. **List all subjects:**
   ```bash
   ksr-cli get subjects
   ```

4. **Get a schema:**
   ```bash
   ksr-cli get schemas my-subject
   ```

## Usage

### Available Commands

**Schema Operations:**
- `ksr-cli get subjects` - List all subjects
- `ksr-cli get schemas [SUBJECT]` - Get schemas
- `ksr-cli get versions SUBJECT` - Get versions for a subject
- `ksr-cli create schema SUBJECT` - Register a new schema
- `ksr-cli check compatibility SUBJECT` - Check schema compatibility

**Configuration Management:**
- `ksr-cli get config [SUBJECT]` - Get configuration
- `ksr-cli config set KEY VALUE` - Set CLI configuration

**Mode Management:**
- `ksr-cli get mode [SUBJECT]` - Get mode configuration
- `ksr-cli set mode [SUBJECT] MODE` - Set mode configuration

**Context Operations:**
- All commands support `--context` flag for multi-tenant environments

### Configuration

ksr-cli uses a configuration file to store connection details and preferences. The configuration file is located at `~/.ksr-cli.yaml` by default.

```bash
# Initialize configuration
ksr-cli config init

# Set registry URL
ksr-cli config set registry-url http://localhost:8081

# Set authentication (choose one)
ksr-cli config set username myuser
ksr-cli config set password mypass
# OR
ksr-cli config set api-key your-api-key

# Set default output format
ksr-cli config set output json

# View all configuration
ksr-cli config list
```

### Getting Schemas and Subjects

```bash
# List all subjects
ksr-cli get subjects

# Get latest schema for a subject
ksr-cli get schemas my-subject

# Get specific schema version
ksr-cli get schemas my-subject --version 2

# Get all versions of a schema
ksr-cli get schemas my-subject --all

# Get all versions for a subject
ksr-cli get versions my-subject
```

### Creating Schemas

```bash
# Register schema from file
ksr-cli create schema my-subject --file schema.avsc

# Register schema from string
ksr-cli create schema my-subject --schema '{"type":"string"}'

# Register JSON schema
ksr-cli create schema my-subject --file schema.json --type JSON

# Register schema from stdin
cat schema.avsc | ksr-cli create schema my-subject
```

### Compatibility Checking

```bash
# Check if schema is compatible
ksr-cli check compatibility my-subject --file new-schema.avsc

# Check compatibility with inline schema
ksr-cli check compatibility my-subject --schema '{"type":"string"}'
```

### Configuration Management

```bash
# Get global configuration
ksr-cli get config

# Get subject-specific configuration
ksr-cli get config my-subject
```

### Mode Management

Schema Registry supports different modes that control its behavior:

```bash
# Get global mode
ksr-cli get mode

# Get subject-specific mode
ksr-cli get mode my-subject

# Set global mode
ksr-cli set mode READWRITE
ksr-cli set mode READONLY
ksr-cli set mode IMPORT

# Set subject-specific mode
ksr-cli set mode my-subject READWRITE
ksr-cli set mode my-subject READONLY
```

**Available Modes:**
- **READWRITE**: Normal operation (default) - allows all operations
- **READONLY**: Only read operations are allowed - no schema registration or updates
- **IMPORT**: Schema Registry is in import mode - allows importing schemas with specific IDs

### Context Support

ksr-cli supports Schema Registry contexts for multi-tenant environments. You can set a default context in your configuration and override it per command when needed.

```bash
# Set default context for all operations
ksr-cli config set context production

# All commands now use 'production' context by default
ksr-cli get subjects
ksr-cli create schema my-subject --file schema.avsc
ksr-cli check compatibility my-subject --file new-schema.avsc

# Override context for specific commands
ksr-cli get subjects --context staging
ksr-cli get schemas my-subject --context development

# Check current default context
ksr-cli config get context

# Reset to default context (.)
ksr-cli config set context .

# List subjects in multiple contexts
ksr-cli get subjects --context production
ksr-cli get subjects --context staging
ksr-cli get subjects --context development
```

**Context Configuration Examples:**
```bash
# Development workflow
ksr-cli config set context development
ksr-cli config set registry-url http://dev-schema-registry:8081

# Production workflow  
ksr-cli config set context production
ksr-cli config set registry-url http://prod-schema-registry:8081

# Multi-environment operations
ksr-cli get subjects --context production --output json > prod-subjects.json
ksr-cli get subjects --context staging --output json > staging-subjects.json
```

### Output Formats

ksr-cli supports multiple output formats:

```bash
# Table format (default)
ksr-cli get subjects

# JSON format
ksr-cli get subjects --output json

# YAML format
ksr-cli get subjects --output yaml
```

## Configuration File

The configuration file (`~/.ksr-cli.yaml`) supports the following options:

```yaml
registry-url: http://localhost:8081
username: myuser
password: mypass
api-key: your-api-key
output: table
timeout: 30s
insecure: false
context: production  # Default context for all operations
```

## Environment Variables

Configuration can also be set via environment variables with the `KSR_` prefix:

```bash
export KSR_REGISTRY_URL=http://localhost:8081
export KSR_USERNAME=myuser
export KSR_PASSWORD=mypass
export KSR_OUTPUT=json
export KSR_CONTEXT=production
```

## Shell Completion

Enable shell completion for a better CLI experience:

```bash
# Bash
echo 'source <(ksr-cli completion bash)' >> ~/.bashrc

# Zsh
echo 'source <(ksr-cli completion zsh)' >> ~/.zshrc

# Fish
ksr-cli completion fish | source
```

## Development

### Prerequisites

- Go 1.21 or later
- Make
- golangci-lint (for linting)

### Building

```bash
# Install development dependencies
make dev-setup

# Build for current platform
make build

# Build for all platforms
make build-all

# Run tests
make test

# Run integration tests
make test-integration

# Run linting
make lint
```

### Integration Testing

ksr-cli includes a comprehensive integration test suite that uses Docker Compose to create a realistic test environment:

```bash
# Run all integration tests
bash tests/run-integration-tests.sh

# The test suite will:
# 1. Build the CLI from source
# 2. Start Kafka and Schema Registry via Docker Compose
# 3. Configure the CLI to use the test environment
# 4. Load test schemas from tests/test-data/schemas/
# 5. Run integration tests including context functionality
# 6. Clean up the test environment
```

**Test Environment Components:**
- **Kafka** (KRaft mode) on port 39092
- **Schema Registry** on port 38081
- **AKHQ UI** on port 38080 for manual testing
- **Test schemas** in `tests/test-data/schemas/`

**Integration Test Coverage:**
- Schema registration and retrieval
- Context configuration and usage
- CLI configuration management
- Multi-format output validation
- Error handling and edge cases

For more details on the test environment, see [tests/README.md](tests/README.md).

### Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Project Structure

```
ksr-cli/
├── cmd/                    # CLI commands
├── internal/               # Internal packages
│   ├── client/            # Schema Registry client
│   ├── config/            # Configuration management
│   └── output/            # Output formatters
├── pkg/                   # Public packages
├── scripts/               # Build and packaging scripts
├── packaging/             # Distribution files
├── .github/workflows/     # GitHub Actions
└── docs/                  # Documentation
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Cobra](https://github.com/spf13/cobra) for the CLI framework
- [Viper](https://github.com/spf13/viper) for configuration management
- [go-pretty](https://github.com/jedib0t/go-pretty) for table formatting

## Support

- 📖 [Documentation](docs/)
- 🐛 [Issue Tracker](https://github.com/aywengo/ksr-cli/issues)
- 💬 [Discussions](https://github.com/aywengo/ksr-cli/discussions)

---

Made with ❤️ for Kafka community
