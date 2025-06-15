#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests"
SCHEMAS_DIR="$TESTS_DIR/test-data/schemas"
INTEGRATION_DIR="$TESTS_DIR/integration"
DOCKER_COMPOSE_FILE="$TESTS_DIR/docker-compose.yml"

# 1. Build ksr-cli
cd "$ROOT_DIR"
echo "[INFO] Building ksr-cli..."
make build

# 2. Start docker-compose environment
cd "$TESTS_DIR"
echo "[INFO] Starting test environment..."
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d --remove-orphans

# 3. Wait for services to be healthy (simple wait loop, 30s timeout)
echo "[INFO] Waiting for services to be healthy..."
ATTEMPTS=30
until docker-compose -f "$DOCKER_COMPOSE_FILE" ps | grep -q "healthy" || [ $ATTEMPTS -eq 0 ]; do
  sleep 1
  ATTEMPTS=$((ATTEMPTS-1))
done
if [ $ATTEMPTS -eq 0 ]; then
  echo "[ERROR] Services did not become healthy in time." >&2
  docker-compose -f "$DOCKER_COMPOSE_FILE" logs
  docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans
  exit 1
fi

# Configure ksr-cli in the test directory
cd "$TESTS_DIR"
"$ROOT_DIR/build/ksr-cli" config init
"$ROOT_DIR/build/ksr-cli" config set registry-url http://localhost:38081

# 4. Load schemas
cd "$ROOT_DIR"
echo "[INFO] Registering schemas..."
for schema in "$SCHEMAS_DIR"/*; do
  subject="$(basename "$schema" .avsc)-value"
  echo "[INFO] Registering $schema as subject $subject..."
  cd "$TESTS_DIR"
  "$ROOT_DIR/build/ksr-cli" create schema "$subject" --file "$schema"
  cd "$ROOT_DIR"
done

# 5. Run integration tests
cd "$INTEGRATION_DIR"
echo "[INFO] Running integration tests..."
for test_script in *.sh; do
  echo "[INFO] Running $test_script..."
  bash "$test_script"
done

# 6. Tear down environment
echo "[INFO] Tearing down test environment..."
docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans

echo "[INFO] Integration tests completed successfully." 