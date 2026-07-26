#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/upstream/tools" "$TMP/kernel/out/arch/arm64/boot" "$TMP/artifacts"
printf '# fixture\n' > "$TMP/upstream/anykernel.sh"
printf '# fixture core\n' > "$TMP/upstream/tools/ak3-core.sh"
git -C "$TMP/upstream" init -q
git -C "$TMP/upstream" -c user.name=Test -c user.email=test@example.invalid \
  add anykernel.sh tools/ak3-core.sh
git -C "$TMP/upstream" -c user.name=Test -c user.email=test@example.invalid \
  commit -qm fixture
FIXTURE_SHA="$(git -C "$TMP/upstream" rev-parse HEAD)"

printf 'kernel-image-fixture\n' > "$TMP/kernel/out/arch/arm64/boot/Image"

KERNEL_DIR="$TMP/kernel" \
OUT_DIR="$TMP/kernel/out" \
ARTIFACT_DIR="$TMP/artifacts" \
ZIP_NAME=op8-test.zip \
DEVICE_PROFILE=OP8 \
ANYKERNEL_REPO="$TMP/upstream" \
ANYKERNEL_REF="$FIXTURE_SHA" \
  bash "$ROOT/scripts/package-anykernel.sh"

bash "$ROOT/scripts/verify-anykernel.sh" "$TMP/artifacts/op8-test.zip"
cmp "$TMP/kernel/out/arch/arm64/boot/Image" "$TMP/artifacts/Image"

if DEVICE_PROFILE=OP8Pro \
  KERNEL_DIR="$TMP/kernel" \
  OUT_DIR="$TMP/kernel/out" \
  ARTIFACT_DIR="$TMP/artifacts" \
  ANYKERNEL_REPO="$TMP/upstream" \
  ANYKERNEL_REF="$FIXTURE_SHA" \
  bash "$ROOT/scripts/package-anykernel.sh" >/dev/null 2>&1; then
  echo "error: non-OP8 package unexpectedly succeeded" >&2
  exit 1
fi

echo "AnyKernel packaging behavior passed"
