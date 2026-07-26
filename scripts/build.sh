#!/usr/bin/env bash
# OnePlus 8 series (SM8250) kernel build orchestrator.
# Kernel source selected by the workflow source preset.
#
# Required env:
#   KERNEL_BRANCH   git branch of KERNEL_SOURCE (default tree uses 14)
#   BUILD_MODE      STOCK | KSUN | KSUN_SUSFS
# Optional:
#   KERNEL_SOURCE   git URL (default HELLBOY017)
#   COMPANION_SOURCE / COMPANION_BRANCH for split official source releases
#   TOOLCHAIN_PROFILE selected source toolchain (default zyc-clang-14)
#   SOURCE_PATCH_SET audited compatibility repairs (default none)
#   DEFCONFIG       default vendor/oplus-stock_defconfig
#   DEVICE_PROFILE  ALL_OP8_SERIES | OP8 | OP8Pro | OP8T | OP9R
#   SOURCE_PRESET   label for artifacts
#   CLEAN_BUILD    true = no ccache; false = CC=ccache clang
#   KSUN_REF / SUSFS_REF / JOBS / ARTIFACT_DIR / WORK_DIR

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"

KERNEL_SOURCE="${KERNEL_SOURCE:-https://github.com/HELLBOY017/kernel_oneplus_sm8250.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:?KERNEL_BRANCH is required}"
COMPANION_SOURCE="${COMPANION_SOURCE:-}"
COMPANION_BRANCH="${COMPANION_BRANCH:-}"
TOOLCHAIN_PROFILE="${TOOLCHAIN_PROFILE:-zyc-clang-14}"
SOURCE_PATCH_SET="${SOURCE_PATCH_SET:-none}"
BUILD_MODE="${BUILD_MODE:?BUILD_MODE is required}"
DEFCONFIG="${DEFCONFIG:-vendor/oplus-stock_defconfig}"
DEVICE_PROFILE="${DEVICE_PROFILE:-ALL_OP8_SERIES}"
SOURCE_PRESET="${SOURCE_PRESET:-HELLBOY017}"
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

if [[ -n "$COMPANION_SOURCE" || -n "$COMPANION_BRANCH" ]]; then
  [[ -n "$COMPANION_SOURCE" && -n "$COMPANION_BRANCH" ]] ||
    die "COMPANION_SOURCE and COMPANION_BRANCH must be set together"

  # Official OnePlus releases are split across two repositories. Their kernel
  # symlinks assume the source is located at kernel/msm-4.19 and resolve vendor
  # components from the shared workspace root.
  OFFICIAL_LAYOUT="$WORK_DIR/official"
  COMPANION_DIR="$WORK_DIR/official-companion"
  KERNEL_DIR="$OFFICIAL_LAYOUT/kernel/msm-4.19"

  log "Assemble official source workspace"
  rm -rf "$OFFICIAL_LAYOUT" "$COMPANION_DIR"
  mkdir -p "$(dirname "$KERNEL_DIR")"
  git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_SOURCE" "$KERNEL_DIR"
  git clone --depth=1 -b "$COMPANION_BRANCH" "$COMPANION_SOURCE" "$COMPANION_DIR"

  case "$SOURCE_PATCH_SET" in
    none)
      ;;
    oneplusoss-sm8250-strict-prototypes)
      PATCH_FILE="$ROOT_DIR/patches/oneplusoss-sm8250-strict-prototypes.patch"
      [[ -f "$PATCH_FILE" ]] || die "source patch not found: $PATCH_FILE"
      # OnePlus publishes the display source with mixed CRLF/LF endings.
      git -C "$COMPANION_DIR" apply --check --ignore-space-change "$PATCH_FILE"
      git -C "$COMPANION_DIR" apply --ignore-space-change "$PATCH_FILE"
      echo "Applied source patch set: $SOURCE_PATCH_SET"
      ;;
    *)
      die "unknown SOURCE_PATCH_SET=$SOURCE_PATCH_SET"
      ;;
  esac

  rsync -a "$COMPANION_DIR/vendor/" "$OFFICIAL_LAYOUT/vendor/"
  rsync -a "$COMPANION_DIR/kernel/msm-4.19/" "$KERNEL_DIR/"
  rm -rf "$COMPANION_DIR"

  BROKEN_LINKS=$(find "$KERNEL_DIR" -xtype l -print)
  if [[ -n "$BROKEN_LINKS" ]]; then
    printf '%s\n' "$BROKEN_LINKS" >&2
    die "official source workspace contains broken symlinks"
  fi
  endgroup
else
  log "Clone kernel $KERNEL_SOURCE @ $KERNEL_BRANCH"
  rm -rf "$KERNEL_DIR"
  git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_SOURCE" "$KERNEL_DIR"
  endgroup
fi

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

log "Configure upstream $DEFCONFIG"
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
  if [[ "$TOOLCHAIN_PROFILE" == "android-clang-r399163b" ]]; then
    # Match the OnePlus build.config files: LLVM=1 with GNU cross assembler
    # prefixes. Leaving LLVM_IAS unset makes this 4.19 tree use external gas.
    MAKE_ARGS+=(
      LLVM=1
      CC="$CC_CMD"
      CROSS_COMPILE=aarch64-linux-gnu-
      CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
      CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    )
  else
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
  fi
else
  MAKE_ARGS+=(CROSS_COMPILE=aarch64-linux-gnu-)
fi

DEFCONFIG_PATH="arch/arm64/configs/$DEFCONFIG"
[[ -f "$DEFCONFIG_PATH" ]] || die "defconfig not found: $DEFCONFIG_PATH"
make "${MAKE_ARGS[@]}" "$DEFCONFIG"

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

if [[ "$ENABLE_KSUN" == "true" || "$ENABLE_SUSFS" == "true" ]]; then
  make "${MAKE_ARGS[@]}" olddefconfig
fi
grep -E 'CONFIG_KSU|CONFIG_KSU_SUSFS' out/.config | head -40 || true
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
  echo "companion_source=$COMPANION_SOURCE"
  echo "companion_branch=$COMPANION_BRANCH"
  echo "toolchain_profile=$TOOLCHAIN_PROFILE"
  echo "source_patch_set=$SOURCE_PATCH_SET"
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
