# Compatibility — OnePlus 8 Series (SM8250)

## Scope

This builder **only** supports kernels from:

`https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250`

| Device | SoC | Notes |
|--------|-----|--------|
| OnePlus 8 | SM8250 | codename `instantnoodle` |
| OnePlus 8 Pro | SM8250 | codename `instantnoodlep` |
| OnePlus 8T | SM8250 | codename `kebab` |
| OnePlus 9R | SM8250-AC | codename `lemonades` |

**Not supported:** OnePlus 9/9 Pro (SM8350), OP7 series, OP10+ GKI devices.

---

## Branch ↔ ROM guide

Pick the OSS branch that matches **your device + stock Android/OOS generation**.

| Branch | Android | Typical devices |
|--------|---------|-----------------|
| `oneplus/SM8250_Q_10.0` | 10 | OP8, OP8 Pro |
| `oneplus/SM8250_R_11.0` | 11 | OP8, OP8 Pro, OP8T |
| `oneplus/SM8250_R_11.0_9R` | 11 | OP9R |
| `oneplus/sm8250_s_12.1` | 12 | OP8 series |
| `oneplus/sm8250_t_13.0.0_op8` | 13.0 | OP8, OP8 Pro, OP8T |
| `oneplus/sm8250_t_13.0.0_op9r` | 13.0 | OP9R |
| `oneplus/sm8250_t_13.1_op8` | 13.1 | OP8 class |
| `oneplus/sm8250_t_13.1_op9r` | 13.1 | OP9R |
| `oneplus/sm8250_u_14.0.0_op8t` | 14 | **OP8T** |
| `oneplus/sm8250_u_14.0.0_op9r` | 14 | **OP9R** |

There is **no** dedicated `u_14` dump for non-T OP8 in OnePlusOSS — OP8/OP8 Pro often stay on **T 13.1** trees for last official sources.

---

## Build modes

| Mode | Root | SUSFS | Use |
|------|------|-------|-----|
| `STOCK` | No | No | Baseline / debug pure tree |
| `KSUN` | KernelSU-Next | No | Root without SUSFS |
| `KSUN_SUSFS` | KernelSU-Next | Yes (`kernel-4.19`) | Root + hide stack |

---

## Important warnings

1. **Stock ROM oriented** — official dumps target OxygenOS-class trees. Custom ROMs may need different sources (e.g. Lineage).
2. **Non-GKI 4.19** — no LKM install; every change needs a full kernel rebuild.
3. **SUSFS patches often need reject fixes** on OEM trees — first boots may need patch iteration.
4. **Unlocked bootloader**; disable verification when required.
5. **OTA** may replace your kernel — re-flash after major updates.
6. Always keep a **stock boot** backup.

---

## Manager / modules

- **KSUN / KSUN_SUSFS:** [KernelSU-Next Manager](https://github.com/KernelSU-Next/KernelSU-Next/releases)
- **SUSFS userspace:** [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module) (needs SUSFS-patched kernel)

---

## Cross-device

Flashing this kernel on non–OP8-series hardware is **unsupported**. SM8250 ≠ modern GKI KMI matching used by OP10+.
