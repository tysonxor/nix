{ config, pkgs, ... }:
{
  imports = [ ./common.nix ];

  programs.git.settings = {
    user.name = "tysonxor";
    user.email = "12140944+tysonxor@users.noreply.github.com";
  };

  # SSH identity for personal GitHub — key is generated INSIDE this VM
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
