{ config, pkgs, ... }:
{
  imports = [ ../guests.nix ];

  programs.git.settings = {
    user.name = "TODO-set-me";
    user.email = "TODO@example.com";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."github.com".identityFile = "~/.ssh/id_ed25519";
  };

  # Secrets for this VM (edit with: vm secrets qa-test). Add only what this
  # guest needs — snowflake per guest.
  sops.defaultSopsFile = ./qa-test/secrets.yaml;
  sops.secrets."ssh_key" = { path = "/home/tyson.guest/.ssh/id_ed25519"; mode = "0600"; };
  # sops.secrets."aws_config" = { path = "/home/tyson.guest/.aws/config"; };
  # sops.secrets."env_local"  = { path = "/home/tyson.guest/.config/qa-test/env.local"; };
}
