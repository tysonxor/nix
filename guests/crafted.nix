{ config, pkgs, ... }:
{
  imports = [ ./common.nix ];

  programs.git.settings = {
    user.name = "tyson-crafted";
    user.email = "tyson@crafted.solutions";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };
}
