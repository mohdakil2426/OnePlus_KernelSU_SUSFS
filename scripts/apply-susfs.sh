#!/usr/bin/env bash
# Integrate official SUSFS v1.5.5 into the audited OnePlus 4.19 tree.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUSFS_REPO="${SUSFS_REPO:-https://gitlab.com/simonpunk/susfs4ksu.git}"
SUSFS_REF="${SUSFS_REF:-001e69919c6271f690fd00b17e4c721c9e599152}"
KERNEL_DIR="${KERNEL_DIR:-.}"
WORK_DIR="${WORK_DIR:-$(cd "$KERNEL_DIR/.." && pwd)}"

die() { echo "error: $*" >&2; exit 1; }
log() { echo "[susfs] $*"; }

[[ "$SUSFS_REF" =~ ^[0-9a-f]{40}$ ]] ||
  die "SUSFS_REF must be a full immutable commit SHA, got: $SUSFS_REF"

KERNEL_DIR="$(cd "$KERNEL_DIR" && pwd)"
SUSFS_DIR="$WORK_DIR/susfs4ksu"
KSUN_DIR="$KERNEL_DIR/KernelSU-Next"
KERNEL_PATCH="$ROOT_DIR/patches/oneplusoss-sm8250-susfs-4.19.patch"
KSUN_PATCH="$ROOT_DIR/patches/ksun-current-susfs-v1.5.5.patch"
KSUN_BRIDGE="$ROOT_DIR/assets/ksun-susfs-v1.5.5.c"

[[ -d "$KSUN_DIR/.git" ]] || die "KernelSU-Next must be integrated first"
for required in "$KERNEL_PATCH" "$KSUN_PATCH" "$KSUN_BRIDGE"; do
  [[ -f "$required" ]] || die "required integration file missing: $required"
done

rm -rf "$SUSFS_DIR"
log "Cloning official SUSFS @ $SUSFS_REF"
git clone --filter=blob:none --no-checkout "$SUSFS_REPO" "$SUSFS_DIR"
git -C "$SUSFS_DIR" checkout --detach "$SUSFS_REF"
RESOLVED="$(git -C "$SUSFS_DIR" rev-parse HEAD)"
[[ "$RESOLVED" == "$SUSFS_REF" ]] ||
  die "SUSFS revision mismatch: expected $SUSFS_REF, got $RESOLVED"

PATCH_ROOT="$SUSFS_DIR/kernel_patches"
[[ -f "$PATCH_ROOT/fs/susfs.c" &&
   -f "$PATCH_ROOT/include/linux/susfs.h" &&
   -f "$PATCH_ROOT/include/linux/susfs_def.h" ]] ||
  die "official SUSFS 4.19 sources are missing"
grep -Fq '#define SUSFS_VERSION "v1.5.5"' \
  "$PATCH_ROOT/include/linux/susfs.h" ||
  die "unexpected SUSFS version at pinned revision"

log "Copying official SUSFS source files"
cp "$PATCH_ROOT"/fs/* "$KERNEL_DIR/fs/"
cp "$PATCH_ROOT"/include/linux/* "$KERNEL_DIR/include/linux/"

log "Applying audited OnePlus 4.19 kernel port"
git -C "$KERNEL_DIR" apply --recount --check "$KERNEL_PATCH"
git -C "$KERNEL_DIR" apply --recount "$KERNEL_PATCH"

log "Applying current KernelSU-Next compatibility bridge"
cp "$KSUN_BRIDGE" "$KSUN_DIR/kernel/feature/susfs_legacy.c"
git -C "$KSUN_DIR" apply --recount --check "$KSUN_PATCH"
git -C "$KSUN_DIR" apply --recount "$KSUN_PATCH"

if find "$KERNEL_DIR" "$KSUN_DIR" \
  \( -name '*.rej' -o -name '*.orig' \) -print -quit | grep -q .; then
  find "$KERNEL_DIR" "$KSUN_DIR" \
    \( -name '*.rej' -o -name '*.orig' \) -print >&2
  die "SUSFS integration produced reject/backup files"
fi

grep -Fq 'obj-$(CONFIG_KSU_SUSFS) += susfs.o' "$KERNEL_DIR/fs/Makefile" ||
  die "SUSFS object is not registered"
grep -Fq 'config KSU_SUSFS' "$KSUN_DIR/kernel/Kconfig" ||
  die "KernelSU SUSFS Kconfig bridge is missing"
grep -Fq 'LSM_HOOK_INIT(task_prctl, ksu_task_prctl)' \
  "$KSUN_DIR/kernel/hook/lsm_hooks.c" ||
  die "SUSFS userspace command hook is missing"

printf '%s\n' "$RESOLVED" > "$KERNEL_DIR/.susfs-revision"
printf '%s\n' 'v1.5.5' > "$KERNEL_DIR/.susfs-version"
log "SUSFS integration complete: $RESOLVED (v1.5.5)"
