{
  description = "nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, ... }:
  let
    guestPkgs = nixpkgs.legacyPackages."aarch64-linux";

    # every vm-configs/*.nix is a guest identity / target
    guestFiles = builtins.attrNames (
      nixpkgs.lib.filterAttrs
        (name: type:
          type == "regular" && nixpkgs.lib.hasSuffix ".nix" name)
        (builtins.readDir ./vm-configs)
    );

    mkGuest = name: file:
      home-manager.lib.homeManagerConfiguration {
        pkgs = guestPkgs;
        # vmName lets guests.nix build a `rebuild` alias for THIS flake target.
        extraSpecialArgs = { vmName = name; };
        modules = [
          # sops-nix home-manager module: no-op unless a guest declares
          # sops.secrets, so un-migrated guests (personal, dummy-podman) are
          # unaffected and need no age key.
          inputs.sops-nix.homeManagerModules.sops
          (./vm-configs + "/${file}")
        ];
      };

    # personal.nix -> "personal", crafted.nix -> "crafted"
    guestConfigs = nixpkgs.lib.listToAttrs (
      map (file:
        let n = nixpkgs.lib.removeSuffix ".nix" file; in {
          name = n;
          value = mkGuest n file;
        }) guestFiles
    );
  in
  {
    darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit self; };
      modules = [
        ./system.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.tyson = import ./home.nix;
        }
      ];
    };

    homeConfigurations = guestConfigs;
  };
}
