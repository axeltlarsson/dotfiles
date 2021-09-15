{
  description = "Axel's Home Manger Configurations";

  inputs = {
    nixpkgs.url = "flake:nixpkgs";
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
    };

  };
}
