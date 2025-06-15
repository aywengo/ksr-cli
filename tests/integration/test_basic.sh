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