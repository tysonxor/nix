{
  description = "nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, mac-app-util, ... }:
  let
    guestPkgs = nixpkgs.legacyPackages."aarch64-linux";

    # every vms/*.nix is a guest identity / target
    guestFiles = builtins.attrNames (
      nixpkgs.lib.filterAttrs
        (name: type:
          type == "regular" && nixpkgs.lib.hasSuffix ".nix" name)
        (builtins.readDir ./vms)
    );

    mkGuest = file:
      home-manager.lib.homeManagerConfiguration {
        pkgs = guestPkgs;
        modules = [ (./vms + "/${file}") ];
      };

    # personal.nix -> "personal", crafted.nix -> "crafted"
    guestConfigs = nixpkgs.lib.listToAttrs (
      map (file: {
        name = nixpkgs.lib.removeSuffix ".nix" file;
        value = mkGuest file;
      }) guestFiles
    );
  in
  {
    darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit self; };
      modules = [
        ./system.nix
        mac-app-util.darwinModules.default
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.tyson = import ./home.nix;
          home-manager.sharedModules = [
            mac-app-util.homeManagerModules.default
          ];
        }
      ];
    };

    homeConfigurations = guestConfigs;
  };
}
