{ config, pkgs, ... }:
{
  imports = [ ../guests.nix ];

  programs.git.settings = {
    user.name = "dummy";
    user.email = "dummy@example.com";
  };
}
