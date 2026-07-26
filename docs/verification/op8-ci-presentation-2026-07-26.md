# OP8 CI Presentation Verification — 2026-07-26

## Scope

This task changed the OnePlus builder workflow, validation, artifact naming,
build summaries, documentation, and executable metadata. It did not change the
kernel source patches, defconfig, KernelSU-Next/SUSFS pins, AnyKernel revision,
or Android Clang toolchain.

## Runs

| Run | Result | Meaning |
|---|---|---|
| [`30213471033`](https://github.com/mohdakil2426/OnePlus_KernelSU_SUSFS/actions/runs/30213471033) | Failed before matrix resolution | The Linux static gate correctly found that `scripts/verify-anykernel.sh` was stored as `100644` instead of executable |
| [`30213621719`](https://github.com/mohdakil2426/OnePlus_KernelSU_SUSFS/actions/runs/30213621719) | Success in 17m56s | File mode was corrected to `100755`; validation, clean compile, summary, packaging, and upload passed |

The corrective commit was
`8ba29d19acf2dd17a923dd363f7f6b7cdae2574e`. It changed no file content.

## Resolved build

| Field | Value |
|---|---|
| Device | OnePlus 8 (`instantnoodle`) |
| Source | OnePlusOSS OP8 OOS 13.1 |
| Kernel / companion revisions | `9fdb3aa681ecbafa77e160bd93d0740537c6457c` / `dab8a261393373f8be4e85209eafcdf0d5f461cb` |
| Kernel version | `4.19.157` |
| Toolchain | Android Clang `r399163b` (`11.0.5`) plus matching GNU cross tools |
| Mode | `KSUN_SUSFS`, clean build, ccache disabled |
| KernelSU-Next | `53791c92bff13d62338f29cc9da035a37652ca91` |
| SUSFS | `001e69919c6271f690fd00b17e4c721c9e599152` (`v1.5.5`) |
| AnyKernel3 | `e1e9dce98430c5c6f231f7094a8c7f4ecaf50948` |

## Downloaded artifact audit

Artifact:
`op8-flash-oneplusoss-op8-oos13-1-ksun-susfs-v1.5.5-r34`

| Check | Result |
|---|---|
| ZIP SHA-256 sidecar | Matches `e4a406e8bd260b7e91ece49ae341ab707362b29924bd3c02653a1b3b57d0617d` |
| Standalone and packaged Image | Same SHA-256: `b03bf02ae6fba1ffa09768d07ce74a6ff990568db248c954b17479e96c95f466` |
| Device guard | `device.name1=instantnoodle` |
| Boot target | `block=boot` |
| Slot policy | `is_slot_device=auto` |
| ZIP payload | Non-empty `Image`, AnyKernel core, updater metadata, and tools present |
| Artifact container digest | `sha256:78e4ac3a2fc1935fb546c276b210fe2cb82e70d91c61e6dcdf8c556598e74beb` |

## Safety conclusion

The current evidence proves source resolution, pinned integration, clean
compilation/linking, package structure, device scoping, and checksums. It does
not prove physical boot, root grant, SUSFS behavior, modem, Wi-Fi, display,
camera, charging, suspend, or recovery flashing. Keep the matching stock
`boot.img` before any device test.
