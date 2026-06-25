#!/usr/bin/env bash
#
# bootstrap-guest.sh — sets up a Lima dev guest from tyson's nix config.
# Run INSIDE the guest. Installs Nix guidance if missing.
#
# Usage:  ./bootstrap-guest.sh <flake-target>     e.g. ./bootstrap-guest.sh crafted

set -euo pipefail

TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "ERROR: pass a flake target, e.g. ./bootstrap-guest.sh crafted"; exit 1; }

REPO_URL="https://github.com/tysonxor/nix"
REPO_DIR="$HOME/nix"

if ! command -v nix >/dev/null 2>&1; then
  cat <<'EOF'
ERROR: nix not found on PATH.

Install Nix first:
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

Then open a NEW shell (exit and re-enter the guest) and re-run this script.
EOF
  exit 1
fi

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "==> Cloning config..."
  git clone "$REPO_URL" "$REPO_DIR"
fi

echo "==> Building home-manager environment (.#$TARGET)..."
cd "$REPO_DIR"
nix run home-manager/master -- switch -b backup --flake ".#$TARGET"

echo "==> Setting login shell to zsh..."
ZSH_PATH="$HOME/.nix-profile/bin/zsh"
if [ -x "$ZSH_PATH" ]; then
  grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  sudo chsh -s "$ZSH_PATH" "$(whoami)"
fi

echo "==> Installing LazyVim..."
if [ ! -d "$HOME/.config/nvim" ]; then
  git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
  nvim --headless "+Lazy! sync" +qa
fi

echo "==> Setting up SSH key for GitHub..."
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "tyson@$TARGET" -f "$HOME/.ssh/id_ed25519"
fi

echo ""
echo "  Public key (copy this — select it in your terminal):"
echo "  --------------------------------------------------------"
cat "$HOME/.ssh/id_ed25519.pub"
echo "  --------------------------------------------------------"
echo "  Paste it into the correct GitHub account:"
echo "    https://github.com/settings/keys  (New SSH key)"
echo ""
read -r -p "  Press Enter once you've added it on GitHub..."

echo "==> Testing GitHub auth..."
ssh -T git@github.com || true

echo "==> Done."
