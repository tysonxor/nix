{ config, pkgs, ... }:
{
  imports = [ ./shared.nix ];

  home.username = "tyson";
  home.homeDirectory = "/home/tyson.guest"; # Linux guest path (Lima default), NOT /Users
  home.stateVersion = "24.05";              # match host; set once
  home.sessionVariables.TERM = "xterm-256color"; # fixes weirness with zsh
  home.sessionVariables.DOCKER_HOST = "unix:///run/user/501/podman/podman.sock";

  programs.zellij = {
    enable = true;
    settings.default_shell = "/home/tyson.guest/.nix-profile/bin/zsh";
  };

  # --- git (identity comes from the per-instance file; this is shared config) ---
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      # user.name / user.email intentionally NOT set here — set per-instance
    };
  };

  # --- Neovim binary + LazyVim's native toolchain ---
  # NOTE: plain package install, NOT programs.neovim. LazyVim/lazy.nvim
  # manages plugins itself; Nix only provides the binary + build deps.
  home.packages = with pkgs; [
    neovim
    ripgrep
    fd
    fzf
    lazygit
    gcc           # C compiler for tree-sitter parser compilation
    gnumake
    nodejs        # some LSPs / Copilot
    git
    curl
    nerd-fonts.jetbrains-mono
    docker-compose
    postgresql

    # docker compose shim (instead of alias)
    (pkgs.writeShellScriptBin "docker" ''
        if [ "$1" = "compose" ]; then
          shift
          exec ${pkgs.docker-compose}/bin/docker-compose "$@"
        fi
        exec ${pkgs.podman}/bin/podman "$@"
      '')
  ];

  programs.home-manager.enable = true;       # let HM manage itself in the guest
}
