# Compatibility — OnePlus 8 Series (SM8250)

## Scope

This builder **only** uses:

**[HELLBOY017/kernel_oneplus_sm8250](https://github.com/HELLBOY017/kernel_oneplus_sm8250)**

| Device | SoC | Notes |
|--------|-----|--------|
| OnePlus 8 | SM8250 | codename `instantnoodle` |
| OnePlus 8 Pro | SM8250 | codename `instantnoodlep` |
| OnePlus 8T | SM8250 | codename `kebab` |
| OnePlus 9R | SM8250-AC | codename `lemonades` |

**Not supported:** other kernel trees (LineageOS, OnePlusOSS, Realking, …), OnePlus 9/9 Pro (SM8350), OP7 series, OP10+ GKI devices.

Default: HELLBOY branch **`14`**, defconfig **`vendor/oplus-stock_defconfig`**.  
Also selectable: **`13.1`**.

---

## Branch guide (HELLBOY)

| Branch | Typical use |
|--------|-------------|
| **`14`** | **Default** — A14-class stock-oriented CLO; STOCK verified |
| **`13.1`** | A13.1-class — prefer for stock OOS 13 / 13.1-era |
| `oos` | Older OOS-oriented (not in CI choices; research only) |

Workflow input: `kernel_branch` = `14` | `13.1`.  
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

1. **HELLBOY-only** — not an official OnePlus dump; stock-oriented community CLO tree.
2. **Non-GKI 4.19** — no LKM install; every change needs a full kernel rebuild.
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
