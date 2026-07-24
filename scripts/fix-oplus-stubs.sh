#!/usr/bin/env bash
# OnePlusOSS sm8250 dumps ship broken symlinks into proprietary vendor/oplus
# (and some qcom DT) trees that are not published. Replace broken links with
# minimal stubs so defconfig / make can run.
# Run from kernel source root.

set -eu
# Do NOT enable pipefail — head/find pipelines must not abort the job.

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
  if [[ ! -e "$path" ]]; then
    case "$path" in
      *.h)
        printf '%s\n' '/* Stub header: proprietary source unavailable */' > "$path"
        ;;
      *.c)
        printf '%s\n' '/* Stub source: proprietary source unavailable */' > "$path"
        ;;
      *)
        : > "$path"
        ;;
    esac
  fi
}

fix_broken_symlink() {
  local link="$1"
  local base
  base=$(basename "$link")
  log "Broken symlink: $link -> $(readlink "$link" 2>/dev/null || echo '?')"
  rm -f "$link"
  # Heuristic: extension => file stub, else directory stub
  if [[ "$base" == *.* ]]; then
    stub_file "$link"
  else
    stub_dir "$link"
  fi
}

log "Scanning for broken symlinks under kernel/ drivers/ arch/ include/ techpack/"
# Portable: no process-substitution pipefail traps
mapfile -t links < <(find kernel drivers techpack arch include -type l 2>/dev/null || true)
for link in "${links[@]+"${links[@]}"}"; do
  [[ -z "${link:-}" ]] && continue
  if [[ ! -e "$link" ]]; then
    fix_broken_symlink "$link"
  fi
done

# Explicit known hotspots (if find missed somehow)
for rel in \
  kernel/sched_assist \
  kernel/tuning \
  kernel/uad \
  arch/arm64/boot/dts/vendor
do
  if [[ -L "$rel" && ! -e "$rel" ]]; then
    fix_broken_symlink "$rel"
  elif [[ ! -e "$rel" ]]; then
    log "Missing path $rel — creating stub dir"
    stub_dir "$rel"
  fi
done

# DT vendor stub: empty dts folder is enough for pure Image builds
if [[ -d arch/arm64/boot/dts/vendor ]] && [[ ! -f arch/arm64/boot/dts/vendor/Makefile ]]; then
  printf '%s\n' '# Stub DT vendor tree' > arch/arm64/boot/dts/vendor/Makefile
fi

log "Oplus/vendor symlink stub fix complete"
