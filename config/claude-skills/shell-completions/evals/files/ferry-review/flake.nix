{
  description = "ferry — review fixture: the completions in ./completions are deliberately flawed";

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
        ferry-unwrapped = pkgs.writeShellApplication {
          name = "ferry";
          text = builtins.readFile ./ferry;
        };
        ferry = pkgs.symlinkJoin {
          name = "ferry";
          paths = [ ferry-unwrapped ];
          postBuild = ''
            install -Dm644 ${./completions/ferry.bash} $out/share/bash-completion/completions/ferry
            install -Dm644 ${./completions/_ferry} $out/share/zsh/site-functions/_ferry
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell { packages = [ ferry ]; };
      }
    );
}
