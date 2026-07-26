#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_name() {
  local expected=$1
  shift
  local actual
  actual="$(env "$@" bash "$ROOT/scripts/generate-package-name.sh")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'error: expected %s, got %s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

COMMON=(
  DEVICE_PROFILE=OP8
  SOURCE_PRESET=ONEPLUSOSS_OP8_OOS13_1
  KERNEL_VERSION=4.19.157
  GITHUB_RUN_NUMBER=42
)

assert_name \
  'AK3_op8_oneplusoss-op8-oos13-1_stock_k4.19.157_r42.zip' \
  "${COMMON[@]}" BUILD_MODE=STOCK

assert_name \
  'AK3_op8_oneplusoss-op8-oos13-1_ksun_k4.19.157_r42.zip' \
  "${COMMON[@]}" BUILD_MODE=KSUN

assert_name \
  'AK3_op8_oneplusoss-op8-oos13-1_ksun_susfs-v1.5.5_k4.19.157_r42.zip' \
  "${COMMON[@]}" BUILD_MODE=KSUN_SUSFS SUSFS_VERSION=v1.5.5

assert_name \
  'op8-flash-oneplusoss-op8-oos13-1-ksun-susfs-v1.5.5-r42' \
  "${COMMON[@]}" BUILD_MODE=KSUN_SUSFS SUSFS_VERSION=v1.5.5 OUTPUT_KIND=artifact

echo "Package naming tests passed"
