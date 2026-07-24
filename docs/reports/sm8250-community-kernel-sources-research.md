# Research: Community / OSS-compatible SM8250 kernel sources (OP8 / 8 Pro / 8T / 9R)

| Field | Value |
|--------|--------|
| **Date** | 2026-07-25 |
| **Goal** | Find maintained, buildable kernel trees that work for **stock OOS** and/or **LineageOS**, replacing incomplete OnePlusOSS dumps |
| **Devices** | OnePlus 8 (`instantnoodle`), 8 Pro (`instantnoodlep`), 8T (`kebab`), 9R (`lemonades`) — SoC SM8250 / SM8250-AC |
| **Context** | Pure [OnePlusOSS/android_kernel_oneplus_sm8250](https://github.com/OnePlusOSS/android_kernel_oneplus_sm8250) fails CI (broken `vendor/oplus` symlinks) |

---

## 1. Hard truth (before picking a tree)

### 1.1 One kernel rarely “does stock + LineageOS perfectly”

Community practice and independent writeups agree:

- **Kernel source must match the ROM class you boot.**
- A pure **LineageOS** kernel often **will not boot stock OxygenOS** (and vice versa): different userspace, props, modules expectations, occasionally panic early.
- “Supports both OOS and AOSP” usually means:
  - **CLO / unified** tree with **different defconfigs / branches**, or  
  - maintainers ship **separate builds**, not one zip for every ROM.

**Implication for this project:**  
Design **two source profiles** (or two branches of the builder), not one magic tree:

| Profile | ROM target | Source family |
|---------|------------|----------------|
| `STOCK_OOS` | OxygenOS / ColorOS stock-class | CLO / Meteoric / Realking opkona-class |
| `LINEAGE` | LineageOS / crDroid / AOSP custom | LineageOS kernel (and forks) |

### 1.2 Why OnePlusOSS is the wrong default

| Issue | Detail |
|--------|--------|
| Incomplete GPL dump | Hundreds of **broken symlinks** → `vendor/oplus/...` (not published) |
| Fail modes we hit | Missing `sched_assist` Kconfig, `block/blk`, headers like `sched_assist_locking.h` |
| Maintenance | Last device branch tips ~mid-2024; not a “build and flash” product |

Community builders for OP8 KSUN **do not** use raw OnePlusOSS as default.

---

## 2. Ranked kernel sources (research results)

### Tier A — Recommended

#### A1. LineageOS official (best for **LineageOS**)

| | |
|--|--|
| **Repo** | https://github.com/LineageOS/android_kernel_oneplus_sm8250 |
| **Default branch** | `lineage-23.2` (also `lineage-23.1`, `23.0`, `22.2` … `18.1`) |
| **Last push (API)** | 2026-05-30 |
| **Stars / forks** | ~84 / ~160 |
| **Tree quality** | **Complete, buildable** — community’s standard for custom ROMs |
| **Stock OOS** | **Not the right primary target** (may not boot stock) |
| **LineageOS** | **Yes — primary** |
| **KSUN/SUSFS** | Not pre-integrated; add via our scripts (or use a fork below) |
| **Used by** | [AzusaHana/KernelSU_Build_Test](https://github.com/AzusaHana/KernelSU_Build_Test) (LOS 23.2 AK3 CI for OP8/8P/8T/9R) |

**Verdict:** Default source for **LINEAGE** profile.

---

#### A2. HELLBOY017 Meteoric / CLO (best known **stock-oriented buildable** tree)

| | |
|--|--|
| **Repo** | https://github.com/HELLBOY017/kernel_oneplus_sm8250 |
| **Description** | “Just another CLO based kernel for OnePlus SM8250 devices” |
| **Important branches** | `oos` (OOS-focused, older), `14`, `13.1`, `meteoric-LOS`, `clo`, `aosp`, … |
| **Last push (API)** | 2024-09-01 on default `14` |
| **Stars / forks** | ~81 / ~56 |
| **Tree quality** | **Much more complete than OnePlusOSS** — e.g. `kernel/sched_assist` is a **real directory** on `oos` (not a dead vendor link) |
| **Stock OOS** | **Intended** (especially `oos` / newer CLO `14`) — community default for OP8 KSUN builders |
| **LineageOS** | Partial / secondary (`meteoric-LOS` exists but stale ~2022) |
| **KSUN/SUSFS** | Not always pre-merged; **builders apply on top** |
| **Used by** | [larrypaul93/oneplus8-kernelsu-susfs](https://github.com/larrypaul93/oneplus8-kernelsu-susfs) / zee295 clone — **default** `kernel_source = HELLBOY017/kernel_oneplus_sm8250`, branch `thirteen` in README (map to existing branch names carefully; `13.1` / `14` exist) |

**Verdict:** Strong default for **STOCK_OOS** profile in our Actions builder.  
**Caveat:** Less “daily commit” activity than LineageOS; still the most referenced **complete** OP8 stock-class OSS tree for KSUN automation.

---

#### A3. Realking (claims **both OOS + AOSP**, actively pushed)

| | |
|--|--|
| **Repo** | https://github.com/Rohail33/Realking_kernel_sm8250 |
| **Description** | Kona SM8250 — Xiaomi devices + **OnePlus 8 series & 9R (`opkona`) for both OOS and AOSP** |
| **Stars / forks** | ~123 / ~86 |
| **Branches** | `main`, `opkona`, `op-staging`, `op-rebase`, `susfs+bb`, Xiaomi branches, … |
| **Activity** | `op-staging` tip **2026-07-24**; `susfs+bb` 2025-11; `opkona` tip ~2024-09 |
| **Extras in tree** | `KernelSU/`, `anykernel/`, CI (`.drone.yml`) — product-like |
| **Stock OOS** | **Claimed** (opkona family) |
| **Lineage / AOSP** | **Claimed** (same family, AOSP ROMs) |
| **KSUN/SUSFS** | `susfs+bb` branch title: “ksun-susfs & baseband Guard” |

**Verdict:** Best **single-project** candidate if you want **one maintained multi-ROM kona tree** with OP8 support and SUSFS interest.  
**Caveat:** OP-specific branch `opkona` is older than `main`/`op-staging`; verify boot on **your** OOS version and LOS version before locking defaults. Still far better starting point than OnePlusOSS.

---

### Tier B — Good forks / specialized

#### B1. wagamy — Lineage 23.2 + KSUN + SUSFS already integrated

| | |
|--|--|
| **Repo** | https://github.com/wagamy/android_kernel_oneplus_sm8250 |
| **Parent** | LineageOS/android_kernel_oneplus_sm8250 |
| **Branches** | `lineage-23.2`, **`ksun-susfs`** |
| **Last push** | 2026-06-28 |
| **Desc** | “Working implementation of KernelSU-Next v3.1.0 & SUSFS v2.1.0 for OP8 Series & 9R” |
| **Stock OOS** | No (LOS-based) |
| **LineageOS** | Yes |
| **KSUN/SUSFS** | **Pre-applied** |

**Verdict:** Fast path for **LINEAGE + KSUN_SUSFS** without re-deriving patches.

---

#### B2. AzusaHana CI (source = pure LineageOS)

| | |
|--|--|
| **Repo** | https://github.com/AzusaHana/KernelSU_Build_Test |
| **Source** | Official LineageOS SM8250 tree |
| **Devices** | OP8 / 8 Pro / 8T / 9R |
| **Stock OOS** | No |
| **LineageOS** | Yes (docs: LOS 23.2) |

**Verdict:** Reference for **how** to CI-build KSU on LOS SM8250; not a kernel tree itself.

---

#### B3. LenseTech — LOS 23.2 + KSUN (9R-focused)

| | |
|--|--|
| **Repo** | https://github.com/LenseTech/android_kernel_oneplus_sm8250-lineage-23.2_KernelSU-Next |
| **Push** | 2026-05-22 |
| **Target** | OnePlus 9R LineageOS 23.2 + KernelSU Next |

**Verdict:** Useful if device is **9R + LOS**; narrower than full OP8 series.

---

#### B4. Hotsteel2901 — LOS 23.2 + ReSukiSU + Droidspaces

| | |
|--|--|
| **Repo** | https://github.com/Hotsteel2901/op8_sm8250_lineage23_resukisu_droidspaces |
| **Push** | 2026-06-12 |
| **Stack** | LineageOS 23.2 + ReSukiSU + Droidspaces |

**Verdict:** LOS + alt KSU fork; not stock OOS.

---

#### B5. oluceps — older LOS20 + KSU

| | |
|--|--|
| **Repo** | https://github.com/oluceps/android_kernel_oneplus_sm8250-KSU |
| **Base** | LineageOS lineage-20 |
| **Push** | 2024-03 (stale) |

**Verdict:** Historical reference only.

---

#### B6. crDroid kernel fork

| | |
|--|--|
| **Repo** | https://github.com/crdroidandroid/android_kernel_oneplus_sm8250 |
| **Role** | Custom ROM kernel fork of LOS lineage |

**Verdict:** Same class as LineageOS; use if you target crDroid specifically.

---

### Tier C — Do not use as primary

| Source | Why not |
|--------|---------|
| **OnePlusOSS/android_kernel_oneplus_sm8250** | Incomplete; broken oplus vendor links; our CI failed repeatedly |
| Random thin forks with 0 stars / copy-paste names | Unverified; high risk |
| Pure NetHunter forks | Different goal; may boot but not “stock baseline” product |

---

## 3. Stock vs LineageOS matrix

| Source | Buildable OSS? | Stock OOS | LineageOS | Pre-KSUN | Pre-SUSFS | Maintained (2025–26) |
|--------|----------------|-----------|-----------|----------|-----------|----------------------|
| OnePlusOSS | Poor | Theoretical | No | No | No | Stale dumps |
| **LineageOS** | **Excellent** | Unreliable / wrong class | **Yes** | No | No | **Yes** |
| **HELLBOY017** | **Good** | **Yes (primary use)** | Weak/old LOS branch | No | No | Moderate (2024 default) |
| **Realking** | **Good (CLO)** | **Claimed** | **Claimed AOSP** | Partial (tree has KernelSU) | `susfs+bb` | **Yes (2026)** |
| **wagamy** | Excellent (LOS fork) | No | **Yes** | **Yes** | **Yes** | Yes (2026) |
| AzusaHana CI | N/A (builder) | No | Yes | Applied in CI | Optional/varies | Yes |

---

## 4. What community KSUN builders actually use

From [larrypaul93/oneplus8-kernelsu-susfs](https://github.com/larrypaul93/oneplus8-kernelsu-susfs) README:

| Option | Default |
|--------|---------|
| `kernel_source` | **HELLBOY017/kernel_oneplus_sm8250** |
| Devices | OP8 / 8 Pro / 8T / 9R |
| Features | KSUN / rsuntk / SukiSU / SUSFS |
| Packaging | AnyKernel3 |

They explicitly credit **Meteoric (HELLBOY017)**, **not** OnePlusOSS.

AzusaHana / wagamy path uses **LineageOS** for custom ROM users.

---

## 5. Recommended strategy for *this* repo (`op8series-sm8250-ksu-susfs`)

### 5.1 Product design (two profiles)

```text
configs/build-request.json (or workflow inputs)
  source_profile: STOCK_OOS | LINEAGE
  build_mode:     STOCK | KSUN | KSUN_SUSFS
```

| `source_profile` | Default kernel_source | Default branch (starting point) |
|------------------|----------------------|----------------------------------|
| **STOCK_OOS** | `https://github.com/HELLBOY017/kernel_oneplus_sm8250` | `14` (or `oos` for older OOS) |
| **STOCK_OOS_ALT** | `https://github.com/Rohail33/Realking_kernel_sm8250` | `opkona` or `op-staging` (verify) |
| **LINEAGE** | `https://github.com/LineageOS/android_kernel_oneplus_sm8250` | `lineage-23.2` |
| **LINEAGE_KSUN** | `https://github.com/wagamy/android_kernel_oneplus_sm8250` | `ksun-susfs` (skip re-patch if possible) |

### 5.2 Priority order to green builds

1. **LINEAGE + STOCK mode** on LineageOS `lineage-23.2`  
   → proves pipeline (defconfig + Image + AK3).  
2. **LINEAGE + KSUN / KSUN_SUSFS** (or wagamy `ksun-susfs`).  
3. **STOCK_OOS + STOCK mode** on HELLBOY017 `14` or `oos`.  
4. **STOCK_OOS + KSUN_SUSFS** (same tree + our scripts).  
5. Optionally evaluate **Realking** if you need one CLO tree for dual ROM claims.

### 5.3 What to stop doing

- Do **not** keep OnePlusOSS as the only/default `KERNEL_SOURCE` for automated green CI.
- Do **not** expect one zip to be “official for stock and LOS” without separate QA.

---

## 6. Suggested defaults for your next code change

**Minimum change for success:**

```yaml
# STOCK_OOS profile
KERNEL_SOURCE: https://github.com/HELLBOY017/kernel_oneplus_sm8250.git
KERNEL_BRANCH: "14"          # or "oos" after you confirm device ROM generation
DEFCONFIG: vendor/kona-perf_defconfig   # confirm exists on that branch

# LINEAGE profile
KERNEL_SOURCE: https://github.com/LineageOS/android_kernel_oneplus_sm8250.git
KERNEL_BRANCH: lineage-23.2
DEFCONFIG: <LOS device defconfig for sm8250-common / opkona>
```

Exact LOS defconfig name should be verified on the branch (often under `arch/arm64/configs/` device fragments used by Android build — standalone `make` may use a vendor defconfig provided by the tree).

---

## 7. Sources used

- GitHub API / repo metadata (2026-07-25): LineageOS, HELLBOY017, wagamy, Realking, AzusaHana, larrypaul93, oluceps, LenseTech, Hotsteel2901  
- [larrypaul93/oneplus8-kernelsu-susfs README](https://github.com/larrypaul93/oneplus8-kernelsu-susfs) — default HELLBOY017  
- [AzusaHana/KernelSU_Build_Test README](https://github.com/AzusaHana/KernelSU_Build_Test) — LOS 23.2 SM8250  
- [wagamy/android_kernel_oneplus_sm8250](https://github.com/wagamy/android_kernel_oneplus_sm8250) — KSUN+SUSFS on LOS  
- [Rohail33/Realking_kernel_sm8250](https://github.com/Rohail33/Realking_kernel_sm8250) — dual OOS/AOSP claim  
- Prior project failures: OnePlusOSS incomplete vendor/oplus symlinks  
- Community lesson (kernel must match ROM class): e.g. public kernel build writeups distinguishing OOS vs LOS sources  

---

## 8. Bottom line

| Need | Use this source |
|------|------------------|
| **LineageOS + clean OSS + maintained** | **LineageOS/android_kernel_oneplus_sm8250** (`lineage-23.2`) |
| **LineageOS + KSUN+SUSFS already in tree** | **wagamy** `ksun-susfs` |
| **Stock OOS + community-proven for KSUN builders** | **HELLBOY017/kernel_oneplus_sm8250** (`14` / `oos`) |
| **CLO multi-device, claims OOS+AOSP, active 2026** | **Rohail33/Realking_kernel_sm8250** (`opkona` / `op-staging` / `susfs+bb`) |
| **Official OnePlus dump alone** | **Avoid** as sole build source |

**No silver bullet:** “one tree, perfect stock + LOS forever” is not what the ecosystem reliably offers.  
**Best practice:** dual profile (STOCK_OOS + LINEAGE) with the sources above.

---

*Research only — no pipeline switch applied in this document step unless you ask to implement next.*
