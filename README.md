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
- ✅ **Context support** - Multi-tenant Schema Registry support
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
curl -LO https://github.com/aywengo/ksr-cli/releases/download/v1.0.0/ksr-cli-linux-amd64.tar.gz
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

### Context Support

```bash
# List subjects in specific context
ksr-cli get subjects --context my-context

# Get schema in specific context
ksr-cli get schemas my-subject --context my-context
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
context: default
```

## Environment Variables

Configuration can also be set via environment variables with the `KSR_` prefix:

```bash
export KSR_REGISTRY_URL=http://localhost:8081
export KSR_USERNAME=myuser
export KSR_PASSWORD=mypass
export KSR_OUTPUT=json
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

# Run linting
make lint
```

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
