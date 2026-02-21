#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

copy_and_patch() {
  local package="$1"
  local version="$2"
  local dest="$3"

  local candidates=(
    "${PUB_CACHE:-}"
    "$HOME/.pub-cache"
    "${LOCALAPPDATA:-}/Pub/Cache"
    "${APPDATA:-}/Pub/Cache"
  )

  local src=""
  for base in "${candidates[@]}"; do
    [[ -n "$base" ]] || continue
    for hosted in "$base/hosted/pub.dev" "$base/hosted"; do
      local candidate="$hosted/${package}-${version}"
      if [[ -d "$candidate" ]]; then
        src="$candidate"
        break
      fi
    done
    [[ -n "$src" ]] && break
  done

  if [[ -z "$src" ]]; then
    echo "[WARN] Could not find ${package}-${version} in pub cache. Skipping copy for ${dest}."
    return 1
  fi

  rm -rf "$dest"
  mkdir -p "$dest"
  cp -a "$src/." "$dest/"

  python3 - "$dest/pubspec.yaml" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding='utf-8')
lines = text.splitlines()
out = []
i = 0
while i < len(lines):
    if lines[i].strip() == 'windows:':
        indent = len(lines[i]) - len(lines[i].lstrip(' '))
        i += 1
        while i < len(lines):
            line = lines[i]
            if not line.strip():
                i += 1
                continue
            current = len(line) - len(line.lstrip(' '))
            if current <= indent:
                break
            i += 1
        continue
    out.append(lines[i])
    i += 1
p.write_text('\n'.join(out) + '\n', encoding='utf-8')
PY

  rm -rf "$dest/windows"
  echo "Prepared $dest from $src"
}

status=0
copy_and_patch firebase_core 4.4.0 third_party/firebase_core_nowindows || status=1
copy_and_patch firebase_auth 6.1.4 third_party/firebase_auth_nowindows || status=1
copy_and_patch cloud_firestore 6.1.2 third_party/cloud_firestore_nowindows || status=1

if [[ "$status" -ne 0 ]]; then
  echo "One or more packages were not found. Run flutter pub get once on your machine, then rerun this script."
  exit 1
fi

echo "All nowindows package forks are prepared."
