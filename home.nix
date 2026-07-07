{ config, pkgs, ... }:
let
  # kickstart.nvim, pinned. Only init.lua is shipped (as a store symlink), so
  # the ~/.config/nvim dir stays writable for lazy.nvim's lazy-lock.json.
  # Bump: rev + hash via `nix store prefetch-file --unpack <archive-url>`.
  kickstart = pkgs.fetchFromGitHub {
    owner = "nvim-lua";
    repo = "kickstart.nvim";
    rev = "f0a2108ed51547793c758d9318bad94f242b22e5";
    hash = "sha256-FHNAmiGS51jy6RhP/0bPJPHtl2d8+tMwpAM1PTtJQf8=";
  };
in
{
  imports = [ ./shared.nix ];

  home.username = "tyson";
  home.homeDirectory = "/Users/tyson";
  home.stateVersion = "24.05";  # set once, don't bump casually
  home.packages= [
    (pkgs.writeShellScriptBin "vm" (builtins.readFile ./vm))
    # sops-nix authoring tools (Mac host only — used to create/edit per-VM
    # secrets and generate age keypairs). NOT needed inside guests.
    pkgs.sops
    pkgs.age
    pkgs.yq-go   # robust .sops.yaml edits for `vm new` / `vm rekey`

    # kickstart.nvim runtime deps: telescope/grep (ripgrep, fd), treesitter
    # parser compilation (gcc, gnumake), and mason/plugin unpacking (unzip).
    pkgs.ripgrep
    pkgs.fd
    pkgs.gcc
    pkgs.gnumake
    pkgs.unzip
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "tysonxor";
      user.email = "12140944+tysonxor@users.noreply.github.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        addKeysToAgent = "yes";
      };
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519";
        UseKeychain = "yes";
      };
    };
  };

  # Ghostty is installed manually on the host (not via Nix).

  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    defaultEditor = true;            # sets $EDITOR; optional
    viAlias = true;                  # `vi` -> nvim; optional
    vimAlias = true;                 # `vim` -> nvim; optional
    # No extraConfig on purpose: with empty rc content home-manager generates
    # no init.lua, leaving the path free for the kickstart symlink below.
  };

  # kickstart.nvim's init.lua, pinned via Nix. lazy.nvim bootstraps the plugins
  # into ~/.local/share/nvim on first launch. init.lua itself is a read-only
  # store symlink — to customise, fork kickstart and repoint `rev`/`hash` above.
  xdg.configFile."nvim/init.lua".source = "${kickstart}/init.lua";

 # programs.zsh = {
 #   enable = true;
 #   autosuggestion.enable = true;
 #   syntaxHighlighting.enable = true;
 #   enableCompletion = true;
 # };

#  programs.atuin = {
#    enable = true;
#    enableZshIntegration = true;
#  };

#  programs.starship = {
#    enable = true;
#    enableZshIntegration = true;
#  };
}
