{
  description = "ferry — synthetic CLI fixture for the shell-completions skill evals";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        ferry = pkgs.writeShellApplication {
          name = "ferry";
          text = builtins.readFile ./ferry;
        };
      in
      {
        packages.default = ferry;
        devShells.default = pkgs.mkShell { packages = [ ferry ]; };
      }
    );
}
