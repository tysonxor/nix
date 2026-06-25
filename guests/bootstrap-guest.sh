#!/usr/bin/env bash
# bootstrap-guest.sh — full guest setup. Run inside the guest.
# Usage: bootstrap-guest.sh <flake-target>
set -euo pipefail

TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "ERROR: pass a flake target"; exit 1; }

REPO_URL="https://github.com/tysonxor/nix"
REPO_DIR="$HOME/nix"

# --- Nix (install + load into THIS shell if missing) ---
if ! command -v nix >/dev/null 2>&1; then
  echo "==> Installing Nix..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "==> Cloning config..."
  git clone "$REPO_URL" "$REPO_DIR"
fi

echo "==> Building environment (.#$TARGET)..."
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

echo "==> SSH key..."
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "tyson@$TARGET" -f "$HOME/.ssh/id_ed25519" -N ""
fi
echo ""
echo "  Public key — copy this:"
echo "  ----------------------------------------"
cat "$HOME/.ssh/id_ed25519.pub"
echo "  ----------------------------------------"
echo "  Paste at https://github.com/settings/keys"
echo ""
read -r -p "  Press Enter once added on GitHub..."
ssh -T git@github.com || true
echo "==> Done."
