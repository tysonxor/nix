{ config, pkgs, vmName, ... }:
{
  imports = [ ./shared.nix ];

  # rebuild THIS guest from inside the VM (vmName = its flake target, e.g. "personal")
  programs.zsh.shellAliases.rebuild = "home-manager switch --flake ~/nix#${vmName}";

  home.username = "tyson";
  home.homeDirectory = "/home/tyson.guest"; # Linux guest path (Lima default), NOT /Users
  home.stateVersion = "24.05";              # match host; set once
  home.sessionVariables.TERM = "xterm-256color"; # fixes weirness with zsh
  home.sessionVariables.DOCKER_HOST = "unix:///run/user/501/podman/podman.sock";

  # --- sops-nix: shared machinery only, NO secrets here (snowflake per guest) ---
  # The age PRIVATE key is placed by `vm create` (limactl copy) at this path.
  # CRITICAL: this is a STRING literal, not a Nix path — a path literal would
  # copy the private key into the world-readable /nix/store. `~` does not
  # expand in Nix, so the absolute path is required. Harmless no-op for guests
  # that declare no sops.secrets.
  sops.age.keyFile = "/home/tyson.guest/.config/sops/age/keys.txt";

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
