# OnePlus 8 Series Kernel Builder (SM8250)

Branch: **`op8series-sm8250-ksu-susfs`**

Build **STOCK**, **KernelSU-Next**, or **KernelSU-Next + SUSFS** kernels for the OP8 series on **SM8250 / kona** (Linux **4.19**, non-GKI).

| Device | SoC | Codenames |
|--------|-----|-----------|
| OnePlus 8 | SM8250 | `instantnoodle` |
| OnePlus 8 Pro | SM8250 | `instantnoodlep` |
| OnePlus 8T | SM8250 | `kebab` |
| OnePlus 9R | SM8250-AC (SD870) | `lemonades` |

### Kernel source (only)

| Field | Value |
|-------|--------|
| **Repo** | [HELLBOY017/kernel_oneplus_sm8250](https://github.com/HELLBOY017/kernel_oneplus_sm8250) |
| **Default HELLBOY branch** | `14` (Android 14–class) |
| **Also selectable** | `13.1`, `13.1-new` (Android 13.1–class) |
| **Default defconfig** | `vendor/oplus-stock_defconfig` |

No LineageOS / OnePlusOSS / other trees — this git branch is **HELLBOY-only**.

Match **HELLBOY branch ≈ your stock OOS generation** (`14` for OOS14-class, `13.1` for OOS13.1-class). Not every branch boots every ROM.

This git branch is **not** for OP10+ GKI devices. Upstream multi-device WildKernels GKI pipeline lives on **`main`** (reference only; do not develop OP8 features there).

---

## Features

| Mode | What you get |
|------|----------------|
| **STOCK** | Non-root baseline (no KernelSU / no SUSFS) — verified on HELLBOY `14` |
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
  -f device_profile=ALL_OP8_SERIES \
  -f kernel_branch=14 \
  -f make_release=false \
  -f clean_build=false \
  -f debug=true
```

| Input | Purpose |
|-------|---------|
| `build_mode` | `STOCK` / `KSUN` / `KSUN_SUSFS` |
| `device_profile` | AnyKernel device check filter |
| `kernel_branch` | **`14`** (default, A14) · **`13.1`** · **`13.1-new`** |
| `defconfig_override` | Optional (empty = `vendor/oplus-stock_defconfig`) |
| `ksun_ref` / `susfs_ref` | For root modes |
| `clean_build` | `true` = no ccache |
| `make_release` | Publish a GitHub Release |
| `debug` | Extra logs on failure |

Source defaults: [`configs/sources.json`](configs/sources.json) (HELLBOY017 only).

---

## Local build (optional)

```bash
# Linux host with clang + aarch64/arm android GCC on PATH
export KERNEL_BRANCH=14
export BUILD_MODE=STOCK          # or KSUN | KSUN_SUSFS
export DEVICE_PROFILE=ALL_OP8_SERIES
# optional: KERNEL_SOURCE defaults to HELLBOY017
chmod +x scripts/*.sh
bash scripts/build.sh
# output: artifacts/*.zip
```

---

## Flash / safety

- Unlock bootloader (data wipe).
- Prefer builds matched to your ROM generation; HELLBOY `14` is stock-oriented CLO.
- Keep a stock `boot` backup (MSM/EDL if needed).
- Flash AnyKernel3 zip via recovery / Kernel Flasher.
- After major OTA, re-flash a matching build.
- **You** are responsible for bricked devices — research before flashing.

For **KSUN_SUSFS**: install a SUSFS userspace module (e.g. [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module)) after root works.

---

## Repo layout (this branch)

```
configs/sources.json          # HELLBOY017 only
configs/build-request.json    # push-triggered build request
configs/registry.json         # devices + known HELLBOY branches
scripts/build.sh              # orchestrator
scripts/apply-ksun.sh
scripts/apply-susfs.sh
scripts/add-manual-hooks.sh
scripts/fix-oplus-stubs.sh
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
| **`op8series-sm8250-ksu-susfs`** | **Active development** — OP8 series HELLBOY builds only |
| **`main`** | **Reference only** — upstream GKI / multi-device pipeline. Do not commit OP8 changes there; copy patterns when needed. |

---

## Credits

- [HELLBOY017/kernel_oneplus_sm8250](https://github.com/HELLBOY017/kernel_oneplus_sm8250) (Meteoric / CLO)
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
