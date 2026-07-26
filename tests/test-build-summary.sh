#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/build-info.txt" <<'INFO'
source_preset=ONEPLUSOSS_OP8_OOS13_1
kernel_source=https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250.git
kernel_branch=oneplus/sm8250_t_13.1_op8
kernel_source_revision=9fdb3aa681ecbafa77e160bd93d0740537c6457c
companion_source=https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8250.git
companion_branch=oneplus/sm8250_t_13.1_op8
companion_source_revision=dab8a261393373f8be4e85209eafcdf0d5f461cb
toolchain_profile=android-clang-r399163b
source_patch_set=oneplusoss-sm8250-strict-prototypes
build_mode=KSUN_SUSFS
defconfig=vendor/kona-perf_defconfig
device_profile=OP8
kernel_version=4.19.157
ksun_revision=53791c92bff13d62338f29cc9da035a37652ca91
ksun_version=v3.2.0-legacy-13-g53791c92
susfs_revision=001e69919c6271f690fd00b17e4c721c9e599152
susfs_version=v1.5.5
anykernel_revision=e1e9dce98430c5c6f231f7094a8c7f4ecaf50948
image_sha256=74f83b13371cea1f611373f0703be14ecf1ac16efa52a769e44d81f164fc8132
zip_sha256=a2f3202e79f0c7c1cc6e3351855d0fa2db7f280fb1e8f8cb1364b9dca2047d24
zip_name=AK3_op8_oneplusoss-op8-oos13-1_ksun_susfs-v1.5.5_k4.19.157_r42.zip
workflow_run=https://github.com/mohdakil2426/OnePlus_KernelSU_SUSFS/actions/runs/42
INFO

BUILD_INFO_FILE="$TMP/build-info.txt" SUMMARY_FILE="$TMP/build-summary.md" \
  bash "$ROOT/scripts/generate-build-summary.sh"

SUMMARY="$TMP/build-summary.md"
[[ -s "$SUMMARY" ]] || { echo "error: summary was not created" >&2; exit 1; }

required=(
  '# OnePlus 8 Kernel · KernelSU-Next + SUSFS'
  'Compile/package proof — physical-device boot is still unverified'
  '| **Device** | OnePlus 8 (`instantnoodle`) |'
  '| **Source preset** | `ONEPLUSOSS_OP8_OOS13_1` |'
  '| **KernelSU-Next** | enabled · `v3.2.0-legacy-13-g53791c92` · `53791c9` |'
  '| **SUSFS** | optional, enabled · `v1.5.5` · `001e699` |'
  'AK3_op8_oneplusoss-op8-oos13-1_ksun_susfs-v1.5.5_k4.19.157_r42.zip'
  '74f83b13371cea1f611373f0703be14ecf1ac16efa52a769e44d81f164fc8132'
  'a2f3202e79f0c7c1cc6e3351855d0fa2db7f280fb1e8f8cb1364b9dca2047d24'
  'Flash only on a matching OnePlus 8 OOS 13.1 base'
)

for pattern in "${required[@]}"; do
  grep -Fq -- "$pattern" "$SUMMARY" || {
    echo "error: summary missing: $pattern" >&2
    exit 1
  }
done

echo "Build summary tests passed"
