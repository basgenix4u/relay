#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="${FLUTTER_BIN:-flutter}"
cd "$ROOT/mobile"
"$FLUTTER" pub get
"$FLUTTER" build web --release --dart2js-optimization=O1 --web-renderer html --pwa-strategy=none --no-web-resources-cdn
mkdir -p "$ROOT/web_release"
# Keep a ready-to-serve, offline-capable build alongside the source.
python3 - "$ROOT" <<'PY'
import shutil,sys
from pathlib import Path
root=Path(sys.argv[1]); src=root/'mobile/build/web'; dst=root/'web_release'
for item in dst.iterdir():
    if item.is_dir(): shutil.rmtree(item)
    else: item.unlink()
shutil.copytree(src,dst,dirs_exist_ok=True,ignore=shutil.ignore_patterns('canvaskit','*.map','flutter_service_worker.js'))
PY
printf '\nRelay web build ready: %s/web_release\n' "$ROOT"
