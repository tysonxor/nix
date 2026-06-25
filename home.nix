{ config, pkgs, ... }:
{
  home.username = "tyson";
  home.homeDirectory = "/Users/tyson";
  home.stateVersion = "24.05";  # set once, don't bump casually
  home.packages= [
    (pkgs.writeShellScriptBin "vm" (builtins.readFile ./vm))
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "tysonxor";
      user.email = "12140944+tysonxor@users.noreply.github.com";
      init.defaultBranch = "main";
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

  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;        # Darwin: prebuilt binary, NOT pkgs.ghostty (source build)
    enableZshIntegration = true;       # change to enableFishIntegration / enableBashIntegration to match your shell

    settings = {
      # font-family = "JetBrainsMono Nerd Font";
      font-size = 13;
      theme = "Abernathy";
      background-opacity = 0.95;
      macos-option-as-alt = true;
    };
  };

  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    defaultEditor = true;            # sets $EDITOR; optional
    viAlias = true;                  # `vi` -> nvim; optional
    vimAlias = true;                 # `vim` -> nvim; optional

    extraConfig = ''
      " --- clipboard ---
      set clipboard=unnamedplus      " yank/delete go to the system clipboard

      " --- sane minimal defaults ---
      set number                     " line numbers
      set mouse=a                    " mouse support (helps with select/scroll)
      set ignorecase smartcase       " smarter search
      set expandtab shiftwidth=2 softtabstop=2  " 2-space indents
      set clipboard=unnamedplus

      " optional: make yanking the whole buffer to clipboard easy
      nnoremap <leader>Y :%y+<CR>
    '';
  };
}
