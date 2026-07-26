#!/usr/bin/env bash
# Apply the audited manual KernelSU hooks for the official OP8 4.19 tree.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="${KERNEL_DIR:-.}"
PATCH="$ROOT_DIR/patches/oneplusoss-sm8250-ksun-manual-hooks.patch"

die() { echo "error: $*" >&2; exit 1; }

KERNEL_DIR="$(cd "$KERNEL_DIR" && pwd)"
[[ -f "$KERNEL_DIR/Makefile" ]] || die "invalid kernel root: $KERNEL_DIR"
[[ -f "$PATCH" ]] || die "manual hook patch missing: $PATCH"

git -C "$KERNEL_DIR" apply --recount --check "$PATCH"
git -C "$KERNEL_DIR" apply --recount "$PATCH"

declare -A REQUIRED=(
  ["fs/exec.c"]="ksu_handle_execveat(&fd"
  ["fs/open.c"]="ksu_handle_faccessat(&dfd"
  ["fs/read_write.c"]="ksu_handle_vfs_read(&file"
  ["fs/stat.c"]="ksu_handle_stat(&dfd"
  ["drivers/input/input.c"]="ksu_handle_input_handle_event(&type"
  ["kernel/reboot.c"]="ksu_handle_sys_reboot(magic1"
  ["fs/namespace.c"]="int path_umount(struct path *path"
)

for file in "${!REQUIRED[@]}"; do
  count="$(grep -Fc "${REQUIRED[$file]}" "$KERNEL_DIR/$file")"
  [[ "$count" == 1 ]] ||
    die "expected exactly one ${REQUIRED[$file]} hook in $file, found $count"
done

if find "$KERNEL_DIR" \( -name '*.rej' -o -name '*.orig' \) \
  -print -quit | grep -q .; then
  die "manual hook integration produced reject/backup files"
fi

echo "[hooks] current KernelSU manual hooks applied exactly once"
