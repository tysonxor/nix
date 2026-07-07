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
    # parser install/compilation (tree-sitter CLI + gcc, gnumake), and
    # mason/plugin unpacking (unzip).
    pkgs.ripgrep
    pkgs.fd
    pkgs.tree-sitter
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

  # Declaratively-provided tree-sitter grammars. nvim-treesitter treats a
  # `parser/<lang>.so` found anywhere on the runtimepath as "installed", and
  # ~/.config/nvim is on that path — so exposing the Nix-built parsers here
  # means kickstart's `auto_install = true` finds them already present and
  # never shells out to the tree-sitter CLI / gcc for these languages.
  # Add a language: append `p.<lang>` below and rebuild. Grammar version comes
  # from nixpkgs while the nvim-treesitter plugin is pinned by lazy-lock.json;
  # if they drift and queries error, bump both together. The CLI + gcc stay in
  # home.packages as the runtime fallback for any language not listed here.
  xdg.configFile."nvim/parser".source =
    "${pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
      p.lua p.vim p.vimdoc p.bash p.nix p.markdown p.markdown_inline p.query
    ])}/parser";

  # File tree (neo-tree.nvim). kickstart ships this as an opt-in module but
  # leaves its `require 'kickstart.plugins.neo-tree'` commented out in init.lua
  # — which we can't uncomment since init.lua is a read-only store symlink.
  # Instead, ship kickstart's own neo-tree module (stays pinned with `rev`) and
  # load it from a `plugin/` file, which Neovim auto-sources after init.lua.
  # neo-tree installs its plugins via vim.pack on first launch. Toggle with `\`.
  xdg.configFile."nvim/lua/kickstart/plugins/neo-tree.lua".source =
    "${kickstart}/lua/kickstart/plugins/neo-tree.lua";
  xdg.configFile."nvim/plugin/kickstart-neo-tree.lua".text = ''
    require 'kickstart.plugins.neo-tree'
  '';

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
