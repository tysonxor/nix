#!/usr/bin/env bash
#
# bootstrap.sh — fresh-machine setup for tyson's nix-darwin config.
# Run AFTER installing Nix (in a new shell so nix is on PATH).

set -euo pipefail

REPO_URL="https://github.com/tysonxor/nix"
REPO_DIR="$HOME/nix"
FLAKE_TARGET="mac"

NIX_FLAGS=(--extra-experimental-features "nix-command flakes")

command -v nix >/dev/null 2>&1 || {
  echo "ERROR: nix not found. Install Nix, open a new shell, and re-run."
  exit 1
}

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "==> Cloning config..."
  nix "${NIX_FLAGS[@]}" run nixpkgs#git -- clone "$REPO_URL" "$REPO_DIR"
fi

echo "==> Running darwin-rebuild (you'll be prompted for sudo)..."
sudo nix "${NIX_FLAGS[@]}" run nix-darwin/master#darwin-rebuild -- \
  switch --flake "$REPO_DIR#$FLAKE_TARGET"

echo "==> Setting up SSH key for GitHub..."
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "tyson@mac" -f "$HOME/.ssh/id_ed25519"
fi

pbcopy < "$HOME/.ssh/id_ed25519.pub"
echo ""
echo "  Public key copied to clipboard."
echo "  Paste it at: https://github.com/settings/keys  (New SSH key)"
echo ""
read -r -p "  Press Enter once you've added it on GitHub..."

echo "==> Testing GitHub auth..."
ssh -T git@github.com || true

echo "==> Done."
