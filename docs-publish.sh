#!/usr/bin/env bash
# Dokumantasyon sitesini uretir ve GitHub Pages'e (gh-pages dali) yayinlar.
#
#   ./docs-publish.sh           # derle + yayinla
#   ./docs-publish.sh --build   # sadece derle (.docs-build/site)
#   ./docs-publish.sh --serve   # yerelde onizle (http://127.0.0.1:8000)
#
# Gereksinim: pipx install mkdocs-material --include-deps
set -euo pipefail
cd "$(dirname "$0")"

SRC=.docs-build/src
rm -rf .docs-build
mkdir -p "$SRC"

# Repodaki .md dosyalarini dizin yapisini koruyarak kopyala; boylece
# dokumanlarin birbirine verdigi goreli linkler oldugu gibi calisir.
# Kod dosyalarina (.swift/.json) verilen linkler GitHub'a yonlendirilir.
python3 - "$SRC" <<'PY'
import os, re, shutil, sys
src = sys.argv[1]
repo = "https://github.com/2sworks/id24.tr-ios-sample-v3/blob/main/"
skip_dirs = {"Vendor", ".docs-build", ".git", "node_modules"}
skip_files = {"CLAUDE.md"}
link = re.compile(r"(\]\()([^)\s#]*)(#[^)]*)?(\))")

def rewrite(md_dir, m):
    target = m.group(2)
    # GitHub "İ" harfini i + birlesik nokta olarak slug'lar; MkDocs noktayi atar.
    frag = (m.group(3) or "").replace("\u0307", "")
    if "://" in target or target.startswith("mailto:") or target.endswith(".md"):
        return f"{m.group(1)}{target}{frag}{m.group(4)}"
    resolved = os.path.normpath(os.path.join(md_dir, target))
    if os.path.isfile(resolved):
        return f"{m.group(1)}{repo}{resolved}{frag}{m.group(4)}"
    if os.path.isdir(resolved):
        return f"{m.group(1)}{repo.replace('/blob/', '/tree/')}{resolved}/{m.group(4)}"
    return m.group(0)

for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in skip_dirs]
    for f in files:
        if not f.endswith(".md") or f in skip_files:
            continue
        path = os.path.normpath(os.path.join(root, f))
        md_dir = os.path.dirname(path)
        text = open(path, encoding="utf-8").read()
        text = link.sub(lambda m: rewrite(md_dir, m), text)
        out = os.path.join(src, path)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, "w", encoding="utf-8").write(text)
PY

case "${1:-}" in
  --build) mkdocs build --strict ;;
  --serve) mkdocs serve ;;
  *)       mkdocs gh-deploy --strict --no-history -m "docs: site yayini" ;;
esac
