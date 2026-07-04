{ config, pkgs, ... }:
{
  imports = [ ../guests.nix ];

  programs.git.settings = {
    user.name = "sops-demo";
    user.email = "demo@example.com";
  };

  # --- sops-nix demo: proves per-VM decryption at activation ---
  # This file (a top-level regular .nix) becomes homeConfigurations.sops-demo.
  # Its secrets live in ./sops-demo/secrets.yaml (a SUBDIR, ignored by the
  # flake generator, encrypted to ONLY the sops-demo age key via .sops.yaml).
  sops.defaultSopsFile = ./sops-demo/secrets.yaml;

  # à la carte — this demo enables every pattern to exercise the machinery.
  # SANDBOXED paths only (~/.config/sops-demo/*): deliberately NOT
  # ~/.ssh/id_ed25519 or ~/.aws/config, so activating this can never clobber a
  # real VM's GitHub key. Real guests use the real paths (see setup.md).
  sops.secrets."demo_hello" = { path = "/home/tyson.guest/.config/sops-demo/hello"; };
  sops.secrets."ssh_key"    = { path = "/home/tyson.guest/.config/sops-demo/id_demo"; mode = "0600"; };
  sops.secrets."aws_config" = { path = "/home/tyson.guest/.config/sops-demo/aws_config"; };
  # .env.local pattern: a real file (rootless Podman can't read a tmpfs-symlink
  # target bind-mounted into a container). Placed at a safe home path.
  sops.secrets."env_local"  = { path = "/home/tyson.guest/.config/sops-demo/env.local"; };
}
