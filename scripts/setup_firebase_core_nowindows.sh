#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-4.4.0}"
DEST="third_party/firebase_core_nowindows"

candidates=(
  "${PUB_CACHE:-}"
  "$HOME/.pub-cache"
  "${LOCALAPPDATA:-}/Pub/Cache"
  "${APPDATA:-}/Pub/Cache"
)

SRC=""
for base in "${candidates[@]}"; do
  [[ -n "$base" ]] || continue
  for hosted in "$base/hosted/pub.dev" "$base/hosted"; do
    candidate="$hosted/firebase_core-$VERSION"
    if [[ -d "$candidate" ]]; then
      SRC="$candidate"
      break
    fi
  done
  [[ -n "$SRC" ]] && break

done

if [[ -z "$SRC" ]]; then
  echo "Could not find firebase_core-$VERSION in pub cache."
  echo "Looked in: ${candidates[*]}"
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$SRC/." "$DEST/"

python3 - <<'PY'
from pathlib import Path
p = Path('third_party/firebase_core_nowindows/pubspec.yaml')
text = p.read_text()
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
p.write_text('\n'.join(out) + '\n')
PY

rm -rf "$DEST/windows"

echo "Prepared $DEST from $SRC"
