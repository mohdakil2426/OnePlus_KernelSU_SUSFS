# Research Report: OnePlusOSS SM8250 Kernel Buildability, Branch Coverage, and KSUN + SUSFS Support

| Field | Value |
|--------|--------|
| **Title** | Feasibility of building **only** `android_kernel_oneplus_sm8250` with full branch control, KSUN, SUSFS, and stock baseline |
| **Repo context** | Local: `OnePlus_KernelSU_SUSFS` (branch `android_kernel_oneplus_sm8250`) — currently a WildKernels-style GKI/kernel_platform pipeline |
| **Target kernel tree** | [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) |
| **Report date** | 2026-07-24 |
| **Scope** | Research + recommendations only (no pipeline implementation in this change) |
| **Research method** | Live GitHub/GitLab APIs, official docs, local pipeline analysis, parallel research subagents |

---

## 1. Executive summary

### Short answers

| Question | Answer |
|----------|--------|
| Can we restrict this branch to **only** build `android_kernel_oneplus_sm8250`? | **Yes**, as a product goal — but **not** by reusing the current WildKernels GKI Actions path as-is. Needs a **legacy monolithic** build mode. |
| Can we build **all** OSS branches of that kernel? | **In principle yes** (10 branches exist). In practice: each branch is device/Android-version specific; some trees may miss DT/vendor pieces; toolchain and defconfig differ from GKI. |
| Will **KernelSU-Next (KSUN) + SUSFS** work on this kernel? | **Yes in principle and proven in community** for SM8250 / Linux **4.19** non-GKI. Official KSUN supports 4.4–6.6 non-GKI; SUSFS has a dedicated **`kernel-4.19`** branch. Expect **manual patch rejects** and non-GKI SUSFS docs oriented around classic KernelSU hooks. |
| Can Actions get a **manual dropdown** for: every branch × KSUN × SUSFS × stock non-root? | **Yes, after redesign**. Today’s `workflow_dispatch` does **not** expose per-branch sm8250 control, SUSFS toggle, or stock baseline. GitHub “choice” dropdowns are static YAML lists (or dynamic matrix from an API job). |
| Does **this repo’s current CI** already support sm8250? | **No.** Pipeline assumes `kernel_platform/common`, `gki_defconfig`, GKI SUSFS keys (`android12-5.10` … `android16-6.12`). sm8250 is **explicitly blacklisted** in the OnePlusOSS monitor workflow as legacy. |

### Bottom-line verdict

```
┌─────────────────────────────────────────────────────────────────────────┐
│  KSUN + SUSFS on SM8250/4.19:  FEASIBLE (official + community proven)  │
│  Build ALL OSS branches:       FEASIBLE with effort & caveats          │
│  Use current WildKernels CI:   NOT FIT (GKI-only architecture)         │
│  Full control dropdowns:       REQUIRES new workflow + action modes    │
│  Stock non-root baseline:      REQUIRES new ksu_type=NONE path         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Recommended architecture later (not implemented here):** keep or fork this repo, but add a **parallel legacy pipeline** (`build-sm8250-monolithic`) instead of forcing sm8250 into the existing GKI matrix.

---

## 2. Goals (what you asked for)

You want this git branch focused so that:

1. **Only** kernels from  
   `https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250`  
   are built (no OP10–OP15 GKI matrix).
2. **Manual GitHub Actions** UI with full control:
   - **All source branches** of that OSS repo (dropdown)
   - **KSUN** selectable
   - **SUSFS** on/off (or integrated path)
   - **Non-root baseline** (stock-like kernel without KSU)
3. Confirmation whether that tree **can be patched** with KSUN + SUSFS.
4. Full research first; **only** deliver this report under `docs/reports/`.

---

## 3. Target kernel repository analysis

### 3.1 Metadata

| Field | Value | Source |
|--------|--------|--------|
| Full name | `OnePlusOSS/android_kernel_oneplus_sm8250` | [GitHub repo](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) |
| Default branch | `oneplus/SM8250_Q_10.0` | GitHub API |
| Language | C | GitHub API |
| Approx. size | ~1.9 GB | GitHub API |
| Last push | 2024-06-28 | GitHub API |
| Style | **Monolithic pre-GKI** Qualcomm tree (Linux **4.19.x**) | Makefile + tree layout |

### 3.2 Complete branch inventory (all 10)

Verified via  
`https://api.github.com/repos/OnePlusOSS/android_kernel_oneplus_sm8250/branches?per_page=100`

| # | Branch | Android / OOS | Kernel (`Makefile`) | Primary devices (from branch name + tip commits) | Tip activity (approx.) |
|---|--------|---------------|---------------------|--------------------------------------------------|-------------------------|
| 1 | `oneplus/SM8250_Q_10.0` **(default)** | Android 10 / OOS 10 | **4.19.81** | OnePlus 8, 8 Pro | 2020 |
| 2 | `oneplus/SM8250_R_11.0` | Android 11 / OOS 11 | **4.19.110** | OP8, 8 Pro, 8T | 2022 |
| 3 | `oneplus/SM8250_R_11.0_9R` | Android 11 | **4.19.125** | OnePlus **9R** | 2021 |
| 4 | `oneplus/sm8250_s_12.1` | Android 12 / OOS 12 | **4.19.157** | OP8 series | 2022 |
| 5 | `oneplus/sm8250_t_13.0.0_op8` | Android 13 / OOS 13.0 | **4.19.157** | OP8, 8 Pro, 8T | 2023 |
| 6 | `oneplus/sm8250_t_13.0.0_op9r` | Android 13 | **4.19.157** | OP9R | 2022 |
| 7 | `oneplus/sm8250_t_13.1_op8` | Android 13.1 | **4.19.157** | OP8 | 2024-06 (newest tip) |
| 8 | `oneplus/sm8250_t_13.1_op9r` | Android 13.1 | **4.19.157** | OP9R | 2023 |
| 9 | `oneplus/sm8250_u_14.0.0_op8t` | Android 14 / OOS 14 | **4.19.157** | **OP8T** | 2024-06 |
| 10 | `oneplus/sm8250_u_14.0.0_op9r` | Android 14 / OOS 14 | **4.19.157** | **OP9R** | 2024-05 |

**Naming pattern:**  
`oneplus/sm8250_<android_letter>_<version>[_device]`  
Letters: **Q**=10, **R**=11, **S**=12, **T**=13, **U**=14.

### 3.3 Devices this tree is for

| Device | SoC | Common codename | Typical models |
|--------|-----|-----------------|----------------|
| OnePlus 8 | SM8250 (SD 865) | `instantnoodle` | IN201x |
| OnePlus 8 Pro | SM8250 | `instantnoodlep` | IN202x |
| OnePlus 8T | SM8250 | `kebab` | KB200x |
| OnePlus 9R | SM8250-AC (SD 870) | `lemonade` / LE210x | LE210x |

**Not this repo:** OnePlus 9 / 9 Pro (SM8350), OnePlus 7 series (SM8150), OP10+ GKI devices.

### 3.4 Tree structure vs modern OnePlusOSS

| Aspect | sm8250 (this target) | Modern WildKernels path (OP10+) |
|--------|----------------------|----------------------------------|
| Layout | Single monolithic kernel | `kernel_platform/common` + modules/DT repo |
| Kernel | Linux **4.19.x** | GKI **5.10 / 5.15 / 6.1 / 6.6 / 6.12** |
| Defconfig | `arch/arm64/configs/vendor/kona*_defconfig` | `gki_defconfig` + fragments |
| Sync | `git clone` one repo (plus missing vendor/DT often) | `repo`/tarball multi-project manifests |
| GKI / LKM | **No** | Yes (LKM on GKI 2.0) |
| Packaging | Often `Image.gz-dtb` / boot.img + DTBO | AnyKernel3 with `Image` for GKI |

**Primary defconfigs for OP8-class:**  
`vendor/kona_defconfig`, `vendor/kona-perf_defconfig`  
(Also present: lito/bengal/etc. from shared CAF base — not OP8 primary.)

### 3.5 Completeness / build risk of OSS dumps

Community and tree structure show:

- Full kernel sources are present (`arch`, `drivers`, `techpack`, `AndroidKernel.mk`, …).
- Some paths historically use **gitlinks / external vendor DT** (`arch/arm64/boot/dts/vendor`, some Oplus modules).
- A pure clone **may not** always produce a 1:1 stock boot image without extra trees, toolchain, or DTB packing steps.
- **Default branch is Android 10** — stale for modern OOS; prefer **T 13.1** / **U 14** device branches for current stock ROMs.

**Implication:** “Build all branches” is valid as CI matrix design, but **bootability must be validated per branch + device + ROM**.

---

## 4. KSUN + SUSFS support research

### 4.1 KernelSU-Next (KSUN)

**Official stance (KernelSU Next homepage + README):**

- Supports kernels **4.4 – 6.6** for **Non-GKI & GKI**.
- Non-GKI **4.x – 5.4**: **LTS / built-in driver** mode (not prebuilt GKI boot.img).
- Non-GKI integrate guide:  
  [How to integrate for non-GKI](https://kernelsu-next.github.io/webpage/pages/how-to-integrate-for-non-gki.html)

| Mode | SM8250 relevance |
|------|------------------|
| GKI LKM | **Not applicable** (not GKI 2.0) |
| Built-in driver (`CONFIG_KSU`) | **Required** |
| kprobe hooks | Preferred if `CONFIG_KPROBES` works |
| Manual hooks (`exec`/`open`/`read`/`stat`/reboot) | Fallback if kprobe broken |

Sources:

- https://kernelsu-next.github.io/webpage/
- https://github.com/KernelSU-Next/KernelSU-Next
- https://kernelsu-next.github.io/webpage/pages/how-to-integrate-for-non-gki.html

### 4.2 Original KernelSU (tiann) — contrast

- Since **v1.0**, official **non-GKI support dropped**.
- Last non-GKI pin: **v0.9.5** (archival docs).
- For modern root on 4.19, **KSUN (or other forks)** is the practical choice — not latest tiann GKI-only path.

Source: https://kernelsu.org/guide/how-to-integrate-for-non-gki.html

### 4.3 SUSFS (`susfs4ksu`)

**GitLab:** https://gitlab.com/simonpunk/susfs4ksu

Relevant branches (API-verified):

| Class | Branches |
|-------|----------|
| **Non-GKI** | `kernel-4.9`, `kernel-4.14`, **`kernel-4.19`**, `kernel-5.4` |
| **GKI** | `gki-android12-5.10` … `gki-android16-6.12` (+ `-dev`) |

**For sm8250 you must use non-GKI `kernel-4.19`**, **not** the GKI SUSFS branches that WildKernels currently resolves (`gki-android12-5.10`, etc.).

From [kernel-4.19 README](https://gitlab.com/simonpunk/susfs4ksu/-/raw/kernel-4.19/README.md):

- Experimental; can hurt stability/performance.
- Patches **differ by kernel version**; **manual reject fixing is expected**.
- Non-GKI docs still describe base as **original KernelSU (tiann)** + specific revert + **manual NON-KPROBE hooks**.
- **`SUS_SU` not supported for NON-GKI** (deprecated path).
- Force-disable kprobe use inside KernelSU for SUSFS non-GKI flow (`CONFIG_KPROBES && 0` pattern in docs).
- Enable `CONFIG_KSU` + `CONFIG_KSU_SUSFS` (+ feature flags; Magic Mount → `KSU_SUSFS_HAS_MAGIC_MOUNT`).
- Known issue: missing `android_kabi_reserved*` members on ≤4.19 — may need manual struct appends.
- Userspace: `ksu_susfs` tool + module ([sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module)) only works on a **SUSFS-patched kernel**.

**KSUN + SUSFS combo:** Official non-GKI SUSFS write-up is KernelSU-classic-centric; community still pairs SUSFS with **KSUN** on 4.19, but **expect adaptation** (manager hash, Magic Mount flags, hook model).

### 4.4 Community proof (SM8250 / OP8 class)

WildKernels **does not** ship OP8/sm8250. Community does:

| Evidence | Relevance |
|----------|-----------|
| Anomaly-Kernel (XDA) for OP8/8T/8Pro — KSUN + SUSFS | Real devices on 4.19 |
| Builders like oneplus8-kernelsu-susfs (GitHub Actions/Docker) | Automated KSUN/SUSFS on sm8250 trees |
| Stellaris / unofficial KernelSU device lists (sm8250) | Historical non-GKI KSU |
| XDA “compile KSUN+SUSFS non-GKI 4.19” threads | Confirms feasibility + pain of rejects |

**Conclusion:** Patching is **supported and proven**, not theoretical — but it is a **custom-kernel project**, not a GKI zip flash.

### 4.5 Feature feasibility matrix for this tree

| Feature | Supported? | Notes |
|---------|------------|--------|
| Stock non-root baseline | Yes | Compile without KSU/SUSFS; still custom-built if tree/defconfig differ from OEM |
| KSUN only | Yes | Built-in driver; kprobe or manual hooks |
| KSUN + SUSFS | Yes, high effort | Use `susfs4ksu` **`kernel-4.19`**; fix rejects; userspace module after flash |
| Original KernelSU latest | No (official non-GKI) | Cap at v0.9.5 or use KSUN |
| LKM install (no rebuild) | No | Non-GKI |
| WildKernels GKI feature pack (BBG, HMBIRD, ntsync GKI patches, …) | Mostly N/A / separate | Those patches assume GKI trees; don’t assume drop-in on 4.19 |

---

## 5. Current local project pipeline (why sm8250 does not fit today)

Analysis of:

- `.github/workflows/build-kernel-release.yml`
- `.github/actions/build-kernel/action.yml`
- `.github/actions/kernel-source-sync/action.yml`
- `configs/{a14,a15,a16}/**`, `manifests/{a14,a15,a16}/**`

### 5.1 What manual Actions expose today

| Input | Purpose |
|-------|---------|
| `op_model` | Filters **all** device JSONs by OS/GKI bucket (`A14`…`A16`, `android12-5.10`…) — **not** sm8250 branches |
| `ksu_options` | JSON list of KSUN/KSU + hash — **always root variants** |
| SUSFS branch overrides | Only for **GKI keys** `android12-5.10` … `android16-6.12` |
| Optimize / clean / debug / timestamp | Shared build knobs |

**Missing for your goal:**

- Dropdown of `oneplus/sm8250_*` branches  
- Device selection limited to OP8/8T/8Pro/9R  
- SUSFS global on/off independent of GKI map  
- **`NONE` / stock non-root** mode  

### 5.2 Device config assumptions

Configs require fields like `model` starting with `OP`, `soc`, `manifest`, `android_version` (`androidN`), `kernel_version` (`X.Y`), feature flags (`susfs`, `bbg`, `opt`, …), and paths into **clang under `kernel_platform/prebuilts/...`**.

There is **no** `OP8*`, `sm8250`, or `kona` config in this repo.

### 5.3 Manifest / sync assumptions

Modern manifests pull:

- Kernel → `kernel_platform/common`
- Modules/DT → separate OnePlusOSS repo
- Clang / build-tools → CodeLinaro prebuilts
- AnyKernel3 → WildKernels

sm8250 is a **single monolithic git tree** — different checkout and make graph.

### 5.4 Hard break points for sm8250

| Stage | Why it breaks on sm8250 |
|-------|-------------------------|
| Matrix | No config; no 4.19 GKI key |
| SUSFS resolve | Only `gki-android*` branches, not `kernel-4.19` |
| Source layout | Expects `kernel_platform/common` |
| Defconfig | Forces `gki_defconfig` |
| Patches | GKI-keyed overlays / ntsync / unicode / BBG / etc. |
| Build product | Collects GKI-style `Image` for AnyKernel3 |
| Toolchain cache | Mapped to modern clang labels; 4.19 often needs older clang |
| Monitor blacklist | `android_kernel_oneplus_sm8250` is **listed in BLACKLIST_REPOS** in `oplus-kernel-monitor.yml` (treated as legacy, not tracked for GKI updates) |

### 5.5 Mental model

```
CURRENT (GKI):
  configs/*.json × ksu_options
       → sync kernel_platform + modules + clang
       → setup KSUN/KSU into gki_defconfig
       → gki SUSFS patches
       → make Image → AnyKernel3

NEEDED (sm8250 legacy):
  branch + device + mode(KSUN|NONE) + susfs(on|off)
       → git clone OnePlusOSS/... @ branch
       → vendor/kona-perf_defconfig (+ KSU/SUSFS configs)
       → KSUN legacy inject ± SUSFS kernel-4.19 patches
       → make Image / Image.gz-dtb → boot/AnyKernel3 (device-specific)
```

---

## 6. Can “all branches” be built?

### 6.1 Engineering answer

| Claim | Assessment |
|-------|------------|
| All **10** branches exist and are cloneable | **Yes** |
| All are Linux 4.19.x | **Yes** (SUBLEVEL 81 → 157) |
| Same defconfig family (`kona*`) | **Likely yes** across OP8-class; still verify per branch |
| Same toolchain for every branch | **Mostly** (4.19 era clang), but Q/R may need older toolchain than U |
| Every branch boots every SM8250 device | **No** — branches are **device- and Android-version-specific** |
| Every branch produces a working stock baseline without extra trees | **Uncertain** until first successful compile + device boot test |

### 6.2 Branch ↔ device mapping (control matrix suggestion)

| Branch | Prefer for |
|--------|------------|
| `SM8250_Q_10.0` | OP8 / 8 Pro on OOS 10 only (legacy) |
| `SM8250_R_11.0` | OP8 / 8 Pro / 8T OOS 11 |
| `SM8250_R_11.0_9R` | OP9R OOS 11 |
| `sm8250_s_12.1` | OP8 series OOS 12 |
| `sm8250_t_13.0.0_op8` | OP8 / 8 Pro / 8T OOS 13.0 |
| `sm8250_t_13.0.0_op9r` | OP9R OOS 13.0 |
| `sm8250_t_13.1_op8` | OP8 OOS 13.1 (recent tip) |
| `sm8250_t_13.1_op9r` | OP9R OOS 13.1 |
| `sm8250_u_14.0.0_op8t` | **OP8T OOS 14** (primary modern OP8T) |
| `sm8250_u_14.0.0_op9r` | **OP9R OOS 14** |

**Important:** There is **no dedicated `u_14` OP8 (non-T) branch** in OSS — OP8 may stay on 13.1 tree for last official dump while OP8T/9R got U 14 trees. Confirm against your exact model + ROM before flashing.

### 6.3 Practical “full control” product matrix

Recommended modes for later CI:

| Mode ID | Root | SUSFS | Use case |
|---------|------|-------|----------|
| `STOCK` | None | Off | Non-root baseline / debugging pure tree |
| `KSUN` | KernelSU-Next | Off | Root without SUSFS |
| `KSUN_SUSFS` | KernelSU-Next | On (`kernel-4.19`) | Full root + hide stack |

Optional later: classic `KSU` @ `v0.9.5` only if you need original KernelSU for non-GKI — **not required** if KSUN works.

**Cartesian size:**  
10 branches × 3 modes = **30** primary cells (before multi-device packaging variants).  
GitHub free minutes / runner disk matter — prefer **manual single-cell** dispatch, not “build all 30 every time”.

---

## 7. Desired Actions UI (design research, not implementation)

### 7.1 Proposed `workflow_dispatch` inputs

| Input | Type | Options / notes |
|-------|------|-----------------|
| `kernel_branch` | `choice` | All 10 `oneplus/...` branch names (static list; update if OnePlus adds branches) |
| `device_profile` | `choice` | `OP8`, `OP8Pro`, `OP8T`, `OP9R`, `auto-from-branch` |
| `build_mode` | `choice` | `STOCK`, `KSUN`, `KSUN_SUSFS` |
| `ksun_ref` | string | Branch/tag/hash (default `dev` or stable tag) |
| `susfs_ref` | string | Default empty → pin to `kernel-4.19` tag/commit |
| `defconfig` | `choice` | `vendor/kona-perf_defconfig`, `vendor/kona_defconfig` |
| `optimize_level` | `choice` | `O2` / `O3` |
| `make_release` | boolean | Upload artifacts / GH release |
| `clean_build` | boolean | No ccache |

### 7.2 GitHub Actions limitation (dropdowns)

- `type: choice` options are **static** in YAML.
- True dynamic “list all remote branches live in the UI” is **not** native.
- Workarounds:
  1. Maintain static list of 10 branches (recommended — list is small and stable since mid-2024).
  2. Or free-text `branch` + job validates against API.
  3. Or job1 queries API → matrix (UI still won’t show a live dropdown of remote state).

### 7.3 What must be built (implementation phases — future work)

1. **Sync:** clone only `OnePlusOSS/android_kernel_oneplus_sm8250` @ selected branch.  
2. **Toolchain:** pin known-good clang for 4.19 (document version after first green build).  
3. **STOCK path:** defconfig → make → package.  
4. **KSUN path:** KSUN legacy setup + config symbols.  
5. **SUSFS path:** apply `kernel-4.19` patches; fail soft with artifact of `.rej` files.  
6. **Package:** AnyKernel3 or boot.img path for OP8-class (may differ from GKI AnyKernel).  
7. **Strip GKI-only** jobs/configs from this branch if goal is “sm8250 only”.

---

## 8. Risks and constraints

| Risk | Severity | Mitigation |
|------|----------|------------|
| Incomplete OSS (DT/vendor/Oplus) | High | Test compile early; may need Lineage/third-party DT or community trees |
| Wrong branch for device/ROM | High | Strict branch↔device table; refuse flash without match |
| SUSFS patch rejects on OEM 4.19 | High | Budget manual porting; pin SUSFS tag; save reject artifacts |
| KSUN vs SUSFS non-GKI docs mismatch | Medium | Validate KSUN manager + `KSU_SUSFS_HAS_MAGIC_MOUNT` |
| Bootloop / AVB | High | Unlocked BL; disable verity when needed; keep stock boot backup |
| OTA overwrites custom kernel | Medium | Re-flash after OTA; no guarantee of OTA survival |
| Non-GKI SUSFS feature lag vs GKI SUSFS | Medium | Don’t expect latest GKI-only SUSFS features |
| Runner resources (full 4.19 tree) | Medium | ccache; single-branch jobs; disk cleanup |
| Confusing this fork with WildKernels GKI releases | Low | Clear README when productizing |

---

## 9. Comparison: keep WildKernels GKI vs specialize for sm8250

| Approach | Pros | Cons |
|----------|------|------|
| **A. Specialize this branch for sm8250 only** | Matches your goal; clean UI; no 150-device noise | Large rewrite; diverges from upstream WildKernels |
| **B. New workflow alongside existing GKI** | Keeps OP10+ capability | Branch name vs purpose confusion |
| **C. Separate repo** for sm8250 legacy | Clean product boundary | More maintenance overhead |

Given branch name `android_kernel_oneplus_sm8250` and your stated intent, **Approach A or C** is the cleanest product story.

---

## 10. Success criteria (when you implement later)

1. Manual Action can select **any of the 10** OSS branches.  
2. `STOCK` build produces flashable artifact **without** KSU symbols / SUSFS.  
3. `KSUN` build: manager detects KernelSU-Next; root works.  
4. `KSUN_SUSFS` build: `ksu_susfs` reports features; module installs.  
5. Documented device matrix: which branch for OP8 / 8T / 9R on which OOS.  
6. No residual dependency on `gki_defconfig` or `gki-android*-*` SUSFS branches for this product path.

---

## 11. Final conclusions

1. **`android_kernel_oneplus_sm8250` is a complete, older-style 4.19 monolithic kernel project** for OnePlus **8 / 8 Pro / 8T / 9R**, with **10 branches** covering OOS 10→14.  
2. **All branches can be targeted by a dedicated CI matrix**, but **not all combinations are equal** for a given phone/ROM — branch choice is part of “full control,” not “build everything blindly.”  
3. **KSUN + SUSFS are officially supportable on 4.19 non-GKI** and **already used in OP8-class community kernels**. Use SUSFS **`kernel-4.19`**, not GKI SUSFS lines.  
4. **This repository’s current Actions cannot build sm8250 without a major legacy pipeline** — they are engineered for OnePlusOSS **GKI / kernel_platform** devices (OP10+).  
5. Your desired **manual dropdown control** (all branches, KSUN, SUSFS, stock baseline) is **well-defined and implementable**, but it is a **new workflow + action design**, not a small config JSON add.  
6. **Stock non-root baseline** is the easiest mode once the bare compile path works; add KSUN, then SUSFS incrementally (recommended order).

---

## 12. Sources

### OnePlusOSS / tree

- https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250  
- https://api.github.com/repos/OnePlusOSS/android_kernel_oneplus_sm8250  
- https://api.github.com/repos/OnePlusOSS/android_kernel_oneplus_sm8250/branches?per_page=100  
- Raw Makefiles per branch (e.g.  
  `.../oneplus/SM8250_Q_10.0/Makefile`,  
  `.../oneplus/sm8250_u_14.0.0_op8t/Makefile`)  
- Defconfigs:  
  `arch/arm64/configs/vendor/` on U branch (`kona_defconfig`, `kona-perf_defconfig`)

### KernelSU / KSUN

- https://kernelsu-next.github.io/webpage/  
- https://kernelsu-next.github.io/webpage/pages/how-to-integrate-for-non-gki.html  
- https://github.com/KernelSU-Next/KernelSU-Next  
- https://kernelsu.org/guide/how-to-integrate-for-non-gki.html (original, archival non-GKI)

### SUSFS

- https://gitlab.com/simonpunk/susfs4ksu  
- https://gitlab.com/api/v4/projects/simonpunk%2Fsusfs4ksu/repository/branches  
- https://gitlab.com/simonpunk/susfs4ksu/-/raw/kernel-4.19/README.md  
- https://github.com/sidex15/susfs4ksu-module  

### This project (local)

- `README.md`, `compatibility.md`  
- `.github/workflows/build-kernel-release.yml`  
- `.github/workflows/oplus-kernel-monitor.yml` (blacklist includes `android_kernel_oneplus_sm8250`)  
- `.github/actions/build-kernel/action.yml`  
- `.github/actions/kernel-source-sync/action.yml`  
- `configs/`, `manifests/` (a14/a15/a16 only; no sm8250)

### Community context (secondary)

- WildKernels OnePlus releases / docs (GKI OP10+)  
- Community OP8 KSUN+SUSFS kernels and builders (XDA / GitHub) — existence supports feasibility, not a substitute for first-party OSS build verification  

---

## 13. Appendix A — Kernel version map (verified)

| Branch | VERSION.PATCHLEVEL.SUBLEVEL |
|--------|-----------------------------|
| `oneplus/SM8250_Q_10.0` | 4.19.81 |
| `oneplus/SM8250_R_11.0` | 4.19.110 |
| `oneplus/SM8250_R_11.0_9R` | 4.19.125 |
| `oneplus/sm8250_s_12.1` | 4.19.157 |
| `oneplus/sm8250_t_13.0.0_op8` | 4.19.157 |
| `oneplus/sm8250_t_13.0.0_op9r` | 4.19.157 |
| `oneplus/sm8250_t_13.1_op8` | 4.19.157 |
| `oneplus/sm8250_t_13.1_op9r` | 4.19.157 |
| `oneplus/sm8250_u_14.0.0_op8t` | 4.19.157 |
| `oneplus/sm8250_u_14.0.0_op9r` | 4.19.157 |

## 14. Appendix B — Suggested next steps (when you want implementation)

1. Confirm **your exact device + OOS version** → pick default branch.  
2. Greenlight design: sm8250-only branch **rewrite** vs separate workflow.  
3. Prototype **STOCK** compile for one branch (e.g. `sm8250_u_14.0.0_op8t`).  
4. Add **KSUN**, verify root.  
5. Add **SUSFS `kernel-4.19`**, verify module.  
6. Wire `workflow_dispatch` dropdowns and packaging.  
7. Expand matrix to remaining branches after one golden path.

---

*End of report. No pipeline code, configs, or workflows were modified for this research deliverable.*
