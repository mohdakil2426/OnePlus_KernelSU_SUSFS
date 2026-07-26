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
NATIVE_FEATURE_PROFILE=none
BUILD_MODE="${BUILD_MODE:?BUILD_MODE is required}"
DEFCONFIG="${DEFCONFIG:-vendor/oplus-stock_defconfig}"
DEVICE_PROFILE="${DEVICE_PROFILE:-ALL_OP8_SERIES}"
SOURCE_PRESET="${SOURCE_PRESET:-HELLBOY017}"
CLEAN_BUILD="${CLEAN_BUILD:-false}"
KSUN_REF="${KSUN_REF:-53791c92bff13d62338f29cc9da035a37652ca91}"
SUSFS_REF="${SUSFS_REF:-001e69919c6271f690fd00b17e4c721c9e599152}"
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
  SOURCE_REVISION="$(git -C "$KERNEL_DIR" rev-parse HEAD)"
  COMPANION_REVISION="$(git -C "$COMPANION_DIR" rev-parse HEAD)"

  case "$SOURCE_PATCH_SET" in
    none)
      ;;
    oneplusoss-sm8250-strict-prototypes)
      KERNEL_PATCH_FILES=(
        "$ROOT_DIR/patches/oneplusoss-sm8250-genksyms.patch"
        "$ROOT_DIR/patches/oneplusoss-sm8250-rtic-bss.patch"
      )
      COMPANION_PATCH_FILE="$ROOT_DIR/patches/oneplusoss-sm8250-strict-prototypes.patch"
      [[ -f "$COMPANION_PATCH_FILE" ]] || die "source patch not found: $COMPANION_PATCH_FILE"
      # OnePlus publishes affected sources with mixed CRLF/LF endings.
      for kernel_patch_file in "${KERNEL_PATCH_FILES[@]}"; do
        [[ -f "$kernel_patch_file" ]] || die "source patch not found: $kernel_patch_file"
        git -C "$KERNEL_DIR" apply --check --unidiff-zero --ignore-space-change "$kernel_patch_file"
        git -C "$KERNEL_DIR" apply --unidiff-zero --ignore-space-change "$kernel_patch_file"
      done
      git -C "$COMPANION_DIR" apply --check --ignore-space-change "$COMPANION_PATCH_FILE"
      git -C "$COMPANION_DIR" apply --ignore-space-change "$COMPANION_PATCH_FILE"
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
  SOURCE_REVISION="$(git -C "$KERNEL_DIR" rev-parse HEAD)"
  COMPANION_REVISION=
  endgroup
fi

if [[ "$ENABLE_KSUN" == "true" ]]; then
  log "KernelSU-Next"
  export KSUN_REF KERNEL_DIR
  bash "$SCRIPT_DIR/apply-ksun.sh"
  endgroup
fi

if [[ "$ENABLE_SUSFS" == "true" ]]; then
  log "SUSFS (kernel-4.19)"
  export SUSFS_REF KERNEL_DIR WORK_DIR
  bash "$SCRIPT_DIR/apply-susfs.sh"
  endgroup
fi

if [[ "$ENABLE_KSUN" == "true" ]]; then
  log "Manual non-GKI hooks"
  export KERNEL_DIR
  bash "$SCRIPT_DIR/add-manual-hooks.sh"
  endgroup
fi

log "Configure upstream $DEFCONFIG"
cd "$KERNEL_DIR"

if [[ -n "$COMPANION_SOURCE" ]]; then
  FEATURE_FILE="$KERNEL_DIR/oplus_native_features.mk"
  [[ -f "$FEATURE_FILE" ]] || die "official source is missing oplus_native_features.mk"

  FEATURE_COUNT=0
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    [[ -n "$value" ]] || continue
    value="${value%$'\r'}"
    export "$key=$value"
    ((FEATURE_COUNT += 1))
  done < "$FEATURE_FILE"

  (( FEATURE_COUNT > 0 )) || die "no native features found in $FEATURE_FILE"
  for required_feature in \
    OPLUS_FEATURE_PADL_STATISTICS \
    OPLUS_FEATURE_PROCESS_RECLAIM \
    OPLUS_FEATURE_UFSPLUS
  do
    [[ -v "$required_feature" && -n "${!required_feature}" ]] ||
      die "required native feature is missing: $required_feature"
  done
  NATIVE_FEATURE_PROFILE=oneplus-published
  echo "Loaded $FEATURE_COUNT published OnePlus native feature values"
fi

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
  ./scripts/config --file out/.config -e KSU
  ./scripts/config --file out/.config -e KSU_MANUAL_HOOK
  ./scripts/config --file out/.config -d KSU_KPROBES_HOOK
  ./scripts/config --file out/.config -e KALLSYMS
  ./scripts/config --file out/.config -e KALLSYMS_ALL
fi

if [[ "$ENABLE_SUSFS" == "true" ]]; then
  for opt in \
    KSU_SUSFS \
    KSU_SUSFS_SUS_PATH \
    KSU_SUSFS_SUS_MOUNT \
    KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT \
    KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT \
    KSU_SUSFS_SUS_KSTAT \
    KSU_SUSFS_SUS_OVERLAYFS \
    KSU_SUSFS_TRY_UMOUNT \
    KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT \
    KSU_SUSFS_SPOOF_UNAME \
    KSU_SUSFS_ENABLE_LOG \
    KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
    KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    KSU_SUSFS_OPEN_REDIRECT \
    KSU_SUSFS_HAS_MAGIC_MOUNT
  do
    ./scripts/config --file out/.config -e "$opt"
  done
fi

if [[ "$ENABLE_KSUN" == "true" || "$ENABLE_SUSFS" == "true" ]]; then
  make "${MAKE_ARGS[@]}" olddefconfig
fi
if [[ "$ENABLE_KSUN" == "true" ]]; then
  grep -Fxq 'CONFIG_KSU=y' out/.config || die "CONFIG_KSU is not enabled"
  grep -Fxq 'CONFIG_KSU_MANUAL_HOOK=y' out/.config ||
    die "KernelSU manual hook mode is not enabled"
  ! grep -Fxq 'CONFIG_KSU_KPROBES_HOOK=y' out/.config ||
    die "KernelSU kprobe hook mode was not disabled"
fi
if [[ "$ENABLE_SUSFS" == "true" ]]; then
  for opt in \
    KSU_SUSFS \
    KSU_SUSFS_SUS_PATH \
    KSU_SUSFS_SUS_MOUNT \
    KSU_SUSFS_SUS_KSTAT \
    KSU_SUSFS_SUS_OVERLAYFS \
    KSU_SUSFS_TRY_UMOUNT \
    KSU_SUSFS_SPOOF_UNAME \
    KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    KSU_SUSFS_OPEN_REDIRECT
  do
    grep -Fxq "CONFIG_${opt}=y" out/.config ||
      die "CONFIG_${opt} is not enabled"
  done
fi
grep -E 'CONFIG_KSU|CONFIG_KSU_SUSFS' out/.config | head -60
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

KSUN_REVISION=
KSUN_VERSION=
SUSFS_REVISION=
SUSFS_VERSION=
if [[ "$ENABLE_KSUN" == "true" ]]; then
  KSUN_REVISION="$(<"$KERNEL_DIR/.ksun-revision")"
  KSUN_VERSION="$(
    git -C "$KERNEL_DIR/KernelSU-Next" describe --tags --always 2>/dev/null ||
      printf '%s' "$KSUN_REVISION"
  )"
fi
if [[ "$ENABLE_SUSFS" == "true" ]]; then
  SUSFS_REVISION="$(<"$KERNEL_DIR/.susfs-revision")"
  SUSFS_VERSION="$(<"$KERNEL_DIR/.susfs-version")"
fi

ZIP_NAME="$(
  DEVICE_PROFILE="$DEVICE_PROFILE" \
  SOURCE_PRESET="$SOURCE_PRESET" \
  BUILD_MODE="$BUILD_MODE" \
  KERNEL_VERSION="$FULL_KVER" \
  SUSFS_VERSION="$SUSFS_VERSION" \
    bash "$SCRIPT_DIR/generate-package-name.sh"
)"
ARTIFACT_NAME="$(
  DEVICE_PROFILE="$DEVICE_PROFILE" \
  SOURCE_PRESET="$SOURCE_PRESET" \
  BUILD_MODE="$BUILD_MODE" \
  KERNEL_VERSION="$FULL_KVER" \
  SUSFS_VERSION="$SUSFS_VERSION" \
  OUTPUT_KIND=artifact \
    bash "$SCRIPT_DIR/generate-package-name.sh"
)"

log "Package AnyKernel3"
export KERNEL_DIR OUT_DIR="$KERNEL_DIR/out" ZIP_NAME DEVICE_PROFILE ARTIFACT_DIR
bash "$SCRIPT_DIR/package-anykernel.sh"
endgroup

ANYKERNEL_REVISION="$(<"$ARTIFACT_DIR/anykernel-revision.txt")"
IMAGE_SHA256="$(sha256sum "$ARTIFACT_DIR/Image" | awk '{print $1}')"
ZIP_SHA256="$(sha256sum "$ARTIFACT_DIR/$ZIP_NAME" | awk '{print $1}')"
printf '%s  %s\n' "$ZIP_SHA256" "$ZIP_NAME" \
  > "$ARTIFACT_DIR/$ZIP_NAME.sha256"

BUILDER_REVISION="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
WORKFLOW_RUN=
if [[ -n "${GITHUB_SERVER_URL:-}" &&
      -n "${GITHUB_REPOSITORY:-}" &&
      -n "${GITHUB_RUN_ID:-}" ]]; then
  WORKFLOW_RUN="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
fi

{
  echo "builder_revision=$BUILDER_REVISION"
  echo "source_preset=$SOURCE_PRESET"
  echo "kernel_source=$KERNEL_SOURCE"
  echo "kernel_branch=$KERNEL_BRANCH"
  echo "kernel_source_revision=$SOURCE_REVISION"
  echo "companion_source=$COMPANION_SOURCE"
  echo "companion_branch=$COMPANION_BRANCH"
  echo "companion_source_revision=$COMPANION_REVISION"
  echo "toolchain_profile=$TOOLCHAIN_PROFILE"
  echo "source_patch_set=$SOURCE_PATCH_SET"
  echo "native_feature_profile=$NATIVE_FEATURE_PROFILE"
  echo "build_mode=$BUILD_MODE"
  echo "defconfig=$DEFCONFIG"
  echo "device_profile=$DEVICE_PROFILE"
  echo "kernel_version=$FULL_KVER"
  echo "clean_build=$CLEAN_BUILD"
  echo "ksun_ref=$KSUN_REF"
  echo "ksun_revision=$KSUN_REVISION"
  echo "ksun_version=$KSUN_VERSION"
  echo "susfs_ref=$SUSFS_REF"
  echo "susfs_revision=$SUSFS_REVISION"
  echo "susfs_version=$SUSFS_VERSION"
  echo "anykernel_revision=$ANYKERNEL_REVISION"
  echo "image_sha256=$IMAGE_SHA256"
  echo "zip_sha256=$ZIP_SHA256"
  echo "zip_name=$ZIP_NAME"
  echo "artifact_name=$ARTIFACT_NAME"
  echo "workflow_run=$WORKFLOW_RUN"
  echo "build_completed_utc=$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
} | tee "$ARTIFACT_DIR/build-info.txt"

BUILD_INFO_FILE="$ARTIFACT_DIR/build-info.txt" \
SUMMARY_FILE="$ARTIFACT_DIR/build-summary.md" \
  bash "$SCRIPT_DIR/generate-build-summary.sh"

# Export for GitHub Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "zip_name=$ZIP_NAME"
    echo "artifact_name=$ARTIFACT_NAME"
    echo "kernel_version=$FULL_KVER"
    echo "image_path=$ARTIFACT_DIR/Image"
  } >> "$GITHUB_OUTPUT"
fi

log "Done: $ARTIFACT_DIR/$ZIP_NAME"
endgroup
