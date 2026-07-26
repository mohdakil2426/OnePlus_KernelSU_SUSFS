#!/usr/bin/env bash
# Validate an already assembled and integrated official OP8 build tree.

set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:?set KERNEL_DIR to the integrated OP8 kernel tree}"
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:?set TOOLCHAIN_DIR to Android clang r399163b}"
GAS_DIR="${GAS_DIR:?set GAS_DIR to the matching Android GNU tools}"
COMPILE="${COMPILE:-false}"
CONFIGURE="${CONFIGURE:-true}"
JOBS="${JOBS:-$(nproc)}"

cd "$KERNEL_DIR"

BROKEN_LINKS="$(find . -xtype l -print)"
[[ -z "$BROKEN_LINKS" ]] || {
  printf '%s\n' "$BROKEN_LINKS" >&2
  echo "error: build tree contains broken symlinks" >&2
  exit 1
}

FEATURE_COUNT=0
while IFS='=' read -r key value; do
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
  [[ -n "$value" ]] || continue
  export "$key=$value"
  FEATURE_COUNT=$((FEATURE_COUNT + 1))
done < oplus_native_features.mk
(( FEATURE_COUNT > 0 ))

export PATH="$TOOLCHAIN_DIR/bin:$GAS_DIR:$PATH"
export ARCH=arm64
export SUBARCH=arm64

clang --version | grep -Fq 'clang version 11.0.5'
aarch64-linux-gnu-as --version | grep -Fq '2.27.0.20170315'

MAKE_ARGS=(
  O=out
  ARCH=arm64
  LLVM=1
  CC=clang
  CROSS_COMPILE=aarch64-linux-gnu-
  CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
  CROSS_COMPILE_ARM32=arm-linux-gnueabi-
)

if [[ "$CONFIGURE" == "true" ]]; then
  rm -rf out
  make "${MAKE_ARGS[@]}" vendor/kona-perf_defconfig
  ./scripts/config --file out/.config \
  -e KSU \
  -e KSU_MANUAL_HOOK \
  -d KSU_KPROBES_HOOK \
  -e KALLSYMS \
  -e KALLSYMS_ALL \
  -e KSU_SUSFS \
  -e KSU_SUSFS_HAS_MAGIC_MOUNT \
  -e KSU_SUSFS_SUS_PATH \
  -e KSU_SUSFS_SUS_MOUNT \
  -e KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT \
  -e KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT \
  -e KSU_SUSFS_SUS_KSTAT \
  -e KSU_SUSFS_SUS_OVERLAYFS \
  -e KSU_SUSFS_TRY_UMOUNT \
  -e KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT \
  -e KSU_SUSFS_SPOOF_UNAME \
  -e KSU_SUSFS_ENABLE_LOG \
  -e KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
  -e KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    -e KSU_SUSFS_OPEN_REDIRECT
  make "${MAKE_ARGS[@]}" olddefconfig
else
  [[ -f out/.config ]] ||
    { echo "error: CONFIGURE=false requires out/.config" >&2; exit 1; }
fi

for expected in \
  CONFIG_KSU=y \
  CONFIG_KSU_MANUAL_HOOK=y \
  CONFIG_KSU_SUSFS=y \
  CONFIG_KSU_SUSFS_SUS_PATH=y \
  CONFIG_KSU_SUSFS_SUS_MOUNT=y \
  CONFIG_KSU_SUSFS_SUS_KSTAT=y \
  CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y \
  CONFIG_KSU_SUSFS_TRY_UMOUNT=y \
  CONFIG_KSU_SUSFS_SPOOF_UNAME=y \
  CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y \
  CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
do
  grep -Fxq "$expected" out/.config ||
    { echo "error: missing $expected" >&2; exit 1; }
done
if grep -Fxq 'CONFIG_KSU_KPROBES_HOOK=y' out/.config; then
  echo "error: KernelSU kprobe hook mode must stay disabled" >&2
  exit 1
fi

if [[ "$COMPILE" == "true" ]]; then
  make -j"$JOBS" "${MAKE_ARGS[@]}" Image
  [[ -s out/arch/arm64/boot/Image ]]
  sha256sum out/arch/arm64/boot/Image
fi

echo "exact OP8 build-tree validation passed (compile=$COMPILE)"
