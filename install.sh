#!/usr/bin/env bash
# Installer for git-cloudsync: https://github.com/bgrgndzz/git-cloudsync
set -euo pipefail

BIN_DIR="${CLOUDSYNC_BIN_DIR:-$HOME/.local/bin}"
URL="https://raw.githubusercontent.com/bgrgndzz/git-cloudsync/main/cloudsync"

mkdir -p "$BIN_DIR"
curl -fsSL "$URL" -o "$BIN_DIR/cloudsync"
chmod +x "$BIN_DIR/cloudsync"
ln -sf "$BIN_DIR/cloudsync" "$BIN_DIR/git-cloudsync"

echo "installed: $BIN_DIR/cloudsync ($("$BIN_DIR/cloudsync" version))"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note: $BIN_DIR is not on your PATH — add it to your shell profile" ;;
esac
