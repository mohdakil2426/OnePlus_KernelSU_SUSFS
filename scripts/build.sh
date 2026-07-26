#!/usr/bin/env bash
# OnePlus 8 series (SM8250) kernel build orchestrator.
# Kernel source: HELLBOY017/kernel_oneplus_sm8250 only (this branch).
#
# Required env:
#   KERNEL_BRANCH   git branch of KERNEL_SOURCE (default tree uses 14)
#   BUILD_MODE      STOCK | KSUN | KSUN_SUSFS
# Optional:
#   KERNEL_SOURCE   git URL (default HELLBOY017)
#   DEFCONFIG       default vendor/oplus-stock_defconfig
#   DEVICE_PROFILE  ALL_OP8_SERIES | OP8 | OP8Pro | OP8T | OP9R
#   SOURCE_PRESET   label for artifacts (HELLBOY017)
#   RUN_OPLUS_STUBS true|false (default true)
#   DISABLE_PROPRIETARY_OPLUS_CONFIGS true|false (default false)
#   CLEAN_BUILD    true = no ccache; false = CC=ccache clang
#   KSUN_REF / SUSFS_REF / JOBS / ARTIFACT_DIR / WORK_DIR

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"

KERNEL_SOURCE="${KERNEL_SOURCE:-https://github.com/HELLBOY017/kernel_oneplus_sm8250.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:?KERNEL_BRANCH is required}"
BUILD_MODE="${BUILD_MODE:?BUILD_MODE is required}"
DEFCONFIG="${DEFCONFIG:-vendor/oplus-stock_defconfig}"
DEVICE_PROFILE="${DEVICE_PROFILE:-ALL_OP8_SERIES}"
SOURCE_PRESET="${SOURCE_PRESET:-HELLBOY017}"
RUN_OPLUS_STUBS="${RUN_OPLUS_STUBS:-true}"
DISABLE_PROPRIETARY_OPLUS_CONFIGS="${DISABLE_PROPRIETARY_OPLUS_CONFIGS:-false}"
CLEAN_BUILD="${CLEAN_BUILD:-false}"
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

if [[ "$RUN_OPLUS_STUBS" == "true" ]]; then
  log "Fix incomplete OSS vendor symlinks / missing Kconfigs"
  ( cd "$KERNEL_DIR" && bash "$SCRIPT_DIR/fix-oplus-stubs.sh" )
  endgroup
else
  log "Skipping oplus stubs (RUN_OPLUS_STUBS=$RUN_OPLUS_STUBS)"
  endgroup
fi

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

# Prefer clang if present; wrap with ccache unless CLEAN_BUILD (author pattern)
export ARCH=arm64
export SUBARCH=arm64
MAKE_ARGS=(O=out ARCH=arm64)

if command -v clang >/dev/null 2>&1; then
  if [[ "$CLEAN_BUILD" == "true" ]]; then
    CC_CMD=clang
    echo "🧹 Clean build mode (no ccache)"
  elif command -v ccache >/dev/null 2>&1; then
    CC_CMD="ccache clang"
    echo "🚀 ccache-accelerated build"
    ccache -s 2>/dev/null | head -n 15 || true
  else
    CC_CMD=clang
    echo "ccache not found; building without cache"
  fi
  MAKE_ARGS+=(
    CC="$CC_CMD"
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

# Seed the defconfig before invoking Kconfig. HELLBOY 13.1 / 13.1-new prompt for
# LITTLE_CPU_MASK / BIG_CPU_MASK (int, no default); vendor/oplus-stock_defconfig
# omits them, so invoking `make <defconfig>` first hangs non-interactive CI.
DEFCONFIG_PATH="arch/arm64/configs/$DEFCONFIG"
[[ -f "$DEFCONFIG_PATH" ]] || die "defconfig not found: $DEFCONFIG_PATH"
mkdir -p out
cp "$DEFCONFIG_PATH" out/.config

# Values match same-tree vendor/kona-perf_defconfig (SM8250). Branch 14 has no
# such symbols, so it keeps the normal olddefconfig path unchanged.
if [[ -f arch/arm64/Kconfig ]] \
  && grep -q '^config LITTLE_CPU_MASK' arch/arm64/Kconfig 2>/dev/null; then
  log "Pre-seed LITTLE/BIG_CPU_MASK for noninteractive conf (13.1-class trees)"
  ./scripts/config --file out/.config --set-val LITTLE_CPU_MASK 15
  ./scripts/config --file out/.config --set-val BIG_CPU_MASK 112
  grep -E 'CONFIG_(LITTLE|BIG)_CPU_MASK' out/.config || true
  endgroup
fi

make "${MAKE_ARGS[@]}" olddefconfig

if [[ "$DISABLE_PROPRIETARY_OPLUS_CONFIGS" == "true" ]]; then
  log "Disable proprietary OPLUS configs (incomplete OSS trees)"
  if [[ -f out/.config ]]; then
    for opt in \
      LOCKING_PROTECT \
      OPLUS_LOCKING_STRATEGY \
      OPLUS_LOCKING_OSQ \
      OPLUS_LOCKING_MONITOR \
      OPLUS_SCHED \
      OPLUS_CTP \
      TOUCHPANEL_OPLUS \
      OPLUS_TP_APK \
      OPLUS_FW_UPDATE \
      OPLUS_SM8250_CHARGER \
      OPLUS_CHIP_SOC_NODE \
      OPLUS_FEATURE_UID_PERF
    do
      ./scripts/config --file out/.config -d "$opt" 2>/dev/null || true
    done
    while IFS= read -r line; do
      opt="${line#CONFIG_}"
      opt="${opt%%=*}"
      [[ -z "$opt" ]] && continue
      ./scripts/config --file out/.config -d "$opt" 2>/dev/null || true
    done < <(grep -E '^CONFIG_OPLUS[A-Z0-9_]*=' out/.config || true)
  fi
  endgroup
else
  log "Keeping OPLUS configs (community tree)"
  endgroup
fi

# Community OP8 trees often enable BOTH generic Synaptics (dsx/tcm) and Oplus
# touch panel stacks → link errors (response_complete, active_panel). Keep Oplus.
log "Disable generic Synaptics touch (keep Oplus touchscreen stack)"
if [[ -f out/.config ]]; then
  while IFS= read -r line; do
    opt="${line#CONFIG_}"
    opt="${opt%%=*}"
    [[ -z "$opt" ]] && continue
    ./scripts/config --file out/.config -d "$opt" 2>/dev/null || true
  done < <(grep -E '^CONFIG_TOUCHSCREEN_SYNAPTICS' out/.config || true)
  # Common names even if not yet expanded in .config
  for opt in \
    TOUCHSCREEN_SYNAPTICS_TCM \
    TOUCHSCREEN_SYNAPTICS_TCM_CORE \
    TOUCHSCREEN_SYNAPTICS_TCM_SPI \
    TOUCHSCREEN_SYNAPTICS_TCM_I2C \
    TOUCHSCREEN_SYNAPTICS_DSX \
    TOUCHSCREEN_SYNAPTICS_DSX_CORE \
    TOUCHSCREEN_SYNAPTICS_DSX_I2C \
    TOUCHSCREEN_SYNAPTICS_DSX_SPI \
    TOUCHSCREEN_SYNAPTICS_DSX_RMI_HID_I2C \
    TOUCHSCREEN_SYNAPTICS_I2C_RMI4
  do
    ./scripts/config --file out/.config -d "$opt" 2>/dev/null || true
  done
  grep -E 'SYNAPTICS|TOUCHPANEL' out/.config | head -40 || true
fi
endgroup

# Re-open configure group for remaining config tweaks
log "Apply optional KSU/SUSFS config symbols"
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
# Confirm critical symbols off/on
grep -E 'CONFIG_LOCKING_PROTECT|CONFIG_KSU|CONFIG_OPLUS' out/.config | head -40 || true
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
if [[ "$CLEAN_BUILD" != "true" ]] && command -v ccache >/dev/null 2>&1; then
  echo "📊 ccache post-compile:"
  ccache -s 2>/dev/null | head -n 25 || true
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
PRESET_SAFE="${SOURCE_PRESET//\//_}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
ZIP_NAME="OP8Series_${PRESET_SAFE}_${BUILD_MODE}_${BRANCH_SAFE}_${FULL_KVER}_${STAMP}.zip"

log "Package AnyKernel3"
export KERNEL_DIR OUT_DIR="$KERNEL_DIR/out" ZIP_NAME DEVICE_PROFILE ARTIFACT_DIR
bash "$SCRIPT_DIR/package-anykernel.sh"
endgroup

{
  echo "source_preset=$SOURCE_PRESET"
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
