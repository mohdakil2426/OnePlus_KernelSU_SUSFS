#!/usr/bin/env bash
# OnePlusOSS sm8250 dumps ship broken symlinks into proprietary vendor/oplus trees
# that are not published. Replace broken links with minimal stubs so kconfig/make work.
# Run from kernel source root.

set -euo pipefail

log() { echo "[stubs] $*"; }

if [[ ! -f Makefile ]]; then
  echo "error: run from kernel root" >&2
  exit 1
fi

# Known broken vendor links on OnePlusOSS sm8250 (U/T/S era)
declare -a KNOWN_LINKS=(
  "kernel/sched_assist"
  "kernel/tuning"
  "kernel/uad"
)

stub_dir() {
  local path="$1"
  mkdir -p "$path"
  if [[ ! -f "$path/Kconfig" ]]; then
    cat > "$path/Kconfig" << 'EOF'
# Stub Kconfig: proprietary OnePlus/Oplus sources not in public OSS dump.
# Intentionally empty so defconfig can proceed.
EOF
  fi
  if [[ ! -f "$path/Makefile" ]]; then
    cat > "$path/Makefile" << 'EOF'
# Stub Makefile — no objects (proprietary sources unavailable)
EOF
  fi
}

log "Fixing known broken oplus symlinks"
for rel in "${KNOWN_LINKS[@]}"; do
  if [[ -L "$rel" ]]; then
    tgt=$(readlink "$rel" || true)
    if [[ ! -e "$rel" ]]; then
      log "Broken symlink $rel -> $tgt ; replacing with stub dir"
      rm -f "$rel"
      stub_dir "$rel"
    else
      log "Symlink $rel resolves OK"
    fi
  elif [[ ! -e "$rel" ]]; then
    log "Missing $rel ; creating stub dir"
    stub_dir "$rel"
  fi
done

# Any other broken symlinks under top-level important trees
log "Scanning for other broken symlinks (kernel drivers techpack arch)"
while IFS= read -r -d '' link; do
  if [[ ! -e "$link" ]]; then
    log "Broken symlink: $link -> $(readlink "$link" || echo '?')"
    rm -f "$link"
    # If name looks like a source tree dir, stub as directory with Kconfig
    parent=$(dirname "$link")
    base=$(basename "$link")
    if [[ "$base" == *.* ]]; then
      # file-like symlink
      mkdir -p "$parent"
      : > "$link"
    else
      stub_dir "$link"
    fi
  fi
done < <(find kernel drivers techpack arch include -type l -print0 2>/dev/null || true)

# Ensure every `source "path/Kconfig"` that is missing gets a stub
log "Stubbing missing Kconfig source paths"
while IFS= read -r line; do
  # source "foo/bar/Kconfig" or source foo/bar/Kconfig
  path=$(echo "$line" | sed -n 's/.*source[[:space:]]*"\([^"]*\)".*/\1/p')
  if [[ -z "$path" ]]; then
    path=$(echo "$line" | sed -n 's/.*source[[:space:]]\+\([^[:space:]]\+\).*/\1/p')
  fi
  [[ -z "$path" ]] && continue
  [[ "$path" == /* ]] && continue
  if [[ ! -f "$path" ]]; then
    log "Missing sourced Kconfig: $path"
    mkdir -p "$(dirname "$path")"
    cat > "$path" << 'EOF'
# Stub Kconfig for missing OSS path
EOF
  fi
done < <(grep -RIn --include='*Kconfig*' -E '^\s*source\s' . 2>/dev/null | head -5000 || true)

log "Oplus/vendor stub fix complete"
