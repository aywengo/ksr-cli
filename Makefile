# Makefile for ksr-cli

# Build variables
BINARY_NAME=ksr-cli
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME=$(shell date +%FT%T%z)
LDFLAGS=-ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"

# Go variables
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod
GOFMT=gofmt

# Directories
BUILD_DIR=build
DIST_DIR=dist

# Supported platforms
PLATFORMS=darwin/amd64 darwin/arm64 linux/amd64 linux/arm64 windows/amd64

.PHONY: all build clean test deps fmt lint vet build-all package-deb package-rpm homebrew-formula

# Default target
all: clean deps test build

# Build for current platform
build:
	@echo "Building $(BINARY_NAME) for current platform..."
	$(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) .

# Clean build artifacts
clean:
	@echo "Cleaning..."
	$(GOCLEAN)
	rm -rf $(BUILD_DIR)
	rm -rf $(DIST_DIR)

# Run tests
test:
	@echo "Running tests..."
	$(GOTEST) -v ./...

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	$(GOTEST) -v -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html

# Download dependencies
deps:
	@echo "Downloading dependencies..."
	$(GOMOD) download
	$(GOMOD) tidy

# Format code
fmt:
	@echo "Formatting code..."
	$(GOFMT) -s -w .

# Lint code
lint:
	@echo "Linting code..."
	golangci-lint run

# Vet code
vet:
	@echo "Vetting code..."
	$(GOCMD) vet ./...

# Cross-compile for all platforms
build-all: clean
	@echo "Building for all platforms..."
	@mkdir -p $(DIST_DIR)
	@for platform in $(PLATFORMS); do \
		echo "Building for $$platform..."; \
		GOOS=$$(echo $$platform | cut -d'/' -f1); \
		GOARCH=$$(echo $$platform | cut -d'/' -f2); \
		output_name=$(BINARY_NAME); \
		if [ $$GOOS = "windows" ]; then output_name=$(BINARY_NAME).exe; fi; \
		output_path=$(DIST_DIR)/$(BINARY_NAME)-$(VERSION)-$$GOOS-$$GOARCH; \
		mkdir -p $$output_path; \
		GOOS=$$GOOS GOARCH=$$GOARCH $(GOBUILD) $(LDFLAGS) -o $$output_path/$$output_name .; \
		if [ $$? -ne 0 ]; then echo "Build failed for $$platform"; exit 1; fi; \
		cd $(DIST_DIR) && tar -czf $(BINARY_NAME)-$(VERSION)-$$GOOS-$$GOARCH.tar.gz $(BINARY_NAME)-$(VERSION)-$$GOOS-$$GOARCH/; \
		cd ../..; \
	done

# Install locally
install: build
	@echo "Installing $(BINARY_NAME)..."
	sudo cp $(BUILD_DIR)/$(BINARY_NAME) /usr/local/bin/

# Uninstall
uninstall:
	@echo "Uninstalling $(BINARY_NAME)..."
	sudo rm -f /usr/local/bin/$(BINARY_NAME)

# Generate completion scripts
completion:
	@echo "Generating completion scripts..."
	@mkdir -p $(BUILD_DIR)/completion
	$(BUILD_DIR)/$(BINARY_NAME) completion bash > $(BUILD_DIR)/completion/$(BINARY_NAME)_bash_completion
	$(BUILD_DIR)/$(BINARY_NAME) completion zsh > $(BUILD_DIR)/completion/$(BINARY_NAME)_zsh_completion

# Package for Debian/Ubuntu
package-deb: build-all
	@echo "Creating Debian package..."
	@./scripts/package-deb.sh

# Package for RedHat/CentOS
package-rpm: build-all
	@echo "Creating RPM package..."
	@./scripts/package-rpm.sh

# Generate Homebrew formula
homebrew-formula:
	@echo "Generating Homebrew formula..."
	@./scripts/generate-homebrew-formula.sh

# Release
release: clean test build-all package-deb package-rpm homebrew-formula
	@echo "Release artifacts created in $(DIST_DIR)"

# Development setup
dev-setup:
	@echo "Setting up development environment..."
	$(GOGET) -u github.com/golangci/golangci-lint/cmd/golangci-lint
	$(GOGET) -u github.com/goreleaser/goreleaser

# Run in development mode
dev-run: build
	@echo "Running $(BINARY_NAME) in development mode..."
	$(BUILD_DIR)/$(BINARY_NAME) $(ARGS)

# Show help
help:
	@echo "Available targets:"
	@echo "  build         - Build for current platform"
	@echo "  build-all     - Cross-compile for all platforms"
	@echo "  clean         - Clean build artifacts"
	@echo "  test          - Run tests"
	@echo "  test-coverage - Run tests with coverage"
	@echo "  deps          - Download dependencies"
	@echo "  fmt           - Format code"
	@echo "  lint          - Lint code"
	@echo "  vet           - Vet code"
	@echo "  install       - Install locally"
	@echo "  uninstall     - Uninstall"
	@echo "  completion    - Generate completion scripts"
	@echo "  package-deb   - Create Debian package"
	@echo "  package-rpm   - Create RPM package"
	@echo "  homebrew-formula - Generate Homebrew formula"
	@echo "  release       - Create release artifacts"
	@echo "  dev-setup     - Setup development environment"
	@echo "  dev-run       - Run in development mode"
	@echo "  help          - Show this help"
