#!/usr/bin/env bash
#
# bootstrap.sh — fresh-machine setup for tyson's nix-darwin config
#
# Run this AFTER installing Nix. It clones the config (if needed) and
# does the first darwin-rebuild. The auth steps at the end are manual
# by design — they involve secrets that never live in the repo.
#
# Usage:
#   1. Install Nix:
#        curl --proto '=https' --tlsv1.2 -sSf -L https://nixos.org/nix/install | sh
#      then open a NEW shell so nix is on PATH.
#   2. Run this script:
#        curl -fsSL https://raw.githubusercontent.com/tyson/nix/main/bootstrap.sh | bash
#      (or clone first and run ./bootstrap.sh)

set -euo pipefail

REPO_URL="https://github.com/tysonxor/nix"
REPO_DIR="$HOME/nix"
FLAKE_TARGET="new-machine-name"   # the darwinConfigurations.<name> in flake.nix

echo "==> Checking for Nix..."
if ! command -v nix >/dev/null 2>&1; then
  echo "ERROR: nix not found on PATH."
  echo "Install Nix first, then open a new shell and re-run this script."
  exit 1
fi

# Make sure the experimental features are available for this session,
# in case the daemon config doesn't have them yet (fresh install).
NIX_FLAGS=(--extra-experimental-features "nix-command flakes")

echo "==> Cloning config repo (if not already present)..."
if [ ! -d "$REPO_DIR/.git" ]; then
  # Use nix-provided git so we never trigger the macOS Xcode CLT prompt,
  # and don't depend on a system git existing yet.
  nix "${NIX_FLAGS[@]}" run nixpkgs#git -- clone "$REPO_URL" "$REPO_DIR"
else
  echo "    $REPO_DIR already exists, skipping clone."
fi

echo "==> Running first darwin-rebuild (this installs everything)..."
echo "    You'll be prompted for your sudo password."
sudo nix "${NIX_FLAGS[@]}" run nix-darwin/master#darwin-rebuild -- \
  switch --flake "$REPO_DIR#$FLAKE_TARGET"

cat <<'EOF'

============================================================
  System config is installed. Two manual steps remain
  (these involve secrets, so they're not automated):
============================================================

  1. Authenticate with GitHub and generate an SSH key:

       gh auth login

     Choose:  GitHub.com -> SSH -> "Generate a new SSH key"
     Give it a passphrase when asked. gh uploads the public
     key to GitHub automatically.

  2. Cache the SSH passphrase in the macOS Keychain so you
     aren't prompted on every push:

       ssh-add --apple-use-keychain ~/.ssh/id_ed25519

     (Check the key name with `ls ~/.ssh` if it differs.)

  Then verify everything works:

       ssh -T git@github.com        # should greet you by name
       cd ~/nix && git push         # should push with no prompt

============================================================
EOF
