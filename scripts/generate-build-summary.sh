#!/usr/bin/env bash

set -euo pipefail

BUILD_INFO_FILE="${BUILD_INFO_FILE:-artifacts/build-info.txt}"
SUMMARY_FILE="${SUMMARY_FILE:-artifacts/build-summary.md}"

[[ -f "$BUILD_INFO_FILE" ]] ||
  { echo "error: build info not found: $BUILD_INFO_FILE" >&2; exit 1; }

declare -A info=()
while IFS='=' read -r key value; do
  [[ -n "$key" ]] || continue
  info["$key"]="$value"
done < "$BUILD_INFO_FILE"

value() {
  printf '%s' "${info[$1]:-}"
}

short_revision() {
  local revision=$1
  if [[ -n "$revision" ]]; then
    printf '%.7s' "$revision"
  else
    printf 'n/a'
  fi
}

repo_url() {
  printf '%s' "${1%.git}"
}

mode="$(value build_mode)"
case "$mode" in
  STOCK)
    title_mode="Stock (no root)"
    ksun_state="disabled"
    susfs_state="optional, disabled"
    ;;
  KSUN)
    title_mode="KernelSU-Next"
    ksun_state="enabled · \`$(value ksun_version)\` · \`$(short_revision "$(value ksun_revision)")\`"
    susfs_state="optional, disabled"
    ;;
  KSUN_SUSFS)
    title_mode="KernelSU-Next + SUSFS"
    ksun_state="enabled · \`$(value ksun_version)\` · \`$(short_revision "$(value ksun_revision)")\`"
    susfs_state="optional, enabled · \`$(value susfs_version)\` · \`$(short_revision "$(value susfs_revision)")\`"
    ;;
  *)
    echo "error: unsupported build_mode in metadata: $mode" >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "$SUMMARY_FILE")"
{
  echo "# OnePlus 8 Kernel · $title_mode"
  echo
  echo "> [!WARNING]"
  echo "> **Compile/package proof — physical-device boot is still unverified.**"
  echo "> Flash only on a matching OnePlus 8 OOS 13.1 base and keep its stock boot image off-device."
  echo
  echo "## Build identity"
  echo
  echo "| Field | Value |"
  echo "|---|---|"
  echo "| **Device** | OnePlus 8 (\`instantnoodle\`) |"
  echo "| **Source preset** | \`$(value source_preset)\` |"
  echo "| **Kernel branch** | \`$(value kernel_branch)\` |"
  echo "| **Kernel version** | \`$(value kernel_version)\` |"
  echo "| **Defconfig** | \`$(value defconfig)\` |"
  echo "| **Toolchain** | \`$(value toolchain_profile)\` |"
  echo "| **Build mode** | \`$mode\` |"
  echo "| **KernelSU-Next** | $ksun_state |"
  echo "| **SUSFS** | $susfs_state |"
  echo
  echo "## Resolved revisions"
  echo
  echo "| Component | Revision |"
  echo "|---|---|"
  echo "| [Kernel source]($(repo_url "$(value kernel_source)")) | \`$(value kernel_source_revision)\` |"
  if [[ -n "$(value companion_source)" ]]; then
    echo "| [OnePlus companion source]($(repo_url "$(value companion_source)")) | \`$(value companion_source_revision)\` |"
  fi
  if [[ "$mode" != "STOCK" ]]; then
    echo "| [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) | \`$(value ksun_revision)\` |"
  fi
  if [[ "$mode" == "KSUN_SUSFS" ]]; then
    echo "| [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) | \`$(value susfs_revision)\` (\`$(value susfs_version)\`) |"
  fi
  echo "| [AnyKernel3](https://github.com/WildKernels/AnyKernel3) | \`$(value anykernel_revision)\` |"
  echo
  echo "## Artifacts and checksums"
  echo
  echo "| Artifact | SHA-256 |"
  echo "|---|---|"
  echo "| \`$(value zip_name)\` | \`$(value zip_sha256)\` |"
  echo "| \`Image\` | \`$(value image_sha256)\` |"
  echo
  echo "## Flash and recovery"
  echo
  echo "1. Flash only on a matching OnePlus 8 OOS 13.1 base."
  echo "2. Verify the ZIP SHA-256 before flashing."
  echo "3. Keep the matching stock \`boot.img\` available before rebooting."
  echo "4. If boot fails, restore that stock boot image to the active slot."
  if [[ "$mode" == "KSUN_SUSFS" ]]; then
    echo "5. After KernelSU-Next root works, install a userspace module compatible with SUSFS \`$(value susfs_version)\`."
  fi
  if [[ -n "$(value workflow_run)" ]]; then
    echo
    echo "[View GitHub Actions run]($(value workflow_run))"
  fi
} > "$SUMMARY_FILE"

echo "Generated $SUMMARY_FILE"
