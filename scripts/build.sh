#!/usr/bin/env bash
# OnePlus 8 series (SM8250) kernel build orchestrator.
# Only supports OnePlusOSS/android_kernel_oneplus_sm8250
#
# Required env:
#   KERNEL_BRANCH   e.g. oneplus/sm8250_u_14.0.0_op8t
#   BUILD_MODE      STOCK | KSUN | KSUN_SUSFS
# Optional:
#   KERNEL_SOURCE   default OnePlusOSS sm8250 URL
#   DEFCONFIG       default vendor/kona-perf_defconfig
#   DEVICE_PROFILE  ALL_OP8_SERIES | OP8 | OP8Pro | OP8T | OP9R
#   KSUN_REF        default next
#   SUSFS_REF       default kernel-4.19
#   JOBS            default nproc
#   ARTIFACT_DIR    default $PWD/artifacts
#   WORK_DIR        default $PWD/work

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"

KERNEL_SOURCE="${KERNEL_SOURCE:-https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:?KERNEL_BRANCH is required}"
BUILD_MODE="${BUILD_MODE:?BUILD_MODE is required}"
DEFCONFIG="${DEFCONFIG:-vendor/kona-perf_defconfig}"
DEVICE_PROFILE="${DEVICE_PROFILE:-ALL_OP8_SERIES}"
KSUN_REF="${KSUN_REF:-next}"
SUSFS_REF="${SUSFS_REF:-kernel-4.19}"
JOBS="${JOBS:-$(nproc)}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/work}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$ROOT_DIR/artifacts}"

log() { echo "::group::$*"; echo "[build] $*"; }
endgroup() { echo "::endgroup::"; }
die() { echo "error: $*" >&2; exit 1; }

case "$BUILD_MODE" in
  STOCK) ENABLE_KSUN=false; ENABLE_SUSFS=false ;;
  KSUN) ENABLE_KSUN=true; ENABLE_SUSFS=false ;;
  KSUN_SUSFS) ENABLE_KSUN=true; ENABLE_SUSFS=true ;;
  *) die "invalid BUILD_MODE=$BUILD_MODE (use STOCK|KSUN|KSUN_SUSFS)" ;;
esac

mkdir -p "$WORK_DIR" "$ARTIFACT_DIR"
KERNEL_DIR="$WORK_DIR/kernel"

log "Clone kernel $KERNEL_SOURCE @ $KERNEL_BRANCH"
rm -rf "$KERNEL_DIR"
git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_SOURCE" "$KERNEL_DIR"
endgroup

# OnePlusOSS dumps: broken vendor/oplus symlinks (sched_assist, etc.)
log "Fix incomplete OSS vendor symlinks / missing Kconfigs"
( cd "$KERNEL_DIR" && bash "$SCRIPT_DIR/fix-oplus-stubs.sh" )
endgroup

# vDSO clang fix (common on 4.19 + modern clang)
log "vDSO clang compatibility"
for f in \
  "$KERNEL_DIR/arch/arm64/kernel/vdso/Makefile" \
  "$KERNEL_DIR/arch/arm64/kernel/vdso32/Makefile"
do
  if [[ -f "$f" ]] && ! grep -q -- '-g0' "$f"; then
    echo 'ccflags-y += -g0' >> "$f"
  fi
done
endgroup

if [[ "$ENABLE_KSUN" == "true" ]]; then
  log "KernelSU-Next"
  export KSUN_REF KERNEL_DIR
  if [[ "$ENABLE_SUSFS" == "true" ]]; then
    export FORCE_NO_KPROBE=true
  else
    export FORCE_NO_KPROBE=false
  fi
  bash "$SCRIPT_DIR/apply-ksun.sh"
  endgroup

  log "Manual non-GKI hooks"
  ( cd "$KERNEL_DIR" && bash "$SCRIPT_DIR/add-manual-hooks.sh" )
  endgroup
fi

if [[ "$ENABLE_SUSFS" == "true" ]]; then
  log "SUSFS (kernel-4.19)"
  export SUSFS_REF KERNEL_DIR WORK_DIR
  bash "$SCRIPT_DIR/apply-susfs.sh"
  endgroup
fi

log "Configure $DEFCONFIG"
cd "$KERNEL_DIR"

# Prefer clang if present
export ARCH=arm64
export SUBARCH=arm64
MAKE_ARGS=(O=out ARCH=arm64)

if command -v clang >/dev/null 2>&1; then
  MAKE_ARGS+=(
    CC=clang
    CLANG_TRIPLE=aarch64-linux-gnu-
    CROSS_COMPILE=aarch64-linux-android-
    CROSS_COMPILE_ARM32=arm-linux-androideabi-
    LLVM_IAS=1
    LD=ld.lld
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
  )
else
  MAKE_ARGS+=(CROSS_COMPILE=aarch64-linux-gnu-)
fi

make "${MAKE_ARGS[@]}" "$DEFCONFIG"

if [[ "$ENABLE_KSUN" == "true" ]]; then
  ./scripts/config --file out/.config -e KSU || true
  ./scripts/config --file out/.config -e KALLSYMS || true
  ./scripts/config --file out/.config -e KALLSYMS_ALL || true
fi

if [[ "$ENABLE_SUSFS" == "true" ]]; then
  for opt in \
    KSU_SUSFS \
    KSU_SUSFS_SUS_PATH \
    KSU_SUSFS_SUS_MOUNT \
    KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT \
    KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT \
    KSU_SUSFS_SUS_KSTAT \
    KSU_SUSFS_TRY_UMOUNT \
    KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT \
    KSU_SUSFS_SPOOF_UNAME \
    KSU_SUSFS_ENABLE_LOG \
    KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
    KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    KSU_SUSFS_OPEN_REDIRECT \
    KSU_SUSFS_HAS_MAGIC_MOUNT
  do
    ./scripts/config --file out/.config -e "$opt" || true
  done
fi

make "${MAKE_ARGS[@]}" olddefconfig
grep -E 'CONFIG_KSU|CONFIG_KSU_SUSFS' out/.config || true
endgroup

log "Compile Image (jobs=$JOBS)"
# Explicit Image target (skip unavailable vendor modules). Capture exit of make, not tee.
set +e
make -j"$JOBS" "${MAKE_ARGS[@]}" Image 2>&1 | tee "$ARTIFACT_DIR/build.log"
MAKE_RC=${PIPESTATUS[0]}
set -e
if [[ $MAKE_RC -ne 0 ]]; then
  die "make Image failed with exit $MAKE_RC (see artifacts/build.log)"
fi
endgroup

if [[ ! -f out/arch/arm64/boot/Image ]]; then
  die "Build failed: Image not produced"
fi

# Version metadata
VERSION=$(grep '^VERSION *=' Makefile | awk '{print $3}')
PATCHLEVEL=$(grep '^PATCHLEVEL *=' Makefile | awk '{print $3}')
SUBLEVEL=$(grep '^SUBLEVEL *=' Makefile | awk '{print $3}')
FULL_KVER="$VERSION.$PATCHLEVEL.$SUBLEVEL"
BRANCH_SAFE="${KERNEL_BRANCH//\//_}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
ZIP_NAME="OP8Series_${BUILD_MODE}_${BRANCH_SAFE}_${FULL_KVER}_${STAMP}.zip"

log "Package AnyKernel3"
export KERNEL_DIR OUT_DIR="$KERNEL_DIR/out" ZIP_NAME DEVICE_PROFILE ARTIFACT_DIR
bash "$SCRIPT_DIR/package-anykernel.sh"
endgroup

{
  echo "kernel_source=$KERNEL_SOURCE"
  echo "kernel_branch=$KERNEL_BRANCH"
  echo "build_mode=$BUILD_MODE"
  echo "defconfig=$DEFCONFIG"
  echo "device_profile=$DEVICE_PROFILE"
  echo "kernel_version=$FULL_KVER"
  echo "ksun_ref=$KSUN_REF"
  echo "susfs_ref=$SUSFS_REF"
  echo "zip_name=$ZIP_NAME"
} | tee "$ARTIFACT_DIR/build-info.txt"

# Export for GitHub Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "zip_name=$ZIP_NAME"
    echo "kernel_version=$FULL_KVER"
    echo "image_path=$ARTIFACT_DIR/Image"
  } >> "$GITHUB_OUTPUT"
fi

log "Done: $ARTIFACT_DIR/$ZIP_NAME"
endgroup
