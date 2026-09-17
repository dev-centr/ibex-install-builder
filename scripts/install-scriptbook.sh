#!/usr/bin/env bash
# Bootstrap Scriptbook without requiring Scriptbook.
set -euo pipefail

dest="${XDG_CONFIG_HOME:-$HOME/.config}/ibex/bin"
mkdir -p "$dest"
target="$dest/scriptbook"

if command -v scriptbook >/dev/null 2>&1; then
  echo "Scriptbook already at $(command -v scriptbook)"
  exit 0
fi
if [ -x "$target" ]; then
  echo "Scriptbook already at $target"
  exit 0
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
sibling="$root/../scriptbook/cli"
if [ -f "$sibling/dub.json" ]; then
  echo "Building Scriptbook from sibling checkout..."
  (cd "$sibling" && dub build --build=release)
  built="$sibling/bin/scriptbook"
  if [ -x "$built" ]; then
    cp -f "$built" "$target"
    chmod +x "$target"
    echo "Installed $target"
    echo "Add to PATH: ibex inplace-path add \"$dest\""
    exit 0
  fi
fi

os="$(uname -s)"
if [ "$os" = "Darwin" ]; then
  echo "No macOS Scriptbook release asset yet. Build from https://github.com/dev-centr/scriptbook" >&2
  exit 1
fi
asset="scriptbook-linux-x86_64.tar.gz"
if command -v gh >/dev/null 2>&1; then
  echo "Downloading Scriptbook release..."
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  (
    cd "$tmp"
    gh release download -R dev-centr/scriptbook -p "$asset" --clobber
    tar -xzf "$asset"
    bin="$(find . -type f -name 'scriptbook*' ! -name '*.tar.gz' | head -n 1)"
    cp -f "$bin" "$target"
    chmod +x "$target"
  )
  echo "Installed $target"
  echo "Add to PATH: ibex inplace-path add \"$dest\""
  exit 0
fi

cat >&2 <<'EOF'
Could not install Scriptbook.
- Clone https://github.com/dev-centr/scriptbook next to ibex-install-builder and install DUB, or
- Install GitHub CLI (gh) and re-run, or
- Download https://github.com/dev-centr/scriptbook/releases
EOF
exit 1
