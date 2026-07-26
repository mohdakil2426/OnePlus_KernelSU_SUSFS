#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

pass() { printf 'ok - %s\n' "$1"; }
fail() { printf 'not ok - %s\n' "$1" >&2; failures=$((failures + 1)); }

contains() {
  local file=$1 pattern=$2 label=$3
  if grep -Fq -- "$pattern" "$ROOT/$file"; then pass "$label"; else fail "$label"; fi
}

excludes() {
  local file=$1 pattern=$2 label=$3
  if grep -Fq -- "$pattern" "$ROOT/$file"; then fail "$label"; else pass "$label"; fi
}

executable_file() {
  local file=$1 label=$2
  if [[ -x "$ROOT/$file" ]]; then pass "$label"; else fail "$label"; fi
}

KSUN_SHA=53791c92bff13d62338f29cc9da035a37652ca91
SUSFS_SHA=001e69919c6271f690fd00b17e4c721c9e599152
ANYKERNEL_SHA=e1e9dce98430c5c6f231f7094a8c7f4ecaf50948

contains scripts/apply-ksun.sh "$KSUN_SHA" "KernelSU default is immutable"
excludes scripts/apply-ksun.sh "trying legacy" "KernelSU has no silent ref fallback"
excludes scripts/apply-ksun.sh "|| bash" "KernelSU setup has no retry-as-different-command fallback"

contains scripts/apply-susfs.sh "$SUSFS_SHA" "SUSFS default is immutable"
excludes scripts/apply-susfs.sh "best-effort" "SUSFS patching is fail-closed"
excludes scripts/apply-susfs.sh " -F3" "SUSFS patching does not fuzz context"
contains scripts/apply-susfs.sh "apply --recount --check" "SUSFS checks patches before applying"
contains scripts/apply-susfs.sh "*.rej" "SUSFS rejects are asserted absent"
contains assets/ksun-susfs-v1.5.5.c "void susfs_try_umount_all(uid_t uid)" "SUSFS namespace wrapper is linked"
contains patches/ksun-current-susfs-v1.5.5.patch "defined(CONFIG_KSU_KPROBES_HOOK)" "SELinux hide follows the selected KSU hook mode"

contains scripts/package-anykernel.sh "$ANYKERNEL_SHA" "AnyKernel source is immutable"
contains scripts/package-anykernel.sh "verify-anykernel.sh" "packager validates generated ZIP"
contains assets/anykernel-op8.sh "device.name1=instantnoodle" "installer is scoped to OnePlus 8"
contains assets/anykernel-op8.sh "block=boot" "installer resolves the boot partition"
contains assets/anykernel-op8.sh "is_slot_device=auto" "installer auto-detects active slot"
excludes assets/anykernel-op8.sh "tuna" "installer has no sample Tuna target"
excludes assets/anykernel-op8.sh "/dev/block/platform/omap" "installer has no sample OMAP path"
executable_file scripts/verify-anykernel.sh "AnyKernel validator is executable"

contains .github/workflows/build-kernel.yml "jq -er '.ksun_ref'" "workflow reads the configured KernelSU pin"
contains .github/workflows/build-kernel.yml "jq -er '.susfs_ref'" "workflow reads the configured SUSFS pin"
contains configs/build-request.json "$KSUN_SHA" "request config pins KernelSU"
contains configs/build-request.json "$SUSFS_SHA" "request config pins SUSFS"
excludes scripts/apply-ksun.sh "pershoot/KernelSU-Next" "OnePlus uses official KernelSU-Next, not the Marble fork"

if (( failures > 0 )); then
  printf '\n%d contract test(s) failed\n' "$failures" >&2
  exit 1
fi

printf '\nall integration contract tests passed\n'
