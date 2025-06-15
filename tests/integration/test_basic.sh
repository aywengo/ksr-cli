#!/usr/bin/env bash
set -euo pipefail

# Check if at least one schema is registered
SCHEMA_COUNT=$(../../build/ksr-cli get subjects | wc -l)
if [ "$SCHEMA_COUNT" -eq 0 ]; then
  echo "[FAIL] No schemas registered!"
  exit 1
else
  echo "[PASS] $SCHEMA_COUNT schemas registered."
fi

# Test context configuration
echo "[INFO] Testing context configuration..."
../../build/ksr-cli config set context test-context
CONFIGURED_CONTEXT=$(../../build/ksr-cli config get context | awk -F' = ' '{print $2}')
if [ "$CONFIGURED_CONTEXT" = "test-context" ]; then
  echo "[PASS] Context configuration works."
else
  echo "[FAIL] Context configuration failed. Expected 'test-context', got '$CONFIGURED_CONTEXT'"
  exit 1
fi

# Reset context to default
../../build/ksr-cli config set context .
echo "[PASS] All tests completed successfully." 