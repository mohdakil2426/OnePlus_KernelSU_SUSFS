# Compatibility — OnePlus 8 Series (SM8250)

## Scope

This builder lets you select one source preset per manual workflow run:

| Preset | Upstream | Default branch | Defconfig | Device scope |
|--------|----------|----------------|-----------|--------------|
| `HELLBOY017` | [HELLBOY017/kernel_oneplus_sm8250](https://github.com/HELLBOY017/kernel_oneplus_sm8250) | `14` | `vendor/oplus-stock_defconfig` | OP8 series |
| `PPAJDA` | [ppajda/android_kernel_oneplus_sm8250](https://github.com/ppajda/android_kernel_oneplus_sm8250) | `oos13.1` | `op8_defconfig` | OP8 / OP8 Pro / OP8T |
| `TORAIDL` | [toraidl/android_kernel_oneplus_sm8250](https://github.com/toraidl/android_kernel_oneplus_sm8250) | `op8t` | `vendor/oplus-stock_defconfig` | OP8T / OP9R |
| `ONEPLUSOSS_OP8_OOS13_1` | [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) | `oneplus/sm8250_t_13.1_op8` | `vendor/kona-perf_defconfig` | OP8 on OOS 13.1 |
| `ONEPLUSOSS_OP9R_OOS13_1` | [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) | `oneplus/sm8250_t_13.1_op9r` | `vendor/kona-perf_defconfig` | OP9R on OOS 13.1 |
| `ONEPLUSOSS_OP8T_OOS14` | [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) | `oneplus/sm8250_u_14.0.0_op8t` | `vendor/kona-perf_defconfig` | OP8T on OOS 14 |
| `ONEPLUSOSS_OP9R_OOS14` | [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) | `oneplus/sm8250_u_14.0.0_op9r` | `vendor/kona-perf_defconfig` | OP9R on OOS 14 |

| Device | SoC | Notes |
|--------|-----|--------|
| OnePlus 8 | SM8250 | codename `instantnoodle` |
| OnePlus 8 Pro | SM8250 | codename `instantnoodlep` |
| OnePlus 8T | SM8250 | codename `kebab` |
| OnePlus 9R | SM8250-AC | codename `lemonades` |

**Not supported:** OnePlus 9/9 Pro (SM8350), OP7 series, OP10+ GKI devices.

Community `STOCK` presets do not alter the selected kernel source or defconfig. Official `ONEPLUSOSS_*` presets apply the audited `oneplusoss-sm8250-strict-prototypes` compatibility set and are stock-derived; it repairs two strict-prototype violations, the invalid `__packed` return-type annotation that breaks GSI symbol-version generation, and the misplaced RTIC BSS output section. Their defconfig remains unchanged. `KSUN` and `KSUN_SUSFS` add only KernelSU-Next and SUSFS integration changes.

Official presets use the same-named branch from both [the kernel repository](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) and [the companion modules/device-tree repository](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8250). A kernel-only clone is incomplete because its relative symlinks expect the companion `vendor/` and `kernel/msm-4.19/techpack/` trees in the shared source workspace.

The official branches declare Android Clang `r399163b` (11.0.5), `LLVM=1`, and GNU cross-assembler prefixes `aarch64-linux-gnu-` / `arm-linux-gnueabi-`. They also publish their Oplus build-feature environment in `oplus_native_features.mk`; the builder exports those branch-owned scalar values before `defconfig` and compilation so feature-gated objects match the selected configuration. The workflow selects this profile only for `ONEPLUSOSS_*`; community presets keep ZyC Clang 14.

---

## Branch guide (HELLBOY)

| Branch | Typical use |
|--------|-------------|
| **`14`** | **Default** — A14-class stock-oriented CLO; STOCK verified |
| **`13.1`** | A13.1-class — prefer for stock OOS 13 / 13.1-era |
| **`13.1-new`** | A13.1-class refreshed tip (WLAN etc. experiments) |
| `oos` | Older OOS-oriented (not in CI choices; research only) |

Workflow input: select `source_preset`; leave `kernel_branch` empty to use its default, or enter one of that preset's configured allowed branches.
**Not all branches boot all stock OOS builds** — match generation to your ROM.

---

## Build modes

| Mode | Root | SUSFS | Use |
|------|------|-------|-----|
| `STOCK` | No | No | Baseline; official presets may include their declared compatibility patch |
| `KSUN` | KernelSU-Next | No | Root without SUSFS |
| `KSUN_SUSFS` | KernelSU-Next | Yes (`kernel-4.19`) | Root + hide stack |

The OP8 clean request is immutable: KernelSU-Next
`53791c92bff13d62338f29cc9da035a37652ca91`
(`v3.2.0-legacy-13-g53791c92`), official SUSFS 4.19
`001e69919c6271f690fd00b17e4c721c9e599152` (`v1.5.5`), and WildKernels
AnyKernel3 framework `e1e9dce98430c5c6f231f7094a8c7f4ecaf50948`.
The current KernelSU repository no longer has the flat layout expected by the
official SUSFS 4.19 patch, so this builder owns a small, fail-fast compatibility
bridge and an exact OnePlus 4.19 rebase. Patch fuzz and rejected hunks are not
accepted.

Clean GitHub Actions run
[`30208343645`](https://github.com/mohdakil2426/OnePlus_KernelSU_SUSFS/actions/runs/30208343645)
compiled both `fs/susfs.o` and the current KernelSU object set, linked
`arch/arm64/boot/Image`, and validated the OP8 AnyKernel package. The downloaded
`Image` SHA-256 is
`74f83b13371cea1f611373f0703be14ecf1ac16efa52a769e44d81f164fc8132`;
the ZIP SHA-256 is
`a2f3202e79f0c7c1cc6e3351855d0fa2db7f280fb1e8f8cb1364b9dca2047d24`.
This is compile/package proof, not physical boot proof.

---

## Important warnings

1. **Source provenance** — the `ONEPLUSOSS_*` presets are official source branches; community presets still need exact-device boot and hardware verification.
2. **Non-GKI 4.19** — no LKM install; every KernelSU/SUSFS integration change needs a full kernel rebuild.
3. **SUSFS patches** may need reject fixes on OEM/community trees — first boots may need patch iteration.
4. **Unlocked bootloader**; disable verification when required.
5. **OTA** may replace your kernel — re-flash after major updates.
6. Always keep a **stock boot** backup.
7. A green build validates `Image` generation and ZIP structure only. Physical
   boot, display, modem, Wi-Fi, camera, charging, suspend, and recovery flashing
   remain unverified until tested on the exact OP8/OOS combination.

---

## Manager / modules

- **KSUN / KSUN_SUSFS:** [KernelSU-Next Manager](https://github.com/KernelSU-Next/KernelSU-Next/releases)
- **SUSFS userspace:** [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module) (needs SUSFS-patched kernel)

---

## Cross-device / other branches

- Flashing this kernel on non–OP8-series hardware is **unsupported**.
- Develop only on **`op8series-sm8250-ksu-susfs`**. Treat **`main`** as read-only reference (GKI pipeline).
