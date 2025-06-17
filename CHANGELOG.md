# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.x] - 2025-06-17

### Added
- Add `--registry-url` flag to specify the Schema Registry instance URL
- Add `--user` flag to specify the username for authentication
- Add `--pass` flag to specify the password for authentication
- Add `--api-key` flag to specify the API key for authentication
- Added `test_delete_commands.sh` to the comprehensive test suite in `tests/integration/test_comprehensive.sh`.
- Add `--version` flag to specify the version number to delete
- Add `--permanent` flag to specify if the subject should be permanently deleted
- Add `delete` command to delete subjects, versions, or other resources from the Schema Registry

## [0.1.x] - 2025-06-15

### Added
- Initial release of ksr-cli
- Complete CLI implementation with Cobra framework
- Cross-platform support (macOS, Linux, Windows)
- Schema Registry client with full API support
- Configuration management with file and environment variable support
- Multiple output formats (table, JSON, YAML)
- Shell completion for bash, zsh, and fish
- Authentication support (basic auth and API keys)
- Context support for multi-tenant Schema Registry
- Homebrew formula for macOS distribution
- Debian packaging for APT distribution
- GitHub Actions for automated releases
- Comprehensive documentation and examples

### Features
- `get` command for retrieving schemas, subjects, versions, and configurations
- `create` command for registering new schemas
- `check` command for compatibility validation
- `config` command for CLI configuration management
- `completion` command for shell completion scripts

### Commands
- `ksr-cli get schemas` - List all subjects or get specific schemas
- `ksr-cli get subjects` - Get all subjects
- `ksr-cli get versions SUBJECT` - Get versions for a subject
- `ksr-cli get config [SUBJECT]` - Get configuration
- `ksr-cli create schema SUBJECT` - Register a new schema
- `ksr-cli check compatibility SUBJECT` - Check schema compatibility
- `ksr-cli config init` - Initialize configuration
- `ksr-cli config set KEY VALUE` - Set configuration values
- `ksr-cli config get KEY` - Get configuration values
- `ksr-cli config list` - List all configuration
- `ksr-cli completion bash|zsh|fish|powershell` - Generate completion scripts

### Configuration
- Registry URL configuration
- Authentication (username/password, API key)
- Output format preferences
- Context support
- Environment variable support with KSR_ prefix

### Distribution
- Homebrew tap: `brew install aywengo/ksr-cli/ksr-cli`
- Debian packages for Ubuntu/Debian
- Binary releases for multiple platforms
- Automated CI/CD with GitHub Actions


[Unreleased]: https://github.com/aywengo/ksr-cli/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/aywengo/ksr-cli/releases/tag/v0.1.0
