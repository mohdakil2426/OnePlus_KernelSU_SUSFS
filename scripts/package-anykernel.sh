#!/usr/bin/env bash
# Package Image into AnyKernel3 zip for OP8 series.
# Env:
#   KERNEL_DIR, OUT_DIR, ZIP_NAME, DEVICE_PROFILE
#   DEVICE_PROFILE: ALL_OP8_SERIES | OP8 | OP8Pro | OP8T | OP9R

set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-.}"
OUT_DIR="${OUT_DIR:-$KERNEL_DIR/out}"
DEVICE_PROFILE="${DEVICE_PROFILE:-ALL_OP8_SERIES}"
ZIP_NAME="${ZIP_NAME:-OP8Series_kernel.zip}"
ARTIFACT_DIR="${ARTIFACT_DIR:-.}"

IMAGE="$OUT_DIR/arch/arm64/boot/Image"
if [[ ! -f "$IMAGE" ]]; then
  echo "error: missing $IMAGE" >&2
  exit 1
fi

rm -rf "$KERNEL_DIR/AnyKernel3"
git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "$KERNEL_DIR/AnyKernel3"
cd "$KERNEL_DIR/AnyKernel3"
rm -rf .git modules patch ramdisk

cp "$IMAGE" .
[[ -f "$OUT_DIR/arch/arm64/boot/dtb" ]] && cp "$OUT_DIR/arch/arm64/boot/dtb" . || true
[[ -f "$OUT_DIR/arch/arm64/boot/dtbo.img" ]] && cp "$OUT_DIR/arch/arm64/boot/dtbo.img" . || true

# Device codenames for OnePlus 8 series
case "$DEVICE_PROFILE" in
  OP8)
    NAMES=(instantnoodle)
    ;;
  OP8Pro)
    NAMES=(instantnoodlep)
    ;;
  OP8T)
    NAMES=(kebab lemonkebab)
    ;;
  OP9R)
    NAMES=(lemonades lemonade)
    ;;
  ALL_OP8_SERIES|*)
    NAMES=(instantnoodle instantnoodlep kebab lemonkebab lemonades lemonade)
    ;;
esac

sed -i 's/do.devicecheck=.*/do.devicecheck=1;/g' anykernel.sh
sed -i 's/do.modules=.*/do.modules=0;/g' anykernel.sh
sed -i 's|block=.*|block=/dev/block/bootdevice/by-name/boot;|g' anykernel.sh
sed -i 's/is_slot_device=.*/is_slot_device=1;/g' anykernel.sh

# Clear default device.nameN then set ours
sed -i '/device\.name[0-9]=/d' anykernel.sh
idx=1
for n in "${NAMES[@]}"; do
  # Insert after do.devicecheck line
  sed -i "/do.devicecheck=/a device.name${idx}=${n};" anykernel.sh
  idx=$((idx + 1))
done

mkdir -p "$ARTIFACT_DIR"
zip -r9 "$ARTIFACT_DIR/$ZIP_NAME" . -x '.git/*' 'README.md' '*placeholder'
cp "$IMAGE" "$ARTIFACT_DIR/Image"

echo "Packaged $ARTIFACT_DIR/$ZIP_NAME"
