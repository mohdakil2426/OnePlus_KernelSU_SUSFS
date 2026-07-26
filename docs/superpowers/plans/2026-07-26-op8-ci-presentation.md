# OP8 CI Presentation Implementation Plan

1. Add failing tests for package naming, build summaries, and workflow policy.
2. Add a testable package-name generator and structured summary generator.
3. Wire naming, checksums, summary outputs, and artifact identity into
   `scripts/build.sh`.
4. Simplify the manual form to verified OP8 choices, use configured immutable
   integration pins, run static tests before build, pin Actions, and make
   releases draft-only.
5. Update README and compatibility documentation, including the boundary
   between Marble's pershoot proof and the OnePlus 4.19 official-manager path.
6. Run local non-kernel tests, commit in logical groups, push, and dispatch one
   clean OP8 GitHub Actions build.
7. Download and verify the ZIP, checksum, summary, metadata, and Image; then
   update the project memory bank with the final evidence.
