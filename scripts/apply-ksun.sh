#!/usr/bin/env bash
# Integrate KernelSU-Next (non-GKI / legacy) into current kernel tree.
# Env:
#   KSUN_REF   - git ref for KernelSU-Next (default: next)
#   KERNEL_DIR - kernel root (default: cwd)

set -euo pipefail

KSUN_REF="${KSUN_REF:-next}"
KERNEL_DIR="${KERNEL_DIR:-.}"

cd "$KERNEL_DIR"

log() { echo "[ksun] $*"; }

log "Integrating KernelSU-Next (ref=$KSUN_REF) via legacy non-GKI setup"

# Prefer next/kernel/setup.sh with legacy arg; fall back to legacy branch setup path.
SETUP_URL="https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/${KSUN_REF}/kernel/setup.sh"
if ! curl -fsSL "$SETUP_URL" -o /tmp/ksun_setup.sh; then
  log "Ref $KSUN_REF failed; trying legacy branch setup.sh"
  curl -fsSL "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/legacy/kernel/setup.sh" -o /tmp/ksun_setup.sh
fi

bash /tmp/ksun_setup.sh legacy || bash /tmp/ksun_setup.sh "$KSUN_REF" || bash /tmp/ksun_setup.sh

# Locate driver
KSU_DRIVER=""
if [[ -d drivers/kernelsu ]]; then
  KSU_DRIVER="drivers/kernelsu"
elif [[ -L drivers/kernelsu ]]; then
  KSU_DRIVER="$(readlink -f drivers/kernelsu)"
else
  KSU_DRIVER="$(find . -maxdepth 3 -type d -name 'kernelsu' 2>/dev/null | head -1 || true)"
fi

if [[ -z "$KSU_DRIVER" || ! -d "$KSU_DRIVER" ]]; then
  echo "error: KernelSU driver directory not found after setup" >&2
  exit 1
fi

log "Driver at: $KSU_DRIVER"

# For SUSFS non-GKI path, force non-kprobe compilation style when requested
if [[ "${FORCE_NO_KPROBE:-false}" == "true" ]]; then
  log "Disabling CONFIG_KPROBES use inside KernelSU sources"
  find "$KSU_DRIVER" -type f \( -name '*.c' -o -name '*.h' \) -print0 2>/dev/null \
    | xargs -0 -r sed -i \
      -e 's/#ifdef CONFIG_KPROBES/#if defined(CONFIG_KPROBES) \&\& 0/g' \
      -e 's/#if defined(CONFIG_KPROBES)$/#if defined(CONFIG_KPROBES) \&\& 0/g' || true
  if [[ -f "$KSU_DRIVER/Makefile" ]] && ! grep -q 'KSU_UMOUNT' "$KSU_DRIVER/Makefile"; then
    echo 'ccflags-y += -DKSU_UMOUNT' >> "$KSU_DRIVER/Makefile"
  fi
fi

echo "$KSU_DRIVER" > /tmp/ksun_driver_path.txt
log "KernelSU-Next setup complete"
