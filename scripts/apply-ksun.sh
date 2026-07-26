#!/usr/bin/env bash
# Integrate an immutable KernelSU-Next legacy revision into a non-GKI tree.

set -euo pipefail

KSUN_REPO="${KSUN_REPO:-https://github.com/KernelSU-Next/KernelSU-Next.git}"
KSUN_REF="${KSUN_REF:-53791c92bff13d62338f29cc9da035a37652ca91}"
KERNEL_DIR="${KERNEL_DIR:-.}"

die() { echo "error: $*" >&2; exit 1; }
log() { echo "[ksun] $*"; }

[[ "$KSUN_REF" =~ ^[0-9a-f]{40}$ ]] ||
  die "KSUN_REF must be a full immutable commit SHA, got: $KSUN_REF"

cd "$KERNEL_DIR"
[[ -f Makefile && -d drivers ]] || die "invalid kernel root: $KERNEL_DIR"

rm -rf KernelSU-Next drivers/kernelsu
log "Cloning KernelSU-Next @ $KSUN_REF"
git clone --filter=blob:none --no-checkout "$KSUN_REPO" KernelSU-Next
git -C KernelSU-Next checkout --detach "$KSUN_REF"

RESOLVED="$(git -C KernelSU-Next rev-parse HEAD)"
[[ "$RESOLVED" == "$KSUN_REF" ]] ||
  die "KernelSU revision mismatch: expected $KSUN_REF, got $RESOLVED"
[[ -f KernelSU-Next/kernel/Kconfig && -f KernelSU-Next/kernel/Kbuild ]] ||
  die "KernelSU current legacy kernel layout is missing"

ln -s ../KernelSU-Next/kernel drivers/kernelsu
grep -Fq 'obj-$(CONFIG_KSU) += kernelsu/' drivers/Makefile ||
  printf '\nobj-$(CONFIG_KSU) += kernelsu/\n' >> drivers/Makefile
if ! grep -Fq 'source "drivers/kernelsu/Kconfig"' drivers/Kconfig; then
  sed -i '/^endmenu/i source "drivers/kernelsu/Kconfig"' drivers/Kconfig
fi

grep -Fq 'source "drivers/kernelsu/Kconfig"' drivers/Kconfig ||
  die "failed to register KernelSU Kconfig"
grep -Fq 'obj-$(CONFIG_KSU) += kernelsu/' drivers/Makefile ||
  die "failed to register KernelSU Makefile"

printf '%s\n' "$RESOLVED" > .ksun-revision
log "KernelSU-Next integration complete: $RESOLVED"
