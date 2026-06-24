{ config, pkgs, ... }:
{
  home.username = "tyson";
  home.homeDirectory = "/Users/tyson";
  home.stateVersion = "24.05";  # set once, don't bump casually

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
}
