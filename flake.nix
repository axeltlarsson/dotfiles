{
  description = "Axel's Home Manager/NixOS Configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/Nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      flake-utils,
      nixos-hardware,
      nix-darwin,
    }:
    # home-manager and nixOS configuration
    {
      darwinConfigurations = {
        "axel-mbp14" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./darwin/configuration.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.axel = import ./darwin/axel_mbp14.nix;
            }
          ];
        };
        "axel-mbp14-ja" = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./darwin/configuration.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.axel = import ./darwin/axel_mbp14_ja.nix;
            }
          ];
        };
      };

      homeConfigurations = {
        "andrimner" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [ ./andrimner/home.nix ];
        };
      };
      nixosConfigurations = {
        nixpi = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            ./nixpi/configuration.nix
            nixos-hardware.nixosModules.raspberry-pi-4
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = false;
              home-manager.useUserPackages = true;
              home-manager.users.axel = import ./nixpi/home.nix;

              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
            }
          ];
        };
      };
    }
    # devShells
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        update = pkgs.writeScriptBin "update" "nix flake update --commit-lock-file";
        build = pkgs.writeShellApplication {
          name = "build";
          text = ''
            # first run: no current generation exists so use ./result (diff against oneself)
            # current=$( (home-manager generations 2> /dev/null || echo result) | head -n 1 | awk '{ print $7 }')
            # home-manager build --flake ".#$(hostname -s | awk '{ print tolower($1) }')" && nvd diff "$current" result
            darwin-rebuild build --flake .
          '';
        };
        switch = pkgs.writeScriptBin "switch" ''
          darwin-rebuild switch --flake .
        '';
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = [
            update
            build
            switch
          ];
        };
        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
