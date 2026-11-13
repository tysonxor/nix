{ config, pkgs, ... }:
{
  imports = [ ../guests.nix ];

  programs.git.settings = {
    user.name = "tyson-incisive";
    user.email = "354999174+tyson-incisive@users.noreply.github.com";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."github.com".identityFile = "~/.ssh/id_ed25519";
  };

  # Secrets for this VM (edit with: vm secrets incisive). Add only what this
  # guest needs — snowflake per guest.
  sops.defaultSopsFile = ./incisive/secrets.yaml;
  sops.secrets."ssh_key" = { path = "/home/tyson.guest/.ssh/id_ed25519"; mode = "0600"; };
  # sops.secrets."aws_config" = { path = "/home/tyson.guest/.aws/config"; };
  # sops.secrets."env_local"  = { path = "/home/tyson.guest/.config/incisive/env.local"; };
}
