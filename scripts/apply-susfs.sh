#!/usr/bin/env bash
# Apply susfs4ksu kernel-4.19 patches into current kernel tree.
# Official non-GKI flow: https://gitlab.com/simonpunk/susfs4ksu (branch kernel-4.19)
# Env:
#   SUSFS_REF   - git branch/tag (default: kernel-4.19)
#   KERNEL_DIR  - kernel root
#   WORK_DIR    - where to clone susfs (default: parent of kernel)

set -euo pipefail

SUSFS_REF="${SUSFS_REF:-kernel-4.19}"
KERNEL_DIR="${KERNEL_DIR:-.}"
WORK_DIR="${WORK_DIR:-$(cd "$KERNEL_DIR/.." && pwd)}"

cd "$KERNEL_DIR"
KERNEL_DIR="$(pwd)"

log() { echo "[susfs] $*"; }
warn() { echo "[susfs][warn] $*" >&2; }

log "Cloning susfs4ksu @ $SUSFS_REF"
rm -rf "$WORK_DIR/susfs4ksu"
if ! git clone --depth=1 -b "$SUSFS_REF" https://gitlab.com/simonpunk/susfs4ksu.git "$WORK_DIR/susfs4ksu"; then
  warn "GitLab clone failed; trying GitHub mirror"
  git clone --depth=1 -b "$SUSFS_REF" https://github.com/sidex15/susfs4ksu.git "$WORK_DIR/susfs4ksu" \
    || git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git "$WORK_DIR/susfs4ksu"
fi

SUSFS="$WORK_DIR/susfs4ksu"
PATCHES="$SUSFS/kernel_patches"

if [[ ! -d "$PATCHES" ]]; then
  echo "error: kernel_patches missing in susfs clone" >&2
  exit 1
fi

# Copy sources
log "Copying SUSFS fs/include sources"
cp -v "$PATCHES"/fs/* "$KERNEL_DIR/fs/" 2>/dev/null || true
cp -v "$PATCHES"/include/linux/* "$KERNEL_DIR/include/linux/" 2>/dev/null || true

# Kernel patch
KERNEL_PATCH=""
for cand in \
  "$PATCHES/50_add_susfs_in_kernel-4.19.patch" \
  "$PATCHES/50_add_susfs_in_kernel.patch"
do
  if [[ -f "$cand" ]]; then
    KERNEL_PATCH="$cand"
    break
  fi
done

if [[ -n "$KERNEL_PATCH" ]]; then
  log "Applying $(basename "$KERNEL_PATCH") (best-effort)"
  set +e
  patch -p1 --no-backup-if-mismatch -F3 < "$KERNEL_PATCH" | tee /tmp/susfs_kernel_patch.log
  PATCH_RC=${PIPESTATUS[0]}
  set -e
  if [[ $PATCH_RC -ne 0 ]]; then
    warn "Kernel SUSFS patch returned $PATCH_RC — check /tmp/susfs_kernel_patch.log and .rej files"
    find . -name '*.rej' -print | head -50 || true
  fi
else
  warn "No 50_add_susfs_in_kernel* patch found"
fi

# Ensure susfs.o in fs/Makefile
if [[ -f fs/Makefile ]] && ! grep -q 'susfs.o' fs/Makefile; then
  log "Adding susfs.o to fs/Makefile"
  echo 'obj-$(CONFIG_KSU_SUSFS) += susfs.o' >> fs/Makefile
fi

# KernelSU driver SUSFS enable patch
KSU_PARENT=""
if [[ -L drivers/kernelsu ]]; then
  KSU_PARENT="$(dirname "$(readlink -f drivers/kernelsu)")"
elif [[ -d KernelSU-Next ]]; then
  KSU_PARENT="KernelSU-Next"
elif [[ -d KernelSU ]]; then
  KSU_PARENT="KernelSU"
elif [[ -d drivers/kernelsu ]]; then
  KSU_PARENT="drivers/kernelsu"
fi

KSU_PATCH="$PATCHES/KernelSU/10_enable_susfs_for_ksu.patch"
if [[ -n "$KSU_PARENT" && -f "$KSU_PATCH" && -d "$KSU_PARENT" ]]; then
  log "Applying 10_enable_susfs_for_ksu.patch in $KSU_PARENT (best-effort)"
  (
    cd "$KSU_PARENT"
    set +e
    patch -p1 --no-backup-if-mismatch -F3 < "$KSU_PATCH" | tee /tmp/susfs_ksu_patch.log
    set -e
  ) || warn "KSU SUSFS patch had rejects — may need manual port for this KSUN version"
else
  warn "Skipping KernelSU SUSFS patch (parent or patch missing)"
fi

# Cleanup reject noise from workspace root (keep logs)
find . -name '*.orig' -delete 2>/dev/null || true

log "SUSFS apply step finished"
