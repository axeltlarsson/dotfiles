{
  description = "Axel's Home Manager Configurations";

  inputs = {
    nixpkgs.url = "flake:nixpkgs";
    # TODO use "github:nixos/nixpkgs/nixos-unstable"?
    homeManager = {
      url = "github:nix-community/home-manager";
      inputs.nixkpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, homeManager }: {
    homeConfigurations = {
      "axel_mbp16" = homeManager.lib.homeManagerConfiguration {
        configuration = import ./axel_mbp16.nix;
        system = "x86_64-darwin";
        homeDirectory = "/Users/axel";
        username = "axel";
        stateVersion = "21.11";
      };
      "andrimner" = homeManager.lib.homeManagerConfiguration {
        configuration = import ./andrimner.nix;
        system = "x86_64-linux";
        homeDirectory = "/home/axel";
        username = "axel";
        stateVersion = "21.11";
      };
    };
  };
  # TODO: nixpi nixos configuration (including home-manager conf)
}
