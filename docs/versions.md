# Pinned Versions — Verified OnePlus 8 Build

These are build inputs, not floating recommendations. The Run workflow reads
the integration SHAs from `configs/build-request.json`.

| Component | Source | Immutable revision | Purpose |
|---|---|---|---|
| OP8 kernel | `OnePlusOSS/android_kernel_oneplus_sm8250` | resolved from `oneplus/sm8250_t_13.1_op8` | Official OOS 13.1 kernel source |
| OP8 companion | `OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8250` | resolved from the matching branch | Published vendor and techpack source |
| Android Clang | Android `clang-r399163b` | Android 12.1 tag archive | OnePlus-declared Clang 11.0.5 profile |
| KernelSU-Next | `KernelSU-Next/KernelSU-Next` | `53791c92bff13d62338f29cc9da035a37652ca91` | Official manager/kernel source |
| SUSFS | `simonpunk/susfs4ksu` | `001e69919c6271f690fd00b17e4c721c9e599152` | Official Linux 4.19 source, version `v1.5.5` |
| AnyKernel3 | `WildKernels/AnyKernel3` | `e1e9dce98430c5c6f231f7094a8c7f4ecaf50948` | Packaging framework; installer is replaced by the OP8-specific script |

## GitHub Actions

Actions stay on compatible major versions and are pinned to the exact commits
resolved from their official major tags on 2026-07-26.

| Action | Major | Commit |
|---|---|---|
| `actions/checkout` | `v4` | `11d5960a326750d5838078e36cf38b85af677262` |
| `actions/upload-artifact` | `v4` | `ea165f8d65b6e75b540449e92b4886f43607fa02` |
| `actions/download-artifact` | `v4` | `d3f86a106a0bac45b974a628896c90dbdf5c8093` |
| `softprops/action-gh-release` | `v2` | `3bb12739c298aeb8a4eeaf626c5b8d85266b0e65` |

## Why the Marble pershoot fork is not used

The Marble evidence establishes `pershoot/KernelSU-Next@dev-susfs` as a proven
manager-side SUSFS route for that project's Linux 5.10 GKI kernel. It does not
prove compatibility with this OnePlus Linux 4.19 non-GKI port. This builder
already has clean GitHub compile/link proof using official KernelSU-Next plus
its exact 4.19 compatibility bridge, so switching to the fork would replace
verified evidence with an unverified integration.
