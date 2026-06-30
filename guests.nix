{ config, pkgs, ... }:
{
  home.username = "tyson";
  home.homeDirectory = "/home/tyson.guest"; # Linux guest path (Lima default), NOT /Users
  home.stateVersion = "24.05";              # match host; set once
  home.sessionVariables.TERM = "xterm-256color"; # fixes weirness with zsh
  home.sessionVariables.DOCKER_HOST = "unix:///run/user/501/podman/podman.sock";

  # --- shell ---
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # --- git (identity comes from the per-instance file; this is shared config) ---
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      # user.name / user.email intentionally NOT set here — set per-instance
      # --- TODO: paste your full git aliases here when you have them, e.g.:
      # alias.co = "checkout";
      # alias.st = "status";
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
    zellij
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

  # --- Zellij: installed above; config added later (Phase 7) ---
  # We deliberately don't enable shell-integration auto-start; you start it deliberately.

  programs.home-manager.enable = true;       # let HM manage itself in the guest
}
