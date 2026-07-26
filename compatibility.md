# Compatibility — OnePlus 8 Series (SM8250)

## Scope

This builder lets you select one clean upstream source per manual workflow run:

| Preset | Upstream | Default branch | Defconfig | Device scope |
|--------|----------|----------------|-----------|--------------|
| `HELLBOY017` | [HELLBOY017/kernel_oneplus_sm8250](https://github.com/HELLBOY017/kernel_oneplus_sm8250) | `14` | `vendor/oplus-stock_defconfig` | OP8 series |
| `PPAJDA` | [ppajda/android_kernel_oneplus_sm8250](https://github.com/ppajda/android_kernel_oneplus_sm8250) | `oos13.1` | `op8_defconfig` | OP8 / OP8 Pro / OP8T |
| `TORAIDL` | [toraidl/android_kernel_oneplus_sm8250](https://github.com/toraidl/android_kernel_oneplus_sm8250) | `op8t` | `vendor/oplus-stock_defconfig` | OP8T / OP9R |

| Device | SoC | Notes |
|--------|-----|--------|
| OnePlus 8 | SM8250 | codename `instantnoodle` |
| OnePlus 8 Pro | SM8250 | codename `instantnoodlep` |
| OnePlus 8T | SM8250 | codename `kebab` |
| OnePlus 9R | SM8250-AC | codename `lemonades` |

**Not supported:** OnePlus 9/9 Pro (SM8350), OP7 series, OP10+ GKI devices.

`STOCK` does not alter the selected kernel source or defconfig. `KSUN` and `KSUN_SUSFS` add only KernelSU-Next and SUSFS integration changes.

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
| `STOCK` | No | No | Baseline / pure tree |
| `KSUN` | KernelSU-Next | No | Root without SUSFS |
| `KSUN_SUSFS` | KernelSU-Next | Yes (`kernel-4.19`) | Root + hide stack |

---

## Important warnings

1. **Community source trees** — they are not official OnePlus release artifacts; verify boot and hardware behavior on your exact OOS build.
2. **Non-GKI 4.19** — no LKM install; every KernelSU/SUSFS integration change needs a full kernel rebuild.
3. **SUSFS patches** may need reject fixes on OEM/community trees — first boots may need patch iteration.
4. **Unlocked bootloader**; disable verification when required.
5. **OTA** may replace your kernel — re-flash after major updates.
6. Always keep a **stock boot** backup.

---

## Manager / modules

- **KSUN / KSUN_SUSFS:** [KernelSU-Next Manager](https://github.com/KernelSU-Next/KernelSU-Next/releases)
- **SUSFS userspace:** [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module) (needs SUSFS-patched kernel)

---

## Cross-device / other branches

- Flashing this kernel on non–OP8-series hardware is **unsupported**.
- Develop only on **`op8series-sm8250-ksu-susfs`**. Treat **`main`** as read-only reference (GKI pipeline).
