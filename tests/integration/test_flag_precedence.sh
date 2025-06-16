#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLI="../../build/ksr-cli"

echo -e "${BLUE}=== Testing Configuration Precedence ===${NC}"

# Test 1: Environment variables override config file
echo -e "${YELLOW}[TEST] Environment variables override config file...${NC}"
# Save original config
ORIGINAL_CONFIG=""
if [ -f ~/.ksr-cli.yaml ]; then
    ORIGINAL_CONFIG=$(cat ~/.ksr-cli.yaml)
fi

# Create config with wrong URL
echo "registry-url: http://invalid-registry:9999" > ~/.ksr-cli.yaml
echo "username: config-user" >> ~/.ksr-cli.yaml
echo "password: config-pass" >> ~/.ksr-cli.yaml

# Set environment variables with correct values
export KSR_REGISTRY_URL="http://localhost:38081"
export KSR_USERNAME="env-user"
export KSR_PASSWORD="env-pass"

if $CLI get subjects | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Environment variables override config file${NC}"
else
    echo -e "${RED}✗ FAILED: Environment variables precedence failed${NC}"
    exit 1
fi

# Clean up environment variables
unset KSR_REGISTRY_URL KSR_USERNAME KSR_PASSWORD

# Test 2: Flags override environment variables
echo -e "${YELLOW}[TEST] Flags override environment variables...${NC}"
# Set environment variables with wrong values
export KSR_REGISTRY_URL="http://invalid-registry:9999"
export KSR_USERNAME="env-wrong-user"
export KSR_PASSWORD="env-wrong-pass"

if $CLI get subjects --registry-url http://localhost:38081 --user flag-user --pass flag-pass | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Flags override environment variables${NC}"
else
    echo -e "${RED}✗ FAILED: Flags precedence failed${NC}"
    exit 1
fi

# Clean up environment variables
unset KSR_REGISTRY_URL KSR_USERNAME KSR_PASSWORD

# Test 3: Flags override config file
echo -e "${YELLOW}[TEST] Flags override config file...${NC}"
# Config file still has wrong values from Test 1
if $CLI get subjects --registry-url http://localhost:38081 --user flag-user --pass flag-pass | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Flags override config file${NC}"
else
    echo -e "${RED}✗ FAILED: Flags over config precedence failed${NC}"
    exit 1
fi

# Test 4: Full precedence chain (flags > env > config)
echo -e "${YELLOW}[TEST] Full precedence chain (flags > env > config)...${NC}"
# Config has wrong values (already set)
# Set env with different wrong values  
export KSR_REGISTRY_URL="http://env-wrong-registry:9999"
export KSR_USERNAME="env-wrong-user"
export KSR_PASSWORD="env-wrong-pass"

# Use flags with correct values
if $CLI get subjects --registry-url http://localhost:38081 --user correct-user --pass correct-pass | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Full precedence chain works correctly${NC}"
else
    echo -e "${RED}✗ FAILED: Full precedence chain failed${NC}"
    exit 1
fi

# Clean up environment variables
unset KSR_REGISTRY_URL KSR_USERNAME KSR_PASSWORD

# Test 5: Partial flag override (only registry-url flag)
echo -e "${YELLOW}[TEST] Partial flag override (only registry-url)...${NC}"
# Set environment variables for authentication
export KSR_USERNAME="env-auth-user"
export KSR_PASSWORD="env-auth-pass"

# Only override registry-url with flag
if $CLI get subjects --registry-url http://localhost:38081 | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Partial flag override works${NC}"
else
    echo -e "${RED}✗ FAILED: Partial flag override failed${NC}"
    exit 1
fi

# Clean up environment variables
unset KSR_USERNAME KSR_PASSWORD

# Test 6: API key precedence over username/password
echo -e "${YELLOW}[TEST] API key precedence...${NC}"
# Set both API key and username/password in different sources
echo "registry-url: http://localhost:38081" > ~/.ksr-cli.yaml
echo "username: config-user" >> ~/.ksr-cli.yaml
echo "password: config-pass" >> ~/.ksr-cli.yaml
echo "api-key: config-api-key" >> ~/.ksr-cli.yaml

# Override with flags (API key should take precedence)
if $CLI get subjects --user flag-user --pass flag-pass --api-key flag-api-key | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: API key precedence works${NC}"
else
    echo -e "${RED}✗ FAILED: API key precedence failed${NC}"
    exit 1
fi

# Test 7: Environment variable API key precedence
echo -e "${YELLOW}[TEST] Environment API key precedence...${NC}"
export KSR_API_KEY="env-api-key"
export KSR_USERNAME="env-user"
export KSR_PASSWORD="env-pass"

# API key from env should take precedence over username/password from env
if $CLI get subjects | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Environment API key precedence works${NC}"
else
    echo -e "${RED}✗ FAILED: Environment API key precedence failed${NC}"
    exit 1
fi

# Clean up environment variables
unset KSR_API_KEY KSR_USERNAME KSR_PASSWORD

# Test 8: Mixed source authentication precedence
echo -e "${YELLOW}[TEST] Mixed source authentication precedence...${NC}"
# Config has username/password
echo "registry-url: http://localhost:38081" > ~/.ksr-cli.yaml
echo "username: config-user" >> ~/.ksr-cli.yaml
echo "password: config-pass" >> ~/.ksr-cli.yaml

# Env has API key
export KSR_API_KEY="env-api-key"

# Flag API key should override env API key
if $CLI get subjects --api-key flag-api-key | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Mixed source authentication precedence works${NC}"
else
    echo -e "${RED}✗ FAILED: Mixed source authentication precedence failed${NC}"
    exit 1
fi

# Clean up environment variables
unset KSR_API_KEY

# Test 9: Test effective values can be queried
echo -e "${YELLOW}[TEST] Effective configuration values...${NC}"
# Set up known configuration
echo "registry-url: http://localhost:38081" > ~/.ksr-cli.yaml
echo "username: config-user" >> ~/.ksr-cli.yaml
echo "output: json" >> ~/.ksr-cli.yaml

# Override some values with flags
CONFIG_OUTPUT=$($CLI config list --user flag-user)
if echo "$CONFIG_OUTPUT" | grep -q "localhost:38081"; then
    echo -e "${GREEN}✓ PASSED: Effective configuration shows correct values${NC}"
else
    echo -e "${RED}✗ FAILED: Effective configuration values incorrect${NC}"
    echo "Config output: $CONFIG_OUTPUT"
    exit 1
fi

# Test 10: Test empty/missing values handling
echo -e "${YELLOW}[TEST] Empty/missing values handling...${NC}"
# Clear everything
rm -f ~/.ksr-cli.yaml

# Should fail with appropriate error
ERROR_OUTPUT=$(env -u KSR_REGISTRY_URL -u KSR_USERNAME -u KSR_PASSWORD -u KSR_API_KEY $CLI get subjects 2>&1 || true)
if echo "$ERROR_OUTPUT" | grep -q "registry URL is required.*--registry-url"; then
    echo -e "${GREEN}✓ PASSED: Proper error for missing registry URL${NC}"
else
    echo -e "${RED}✗ FAILED: Should show proper error for missing configuration${NC}"
    exit 1
fi

# Restore original config
if [ -n "$ORIGINAL_CONFIG" ]; then
    echo "$ORIGINAL_CONFIG" > ~/.ksr-cli.yaml
else
    rm -f ~/.ksr-cli.yaml
fi

echo -e "${GREEN}All configuration precedence tests passed!${NC}" 