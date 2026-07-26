#!/usr/bin/env bash

set -euo pipefail

ZIP_PATH="${1:?usage: verify-anykernel.sh ZIP}"
[[ -s "$ZIP_PATH" ]] || { echo "error: ZIP missing or empty: $ZIP_PATH" >&2; exit 1; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

unzip -q "$ZIP_PATH" -d "$TMP_DIR"
[[ -s "$TMP_DIR/Image" ]] || { echo "error: packaged Image missing or empty" >&2; exit 1; }
[[ -f "$TMP_DIR/anykernel.sh" ]] || { echo "error: anykernel.sh missing" >&2; exit 1; }
[[ -f "$TMP_DIR/tools/ak3-core.sh" ]] || { echo "error: AnyKernel core missing" >&2; exit 1; }

INSTALLER="$TMP_DIR/anykernel.sh"
grep -Fxq 'device.name1=instantnoodle' "$INSTALLER" ||
  { echo "error: installer is not scoped to instantnoodle" >&2; exit 1; }
if grep -Eq '^device\.name[2-9]=.+' "$INSTALLER"; then
  echo "error: installer contains additional device targets" >&2
  exit 1
fi
grep -Fxq 'block=boot' "$INSTALLER" ||
  { echo "error: installer does not use AnyKernel boot resolution" >&2; exit 1; }
grep -Fxq 'is_slot_device=auto' "$INSTALLER" ||
  { echo "error: installer does not auto-detect the active slot" >&2; exit 1; }

if grep -Eqi 'tuna|/dev/block/platform/omap|Non-GKI device, abort' "$INSTALLER"; then
  echo "error: installer contains an unsafe sample/GKI-only rule" >&2
  exit 1
fi

echo "AnyKernel ZIP verified: instantnoodle, active boot slot, Image present"
