#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="${KERNEL_DIR:-.}"
OUT_DIR="${OUT_DIR:-$KERNEL_DIR/out}"
ZIP_NAME="${ZIP_NAME:-OP8_kernel.zip}"
ARTIFACT_DIR="${ARTIFACT_DIR:-.}"
DEVICE_PROFILE="${DEVICE_PROFILE:-OP8}"
ANYKERNEL_REPO="${ANYKERNEL_REPO:-https://github.com/WildKernels/AnyKernel3.git}"
ANYKERNEL_REF="${ANYKERNEL_REF:-e1e9dce98430c5c6f231f7094a8c7f4ecaf50948}"

die() { echo "error: $*" >&2; exit 1; }

[[ "$DEVICE_PROFILE" == "OP8" ]] ||
  die "this verified installer is intentionally restricted to DEVICE_PROFILE=OP8"
[[ "$ANYKERNEL_REF" =~ ^[0-9a-f]{40}$ ]] ||
  die "ANYKERNEL_REF must be a full immutable commit SHA"

IMAGE="$OUT_DIR/arch/arm64/boot/Image"
[[ -s "$IMAGE" ]] || die "missing or empty $IMAGE"

PACKAGE_DIR="$KERNEL_DIR/AnyKernel3"
rm -rf "$PACKAGE_DIR"
git clone --filter=blob:none --no-checkout "$ANYKERNEL_REPO" "$PACKAGE_DIR"
git -C "$PACKAGE_DIR" checkout --detach "$ANYKERNEL_REF"
RESOLVED="$(git -C "$PACKAGE_DIR" rev-parse HEAD)"
[[ "$RESOLVED" == "$ANYKERNEL_REF" ]] ||
  die "AnyKernel revision mismatch: expected $ANYKERNEL_REF, got $RESOLVED"

rm -rf "$PACKAGE_DIR/.git" "$PACKAGE_DIR/modules" "$PACKAGE_DIR/patch" \
  "$PACKAGE_DIR/ramdisk"
cp "$ROOT_DIR/assets/anykernel-op8.sh" "$PACKAGE_DIR/anykernel.sh"
cp "$IMAGE" "$PACKAGE_DIR/Image"

mkdir -p "$ARTIFACT_DIR"
(
  cd "$PACKAGE_DIR"
  zip -qr9 "$ARTIFACT_DIR/$ZIP_NAME" . \
    -x 'README.md' '*placeholder' '*.git*'
)
cp "$IMAGE" "$ARTIFACT_DIR/Image"

bash "$ROOT_DIR/scripts/verify-anykernel.sh" "$ARTIFACT_DIR/$ZIP_NAME"
printf '%s\n' "$RESOLVED" > "$ARTIFACT_DIR/anykernel-revision.txt"
echo "Packaged and verified $ARTIFACT_DIR/$ZIP_NAME"
