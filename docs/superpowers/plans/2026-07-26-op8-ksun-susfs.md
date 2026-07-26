# OP8 KernelSU-Next + SUSFS implementation plan

1. Add behavior tests for immutable ref handling, strict patch rejection,
   deterministic manual hooks, and OP8-only AnyKernel packaging. Run them
   against the current scripts and record the expected failures.
2. Replace floating KernelSU integration with a pinned, verified legacy clone.
3. Rebase the official SUSFS 4.19 kernel patch onto the exact OnePlus source and
   add the current-KernelSU SUSFS v1.5.5 compatibility bridge.
4. Replace best-effort manual hook edits with checked OP8-specific patches.
5. Replace the floating/sample AnyKernel package step with a pinned source,
   repository-owned OP8 installer, and ZIP validator.
6. Make build configuration and metadata assertions fail closed. Update the
   workflow defaults and request configuration to immutable compatible refs.
7. Run tests and a local exact-source integration/configuration check. Fix all
   failures and run `git diff --check`.
8. Update project documentation and `memory-bank` with verified revisions,
   limitations, and validation evidence.
9. Commit and push the scoped changes, dispatch one clean OP8
   `KSUN_SUSFS` workflow, and monitor it through artifact validation.
