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
| `ONEPLUSOSS_OP8_OOS13_1` | [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) | `oneplus/sm8250_t_13.1_op8` | `vendor/kona-perf_defconfig` | OP8 on OOS 13.1 |
| `ONEPLUSOSS_OP9R_OOS13_1` | [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) | `oneplus/sm8250_t_13.1_op9r` | `vendor/kona-perf_defconfig` | OP9R on OOS 13.1 |
| `ONEPLUSOSS_OP8T_OOS14` | [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) | `oneplus/sm8250_u_14.0.0_op8t` | `vendor/kona-perf_defconfig` | OP8T on OOS 14 |
| `ONEPLUSOSS_OP9R_OOS14` | [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) | `oneplus/sm8250_u_14.0.0_op9r` | `vendor/kona-perf_defconfig` | OP9R on OOS 14 |

Community-source `STOCK` builds remain clean upstream builds. Official `ONEPLUSOSS_*` STOCK builds apply the audited `oneplusoss-sm8250-strict-prototypes` compatibility set. It corrects two invalid function signatures, removes an unnecessary `__packed` function return-type annotation that prevents `genksyms` from generating one symbol version, and places RTIC data inside the existing BSS output section as intended. Their artifacts are therefore stock-derived, not byte-for-byte upstream. The selected defconfig remains unchanged. `KSUN` and `KSUN_SUSFS` add only the requested KernelSU-Next and SUSFS integrations.

The official `ONEPLUSOSS_*` presets compose both matching OnePlus repositories: the kernel tree and `android_kernel_modules_and_devicetree_oneplus_sm8250`. The latter supplies the `vendor/` and `techpack/` targets referenced by the kernel tree's symlinks. The builder applies its declared compatibility patches with `git apply --check --ignore-space-change` to handle OnePlus's mixed line endings, while signature context still fails if target code changes. Before configuration, it also exports the scalar values published by the selected branch's `oplus_native_features.mk`, matching the feature environment used by OnePlus's Android build.

Those presets also follow the published OnePlus build configuration: Android Clang `r399163b` (11.0.5), `LLVM=1`, and the matching `aarch64-linux-gnu` / `arm-linux-gnueabi` GNU assembler tools. Community presets retain their existing ZyC Clang profile.

Match the selected source and branch to your installed stock OOS generation. Not every branch boots every ROM.

This git branch is **not** for OP10+ GKI devices. Upstream multi-device WildKernels GKI pipeline lives on **`main`** (reference only; do not develop OP8 features there).

---

## Features

| Mode | What you get |
|------|----------------|
| **STOCK** | Non-root baseline (no KernelSU / no SUSFS); official presets may declare an audited compatibility patch |
| **KSUN** | [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) built-in (non-GKI 4.19) |
| **KSUN_SUSFS** | KSUN + [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) (`kernel-4.19`) |

- The verified OP8 request pins KernelSU-Next `53791c92bff13d62338f29cc9da035a37652ca91`
  (`v3.2.0-legacy-13-g53791c92`) and official SUSFS 4.19
  `001e69919c6271f690fd00b17e4c721c9e599152` (`v1.5.5`).
- Flashable **AnyKernel3** ZIP, using WildKernels framework commit
  `e1e9dce98430c5c6f231f7094a8c7f4ecaf50948` plus a repo-owned,
  OP8-only non-GKI installer.
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
  -f build_mode=KSUN_SUSFS \
  -f device_profile=OP8 \
  -f source_preset=ONEPLUSOSS_OP8_OOS13_1 \
  -f kernel_branch=oneplus/sm8250_t_13.1_op8 \
  -f ksun_ref=53791c92bff13d62338f29cc9da035a37652ca91 \
  -f susfs_ref=001e69919c6271f690fd00b17e4c721c9e599152 \
  -f make_release=false \
  -f clean_build=true \
  -f debug=true
```

| Input | Purpose |
|-------|---------|
| `build_mode` | `STOCK` / `KSUN` / `KSUN_SUSFS` |
| `device_profile` | AnyKernel device check filter |
| `source_preset` | `HELLBOY017` / `PPAJDA` / `TORAIDL` / exact-device `ONEPLUSOSS_*` OOS preset |
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

### Kernel changes and boot risk

| Change | Kernel-level effect | Main risk | Current evidence |
|--------|---------------------|-----------|------------------|
| OnePlus compatibility set | Repairs invalid prototypes, GSI symbol generation, and RTIC BSS placement without changing the defconfig | Low, but still changes compiled source | Clean STOCK CI baseline passed |
| KernelSU-Next manual hooks | Hooks exec/open/read/stat, input safe mode, reboot supercall, and the 4.19 unmount path | Medium; a wrong hook placement can panic or break early userspace | Exact-tree compile and link passed locally |
| SUSFS v1.5.5 | Changes VFS, mount namespace, proc/fdinfo, stat, uname, and task state paths | Medium to high; OEM-port mistakes can cause boot or runtime faults | Rebased patch applies cleanly; SUSFS and final Image link passed locally |
| Current-KSU/SUSFS bridge | Connects the official SUSFS 4.19 ABI to the current KernelSU-Next layout | Medium; ABI mismatch can break root/SUSFS behavior | Contract tests and exact-tree compile/link passed locally |
| OP8 AnyKernel installer | Replaces the active-slot `boot` kernel only for `instantnoodle` | High if flashed on the wrong ROM/device or without a backup | ZIP validator passed; no physical-device flash test yet |

Build success proves compilation and package structure, **not** boot safety. Keep a
known-good stock `boot.img`, verify the installed ROM is OP8 OOS 13.1-compatible,
and test with a recoverable flashing method. The KernelSU input safe-mode hook is
included, but it cannot recover every early boot failure.

---

## Repo layout (this branch)

```
configs/sources.json          # selectable source and compatibility metadata
patches/                      # audited source-specific compatibility repairs
configs/build-request.json    # push-triggered build request
configs/registry.json         # devices + known HELLBOY branches
scripts/build.sh              # orchestrator
scripts/apply-ksun.sh
scripts/apply-susfs.sh
scripts/add-manual-hooks.sh
scripts/package-anykernel.sh
scripts/verify-anykernel.sh
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
| **`op8series-sm8250-ksu-susfs`** | **Active development** — OP8 series source-aware builds |
| **`main`** | **Reference only** — upstream GKI / multi-device pipeline. Do not commit OP8 changes there; copy patterns when needed. |

---

## Credits

- [HELLBOY017/kernel_oneplus_sm8250](https://github.com/HELLBOY017/kernel_oneplus_sm8250) (Meteoric / CLO)
- [ppajda/android_kernel_oneplus_sm8250](https://github.com/ppajda/android_kernel_oneplus_sm8250)
- [toraidl/android_kernel_oneplus_sm8250](https://github.com/toraidl/android_kernel_oneplus_sm8250)
- [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250)
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
