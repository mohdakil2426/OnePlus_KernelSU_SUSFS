#!/usr/bin/env bash
# OnePlusOSS sm8250 dumps ship many broken symlinks into proprietary
# vendor/oplus and qcom DT trees. Replace ALL broken symlinks under the
# kernel tree with minimal stubs so defconfig / Image build can proceed.
# Run from kernel source root.

set -eu
# No pipefail — find/read loops must not abort the job.

log() { echo "[stubs] $*"; }

if [[ ! -f Makefile ]]; then
  echo "error: run from kernel root" >&2
  exit 1
fi

stub_dir() {
  local path="$1"
  mkdir -p "$path"
  if [[ ! -f "$path/Kconfig" ]]; then
    printf '%s\n' '# Stub: proprietary source not in public OnePlusOSS dump' > "$path/Kconfig"
  fi
  if [[ ! -f "$path/Makefile" ]]; then
    printf '%s\n' '# Stub Makefile — no objects' > "$path/Makefile"
  fi
}

stub_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  if [[ -e "$path" ]]; then
    return 0
  fi
  case "$path" in
    *.h)
      printf '%s\n' '/* Stub header: proprietary source unavailable */' > "$path"
      ;;
    *.c|*.S|*.s)
      printf '%s\n' '/* Stub source: proprietary source unavailable */' > "$path"
      ;;
    *)
      : > "$path"
      ;;
  esac
}

fix_broken_symlink() {
  local link="$1"
  local base
  base=$(basename "$link")
  log "Broken symlink: $link -> $(readlink "$link" 2>/dev/null || echo '?')"
  rm -f "$link"
  if [[ "$base" == *.* ]]; then
    stub_file "$link"
  else
    stub_dir "$link"
  fi
}

log "Scanning entire tree for broken symlinks (excl. .git)"
count=0
# Use find -print0 for safety
while IFS= read -r -d '' link; do
  if [[ ! -e "$link" ]]; then
    fix_broken_symlink "$link"
    count=$((count + 1))
  fi
done < <(find . -path './.git' -prune -o -type l -print0 2>/dev/null)

log "Fixed $count broken symlinks"

# Also stub missing Kconfig targets that are hard-sourced (no $ vars)
# e.g. source block/blk/Kconfig after we already stubbed the dir
log "Ensuring sourced Kconfig files exist (static paths only)"
while IFS= read -r line; do
  # Extract path from: source "path"  OR  source path
  path=""
  if [[ "$line" =~ source[[:space:]]+\"([^\"]+)\" ]]; then
    path="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ source[[:space:]]+([^[:space:]#]+) ]]; then
    path="${BASH_REMATCH[1]}"
  fi
  [[ -z "$path" ]] && continue
  # Skip make variables and absolute junk
  [[ "$path" == *'$'* ]] && continue
  [[ "$path" == *'('* ]] && continue
  [[ "$path" == /* ]] && continue
  if [[ ! -f "$path" ]]; then
    log "Stub missing sourced Kconfig: $path"
    mkdir -p "$(dirname "$path")"
    printf '%s\n' '# Stub Kconfig (sourced but missing from OSS dump)' > "$path"
  fi
done < <(grep -RIn --include='*Kconfig*' -E '^[[:space:]]*source[[:space:]]' . 2>/dev/null | sed 's/^[^:]*:[0-9]*://' || true)

log "Oplus/vendor stub fix complete"
