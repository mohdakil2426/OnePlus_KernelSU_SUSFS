# OP8 CI Presentation and Safety Design

**Date:** 2026-07-26  
**Status:** Approved by the user's instruction to implement the OnePlus work end to end

## Goal

Make the existing verified OnePlus 8 OOS 13.1 build easy to run and audit
without changing its kernel source, toolchain, KernelSU-Next integration, SUSFS
port, or AnyKernel installer behavior.

## Scope

- OnePlus 8 (`instantnoodle`) only in the current Run workflow form.
- Keep the exact verified source, compiler, KernelSU-Next, SUSFS, and AnyKernel
  revisions.
- Make KernelSU-Next + SUSFS visibly optional through the existing build modes.
- Replace the timestamp-heavy ZIP and artifact names with stable, readable
  identities.
- Publish one structured build summary and checksum sidecar.
- Run repository contract tests before the expensive kernel build.
- Keep releases opt-in and draft-only.

## Reference boundary

The Marble report proves that `pershoot/KernelSU-Next@dev-susfs` is a working
manager-side SUSFS path for Marble's Android 12 / Linux 5.10 GKI kernel.

That fork is **not** copied into this Linux 4.19 non-GKI project. The verified
OnePlus path already uses:

- official `KernelSU-Next/KernelSU-Next` at immutable commit
  `53791c92bff13d62338f29cc9da035a37652ca91`;
- official SUSFS 4.19 at immutable commit
  `001e69919c6271f690fd00b17e4c721c9e599152`;
- the repository's fail-closed current-KSU/SUSFS bridge and exact OnePlus 4.19
  patch.

The transferable pattern is the product behavior: plain KernelSU-Next and
KernelSU-Next + SUSFS are separate optional choices, and summaries state the
resolved source and revisions. Kernel-version-specific integration is not
transferable.

## Run workflow form

Keep the stable `build_mode` input and its three values:

| Value | Result |
|---|---|
| `STOCK` | No root, no SUSFS |
| `KSUN` | Official pinned KernelSU-Next, no SUSFS |
| `KSUN_SUSFS` | The same KernelSU-Next plus the verified optional SUSFS 4.19 port |

The current packager is deliberately restricted to `OP8`, so the visible form
must not offer OP8 Pro, OP8T, or OP9R targets that will fail packaging. Keep
their registry data for future independently verified installers.

The form will expose only OP8-compatible source presets. Arbitrary defconfig,
KernelSU, and SUSFS refs will not be accepted from the form; the verified
immutable pins remain in versioned configuration.

## Naming

Locked ZIP format:

```text
AK3_<device>_<source-preset>_<mode>[_susfs-vX.Y.Z]_k<kernel-version>_r<run>.zip
```

Example:

```text
AK3_op8_oneplusoss-op8-oos13-1_ksun_susfs-v1.5.5_k4.19.157_r42.zip
```

Locked Actions artifact format:

```text
op8-flash-<source-preset>-<mode>-r<run>
```

The run number is stable for the Actions build. Local metadata tests use
`rlocal`.

## Summary

`artifacts/build-summary.md` is generated from `build-info.txt` and contains:

1. exact device/source/build identity;
2. root and optional SUSFS state;
3. immutable source and integration revisions;
4. ZIP/Image SHA-256 values;
5. a prominent compile-vs-device-verification warning;
6. minimal flash and recovery guidance.

The same file is appended to `GITHUB_STEP_SUMMARY`, uploaded with the artifact,
and used as draft release notes.

## Safety and compatibility invariants

- No change to kernel source patches, defconfig content, toolchain, KSU hooks,
  SUSFS ABI bridge, or AnyKernel installer.
- The workflow remains manual `workflow_dispatch` only.
- `main` remains reference-only.
- Source/device mismatches fail in the resolver before runner setup.
- All external Actions remain on their current major release but are pinned to
  immutable commit SHAs.
- A green build remains compile/package proof only; physical OP8 boot and
  hardware verification are still required.

## Verification

- Package-name unit tests cover STOCK, KSUN, and KSUN_SUSFS.
- Summary fixture test covers resolved revisions, optional SUSFS state,
  checksums, and boot warning.
- Workflow contract test covers manual-only triggering, OP8-only form,
  immutable pins, static tests before the build, clear labels, clean artifact
  naming, and draft-only releases.
- Existing AnyKernel and integration contract tests remain green.
- One clean `ONEPLUSOSS_OP8_OOS13_1` + `KSUN_SUSFS` kernel build runs only on
  GitHub Actions; downloaded artifacts are revalidated after completion.
