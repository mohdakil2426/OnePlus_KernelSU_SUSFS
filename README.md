# OnePlus 8 Series Kernel Builder (SM8250)

Build **stock**, **KernelSU-Next**, or **KernelSU-Next + SUSFS** kernels for:

| Device | SoC | Codenames |
|--------|-----|-----------|
| OnePlus 8 | SM8250 | `instantnoodle` |
| OnePlus 8 Pro | SM8250 | `instantnoodlep` |
| OnePlus 8T | SM8250 | `kebab` |
| OnePlus 9R | SM8250-AC (SD870) | `lemonades` |

**Kernel source (only):**  
[OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250)

This branch is **not** for OP10+ GKI devices. Those belong on the multi-device WildKernels pipeline.

---

## Features

| Mode | What you get |
|------|----------------|
| **STOCK** | Non-root baseline (no KernelSU / no SUSFS) |
| **KSUN** | [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) built-in (non-GKI 4.19) |
| **KSUN_SUSFS** | KSUN + [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) (`kernel-4.19`) |

- Manual GitHub Actions control over **all 10 official OSS branches**
- Defconfig: `vendor/kona-perf_defconfig` (or `vendor/kona_defconfig`)
- Flashable **AnyKernel3** ZIP
- Linux **4.19.x** monolithic tree (not GKI / not LKM)

---

## Build (GitHub Actions)

1. Open **Actions** → **Build OP8 Series Kernel (SM8250)**
2. **Run workflow**
3. Choose:

| Input | Purpose |
|-------|---------|
| `kernel_branch` | One of the 10 OnePlusOSS branches |
| `build_mode` | `STOCK` / `KSUN` / `KSUN_SUSFS` |
| `device_profile` | AnyKernel device check filter |
| `defconfig` | kona-perf (default) or kona |
| `ksun_ref` | KernelSU-Next ref (default `next`) |
| `susfs_ref` | SUSFS ref (default `kernel-4.19`) |
| `make_release` | Publish a GitHub Release |

Artifacts appear on the run page (and as a release if enabled).

### Recommended branches

| Device + ROM | Branch |
|--------------|--------|
| OP8T on OOS 14 | `oneplus/sm8250_u_14.0.0_op8t` |
| OP9R on OOS 14 | `oneplus/sm8250_u_14.0.0_op9r` |
| OP8 / 8 Pro on OOS 13.1 | `oneplus/sm8250_t_13.1_op8` |
| OP9R on OOS 13.1 | `oneplus/sm8250_t_13.1_op9r` |

Full map: [`configs/registry.json`](configs/registry.json) and [`compatibility.md`](compatibility.md).

---

## Local build (optional)

```bash
# Linux host with clang + aarch64/arm android GCC on PATH
export KERNEL_BRANCH=oneplus/sm8250_u_14.0.0_op8t
export BUILD_MODE=KSUN_SUSFS   # or STOCK | KSUN
export DEVICE_PROFILE=OP8T
chmod +x scripts/*.sh
bash scripts/build.sh
# output: artifacts/*.zip
```

---

## Flash / safety

- Unlock bootloader (data wipe).
- Match **kernel branch ↔ stock OOS Android version**.
- Keep a stock `boot` backup (MSM/EDL if needed).
- Flash AnyKernel3 zip via recovery / Kernel Flasher.
- After major OTA, re-flash a matching build.
- **You** are responsible for bricked devices — research before flashing.

For KSUN_SUSFS: install a SUSFS userspace module (e.g. [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module)) after root works.

---

## Repo layout

```
configs/registry.json     # branches, devices, modes
scripts/build.sh          # orchestrator
scripts/apply-ksun.sh
scripts/apply-susfs.sh
scripts/add-manual-hooks.sh
scripts/package-anykernel.sh
.github/workflows/build-kernel.yml
docs/reports/             # feasibility research
```

---

## Credits

- [OnePlusOSS](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250)
- [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)
- [KernelSU](https://github.com/tiann/KernelSU)
- [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
- [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module)
- [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3)
- Community non-GKI OP8 builders (reference integration patterns)

---

## Docs

- [compatibility.md](compatibility.md)
- [SM8250 KSUN/SUSFS feasibility report](docs/reports/sm8250-ksun-susfs-build-feasibility-report.md)
