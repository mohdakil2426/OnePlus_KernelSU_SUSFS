#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for script in scripts/*.sh tests/*.sh; do
  bash -n "$script"
done

for test_script in tests/test-*.sh; do
  case "$test_script" in
    tests/test-op8-build-tree.sh)
      # Requires an assembled OnePlus source tree and pinned toolchains.
      continue
      ;;
  esac
  echo "RUN $test_script"
  bash "$test_script"
done

echo "Static test suite passed"
