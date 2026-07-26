# OP8 KernelSU-Next + SUSFS build design

Date: 2026-07-26

## Goal

Produce one clean OnePlus 8 (`instantnoodle`) Android 13.1 kernel build with:

- KernelSU-Next's current Linux 4.x-compatible `legacy` revision;
- the newest official SUSFS revision that supports Linux 4.19;
- a fail-closed integration (no silent fallback, fuzzy-success, or rejects);
- a device-scoped AnyKernel3 ZIP whose installer targets only the OP8 boot slot;
- exact source revisions recorded in the artifact.

The existing stock build at commit `15686e4` is the compiler/source baseline.

## Verified upstream constraints

- KernelSU-Next no longer has the configured `next` branch. Its current
  Linux 4.x line is `legacy`, revision
  `53791c92bff13d62338f29cc9da035a37652ca91`.
- Official SUSFS has no newer Linux 4.19 branch than `kernel-4.19`, revision
  `001e69919c6271f690fd00b17e4c721c9e599152`, reporting SUSFS `v1.5.5`.
- SUSFS's bundled KernelSU patch targets an older, flat KernelSU source layout.
  It cannot be applied to current KernelSU-Next without a compatibility port.
- The official SUSFS kernel patch also needs six OnePlus-specific context
  adaptations. A fuzzy patch with `.rej` files is not an acceptable build.
- WildKernels' AnyKernel3 fork is GKI-only. Its boot-slot pattern is useful,
  but its stock installer must not be flashed on this non-GKI 4.19 kernel.

## Options considered

1. Pin an older KernelSU-Next revision that accepts the official SUSFS patch.
   This is simpler, but violates the requirement to use current compatible
   KernelSU-Next.
2. Use current KernelSU-Next and copy only SUSFS kernel files. This can compile
   while leaving the SUSFS userspace control protocol and lifecycle hooks
   incomplete, so it is not a real integration.
3. Use current KernelSU-Next plus a repository-owned 4.19 compatibility bridge.
   Port the official SUSFS v1.5.5 command ABI and lifecycle calls into the
   current KernelSU source layout, and rebase the official kernel patch onto the
   exact OnePlus tree. This is selected.

## Selected implementation

All external repositories are fetched by immutable commit SHA. The scripts
verify the checked-out SHA and abort on mismatch.

`apply-ksun.sh` clones KernelSU-Next directly at the pinned revision and runs
its legacy setup. It does not download a floating setup script or fall back to
another ref.

`apply-susfs.sh` clones official SUSFS at the pinned revision, copies the
official `fs` and `include` sources, applies an OP8-rebased kernel patch with
`git apply --check`, and applies the current-KernelSU compatibility patch with
the same strict check. It aborts if any reject or backup file exists.

The bridge retains SUSFS v1.5.5's root-only `prctl` command ABI so the official
userspace helper remains compatible. It wires only the hooks required by the
enabled feature set. The kprobe-only `SUS_SU` feature remains disabled on this
manual-hook Linux 4.19 build.

`add-manual-hooks.sh` becomes deterministic and OP8-specific. Each required
hook must be inserted exactly once; missing anchor text is fatal.

The packager pins a reviewed AnyKernel3 source revision but replaces its GKI
installer with a repository-owned non-GKI OP8 installer. The resulting ZIP
must contain `Image`, identify only `instantnoodle`, use `block=boot` and
`is_slot_device=auto`, and contain no sample Tuna/OMAP paths or GKI abort.

## Verification

Before dispatch:

- shell integration tests fail against the old implementation, then pass;
- the strict patches apply to the exact assembled OnePlus source with no
  rejects;
- configuration assertions prove KernelSU, manual hooks, and enabled SUSFS
  features;
- `git diff --check` passes.

GitHub Actions then performs exactly one clean OP8 `KSUN_SUSFS` build. Success
requires a green build job, non-empty `Image`, validated AnyKernel3 ZIP, and
`build-info.txt` containing exact KernelSU, SUSFS, AnyKernel, source, and
toolchain revisions.

Compilation cannot prove device boot safety. The ZIP will remain explicitly
unverified-on-device until the user tests it with a backed-up stock boot image.
