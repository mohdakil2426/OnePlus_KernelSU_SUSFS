# OnePlus 8 Series Kernel Builder (SM8250)

Branch: **`op8series-sm8250-ksu-susfs`**

Build **STOCK**, **KernelSU-Next**, or **KernelSU-Next + SUSFS** kernels for the OP8 series on **SM8250 / kona** (Linux **4.19**, non-GKI).

| Device | SoC | Codenames |
|--------|-----|-----------|
| OnePlus 8 | SM8250 | `instantnoodle` |
| OnePlus 8 Pro | SM8250 | `instantnoodlep` |
| OnePlus 8T | SM8250 | `kebab` |
| OnePlus 9R | SM8250-AC (SD870) | `lemonades` |

### Selectable kernel sources

| Preset | Upstream | Default branch | Default defconfig | Intended devices |
|--------|----------|----------------|-------------------|------------------|
| `HELLBOY017` | [HELLBOY017/kernel_oneplus_sm8250](https://github.com/HELLBOY017/kernel_oneplus_sm8250) | `14` | `vendor/oplus-stock_defconfig` | OP8 series |
| `PPAJDA` | [ppajda/android_kernel_oneplus_sm8250](https://github.com/ppajda/android_kernel_oneplus_sm8250) | `oos13.1` | `op8_defconfig` | OP8 / OP8 Pro / OP8T |
| `TORAIDL` | [toraidl/android_kernel_oneplus_sm8250](https://github.com/toraidl/android_kernel_oneplus_sm8250) | `op8t` | `vendor/oplus-stock_defconfig` | OP8T / OP9R |

`STOCK` builds are clean upstream builds: the builder does not patch source files or rewrite the selected defconfig. `KSUN` and `KSUN_SUSFS` only add the requested KernelSU-Next and SUSFS integrations.

Match the selected source and branch to your installed stock OOS generation. Not every branch boots every ROM.

This git branch is **not** for OP10+ GKI devices. Upstream multi-device WildKernels GKI pipeline lives on **`main`** (reference only; do not develop OP8 features there).

---

## Features

| Mode | What you get |
|------|----------------|
| **STOCK** | Non-root clean-upstream baseline (no KernelSU / no SUSFS) — HELLBOY `14` verified |
| **KSUN** | [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) built-in (non-GKI 4.19) |
| **KSUN_SUSFS** | KSUN + [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) (`kernel-4.19`) |

- Flashable **AnyKernel3** ZIP
- **ccache** via GitHub release bucket `ccache-cache` (same pattern as upstream author on `main`, adapted here)
- Manual GitHub Actions control on this branch only

---

## Build (GitHub Actions)

**Manual only** (`workflow_dispatch`). No automatic run on push, PR, or schedule.

### How to run (UI)

GitHub only shows **Run workflow** if a same-named workflow file exists on the **default branch** (`main`). A tiny stub lives on `main` for that; the **real build** is on this branch.

1. Open **Actions** → **Build OP8 Series Kernel (SM8250)**.
2. Click **Run workflow** (right side).
3. **Use workflow from:** select **`op8series-sm8250-ksu-susfs`** (important — not `main`).
4. Set inputs → **Run workflow**.

If you leave **Use workflow from = main**, the stub job exits with instructions (no kernel build).

### CLI (always works)

```bash
gh workflow run "Build OP8 Series Kernel (SM8250)" \
  --ref op8series-sm8250-ksu-susfs \
  -f build_mode=STOCK \
  -f device_profile=OP8 \
  -f source_preset=PPAJDA \
  -f make_release=false \
  -f clean_build=true \
  -f debug=true
```

| Input | Purpose |
|-------|---------|
| `build_mode` | `STOCK` / `KSUN` / `KSUN_SUSFS` |
| `device_profile` | AnyKernel device check filter |
| `source_preset` | `HELLBOY017` / `PPAJDA` / `TORAIDL` |
| `kernel_branch` | Optional override; must be allowed by the selected source (empty = that preset's default) |
| `defconfig_override` | Optional (empty = selected source's default defconfig) |
| `ksun_ref` / `susfs_ref` | For root modes |
| `clean_build` | `true` = no ccache |
| `make_release` | Publish a GitHub Release |
| `debug` | Extra logs on failure |

Source defaults and allowed branches: [`configs/sources.json`](configs/sources.json).

---

## Local build (optional)

```bash
# Linux host with clang + aarch64/arm android GCC on PATH
export KERNEL_SOURCE=https://github.com/ppajda/android_kernel_oneplus_sm8250.git
export KERNEL_BRANCH=oos13.1
export DEFCONFIG=op8_defconfig
export BUILD_MODE=STOCK          # or KSUN | KSUN_SUSFS
export DEVICE_PROFILE=OP8
export SOURCE_PRESET=PPAJDA
chmod +x scripts/*.sh
bash scripts/build.sh
# output: artifacts/*.zip
```

---

## Flash / safety

- Unlock bootloader (data wipe).
- Prefer builds matched to your ROM generation and source/device scope.
- Keep a stock `boot` backup (MSM/EDL if needed).
- Flash AnyKernel3 zip via recovery / Kernel Flasher.
- After major OTA, re-flash a matching build.
- **You** are responsible for bricked devices — research before flashing.

For **KSUN_SUSFS**: install a SUSFS userspace module (e.g. [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module)) after root works.

---

## Repo layout (this branch)

```
configs/sources.json          # selectable clean upstream source presets
configs/build-request.json    # push-triggered build request
configs/registry.json         # devices + known HELLBOY branches
scripts/build.sh              # orchestrator
scripts/apply-ksun.sh
scripts/apply-susfs.sh
scripts/add-manual-hooks.sh
scripts/package-anykernel.sh
.github/workflows/build-kernel.yml
.github/actions/cache/        # ccache restore/save (author pattern from main)
```

**Outside this GitHub repo** (parent `OnePlus/` root — local only):

```
../docs/reports/              # research / feasibility notes
../memory-bank/               # project memory (agents); not published in git
```

---

## Branch policy

| Branch | Role |
|--------|------|
| **`op8series-sm8250-ksu-susfs`** | **Active development** — OP8 series clean-source builds |
| **`main`** | **Reference only** — upstream GKI / multi-device pipeline. Do not commit OP8 changes there; copy patterns when needed. |

---

## Credits

- [HELLBOY017/kernel_oneplus_sm8250](https://github.com/HELLBOY017/kernel_oneplus_sm8250) (Meteoric / CLO)
- [ppajda/android_kernel_oneplus_sm8250](https://github.com/ppajda/android_kernel_oneplus_sm8250)
- [toraidl/android_kernel_oneplus_sm8250](https://github.com/toraidl/android_kernel_oneplus_sm8250)
- [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)
- [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)
- [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module)
- [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3)
- Upstream WildKernels-style CI patterns (ccache release cache) referenced from `main`

---

## Docs

- [compatibility.md](compatibility.md) (in repo)
- [Community sources research](../docs/reports/sm8250-community-kernel-sources-research.md) (parent `docs/`)
- [SM8250 KSUN/SUSFS feasibility](../docs/reports/sm8250-ksun-susfs-build-feasibility-report.md) (parent `docs/`)
- Project memory: `../memory-bank/` (local, not in git)
