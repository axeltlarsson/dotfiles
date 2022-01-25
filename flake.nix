{
  description = "Axel's Home Manager/NixOS Configurations";

  inputs = {
    nixpkgs.url = "flake:nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixkpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }: {
    homeConfigurations = {
      "axel_mbp16" = home-manager.lib.homeManagerConfiguration {
        configuration = import ./axel_mbp16.nix;
        system = "x86_64-darwin";
        homeDirectory = "/Users/axel";
        username = "axel";
        stateVersion = "21.11";
      };
      "andrimner" = home-manager.lib.homeManagerConfiguration {
        configuration = import ./andrimner.nix;
        system = "x86_64-linux";
        homeDirectory = "/home/axel";
        username = "axel";
        stateVersion = "21.11";
      };
    };
    nixosConfigurations = {
      nixpi = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./nixpi/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.axel = import ./home.nix;

            # Optionally, use home-manager.extraSpecialArgs to pass
            # arguments to home.nix
          }
        ];
      };
    };
  };
}
