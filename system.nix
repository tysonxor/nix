{ pkgs, self, ... }: {
  environment.systemPackages = [
    pkgs.vim
    pkgs.lima
    pkgs.git
    pkgs.gh
  ];

  system.primaryUser = "tyson";

  system.defaults = {
    dock.autohide = false;
    dock.tilesize = 32;
    dock.largesize = 64;
    dock.magnification = true;
    NSGlobalDomain.KeyRepeat = 1;
    NSGlobalDomain.InitialKeyRepeat = 10;
  };

  users.users.tyson = {
    name = "tyson";
    home = "/Users/tyson";
  };

  environment.shellAliases = {
    rebuild = "sudo darwin-rebuild switch --flake ~/nix#mac";
    flake = "vim ~/nix/flake.nix";
  };

  nix.settings.experimental-features = "nix-command flakes";

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";

  # for ghostty colors so they don't break during sudo
  security.sudo.extraConfig = ''
    Defaults env_keep += "TERMINFO"
  '';
}
