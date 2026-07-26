#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/build-kernel.yml"
INPUTS="$(sed -n '1,/^jobs:/p' "$WORKFLOW")"

grep -Fq 'workflow_dispatch:' "$WORKFLOW"
for automatic in '  push:' '  pull_request:' '  schedule:'; do
  if grep -Fq "$automatic" "$WORKFLOW"; then
    echo "error: workflow must remain manual-only: $automatic" >&2
    exit 1
  fi
done

required_menu_labels=(
  "description: 'Root: STOCK / KernelSU-Next / optional SUSFS'"
  "description: 'Device: verified OnePlus 8 only'"
  "description: 'Source: OP8-compatible kernel preset'"
  "description: 'CI: clean build without ccache'"
  "description: 'Release: create draft after success'"
)
for label in "${required_menu_labels[@]}"; do
  grep -Fq "$label" "$WORKFLOW" || {
    echo "error: Run workflow menu missing clear label: $label" >&2
    exit 1
  }
done

for unsupported in OP8Pro OP8T OP9R TORAIDL ONEPLUSOSS_OP9R ONEPLUSOSS_OP8T; do
  if grep -Fq -- "- $unsupported" <<< "$INPUTS"; then
    echo "error: unverified/non-OP8 menu option remains: $unsupported" >&2
    exit 1
  fi
done

for unsafe_input in defconfig_override ksun_ref susfs_ref; do
  if grep -Eq "^[[:space:]]{6}${unsafe_input}:" <<< "$INPUTS"; then
    echo "error: mutable advanced input remains in Run workflow: $unsafe_input" >&2
    exit 1
  fi
done

required_workflow_patterns=(
  'actions/checkout@11d5960a326750d5838078e36cf38b85af677262'
  'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02'
  'actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093'
  'softprops/action-gh-release@3bb12739c298aeb8a4eeaf626c5b8d85266b0e65'
  'bash tests/run-static-tests.sh'
  'cat artifacts/build-summary.md >> "$GITHUB_STEP_SUMMARY"'
  "name: \${{ steps.build.outputs.artifact_name }}"
  'artifacts/*.zip.sha256'
  'artifacts/build-summary.md'
  'draft: true'
  'body_path: artifacts/build-summary.md'
  'inputs.clean_build != true'
)
for pattern in "${required_workflow_patterns[@]}"; do
  grep -Fq -- "$pattern" "$WORKFLOW" || {
    echo "error: workflow policy missing: $pattern" >&2
    exit 1
  }
done

echo "Workflow policy tests passed"
