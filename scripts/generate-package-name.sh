#!/usr/bin/env bash

set -euo pipefail

DEVICE_PROFILE="${DEVICE_PROFILE:?DEVICE_PROFILE is required}"
SOURCE_PRESET="${SOURCE_PRESET:?SOURCE_PRESET is required}"
BUILD_MODE="${BUILD_MODE:?BUILD_MODE is required}"
KERNEL_VERSION="${KERNEL_VERSION:?KERNEL_VERSION is required}"
SUSFS_VERSION="${SUSFS_VERSION:-}"
RUN_NUMBER="${GITHUB_RUN_NUMBER:-local}"
OUTPUT_KIND="${OUTPUT_KIND:-zip}"

sanitize() {
  printf '%s' "$1" |
    tr '[:upper:]_' '[:lower:]-' |
    sed -E 's/[^a-z0-9.-]+/-/g; s/^-+//; s/-+$//'
}

device_token="$(sanitize "$DEVICE_PROFILE")"
source_token="$(sanitize "$SOURCE_PRESET")"
kernel_token="$(sanitize "$KERNEL_VERSION")"
run_token="$(sanitize "$RUN_NUMBER")"

case "$BUILD_MODE" in
  STOCK)
    mode_token=stock
    ;;
  KSUN)
    mode_token=ksun
    ;;
  KSUN_SUSFS)
    [[ -n "$SUSFS_VERSION" ]] ||
      { echo "error: SUSFS_VERSION is required for KSUN_SUSFS naming" >&2; exit 1; }
    mode_token="ksun_susfs-$(sanitize "$SUSFS_VERSION")"
    ;;
  *)
    echo "error: unsupported BUILD_MODE=$BUILD_MODE" >&2
    exit 1
    ;;
esac

case "$OUTPUT_KIND" in
  zip)
    printf 'AK3_%s_%s_%s_k%s_r%s.zip\n' \
      "$device_token" "$source_token" "$mode_token" "$kernel_token" "$run_token"
    ;;
  artifact)
    printf 'op8-flash-%s-%s-r%s\n' \
      "$source_token" "${mode_token//_/-}" "$run_token"
    ;;
  *)
    echo "error: unsupported OUTPUT_KIND=$OUTPUT_KIND" >&2
    exit 1
    ;;
esac
