{ config, pkgs, ... }:
{
  imports = [ ../guests.nix ];

  # AWS tooling — crafted-specific, not in the shared baseline
  home.packages = [ pkgs.awscli2 ];

  # crafted's compose file mounts /var/run/docker.sock into the api container.
  # Rootless Podman has no such socket — remap it to the Podman socket.
  # Kept out of the (unmodifiable) client repo via a separate override file.
  home.file."incisive-portal-override.yml".text = ''
    services:
      api:
        volumes:
          - /run/user/501/podman/podman.sock:/var/run/docker.sock
  '';

  programs.git.settings = {
    user.name = "tyson-crafted";
    user.email = "281733437+tyson-crafted@users.noreply.github.com";
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

  # invoke compose with both the repo file and our override
  programs.zsh.shellAliases.dcc =
    "docker-compose -f docker-compose.yml -f ~/incisive-portal-override.yml";
}
