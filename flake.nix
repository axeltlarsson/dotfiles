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
            nh darwin build .#
          '';
        };
        nixfmt = pkgs.nixfmt;
        switch = pkgs.writeScriptBin "switch" ''
          nh darwin switch .# --ask
        '';
        # Run nvim against local config w/o having to do `switch` first
        nvim-local = pkgs.writeScriptBin "nvim-local" ''XDG_CONFIG_HOME=$PWD/config nvim -u config/nvim/init.lua "$@"'';
        # CI script that runs linters/static type checkers etc
        # You can run this locally in the same dev shell with `nix develop -c ci` or nix flake check -L which is how CI runs it as well!
        ci = pkgs.writeShellApplication {
          name = "ci";
          runtimeInputs = [
            pkgs.lua-language-server
            nixfmt
          ];
          text = ''
            echo "Checking Lua (lua-language-server)..."
            # Set writable HOME for lua-language-server cache (needed in nix sandbox)
            # Use TMPDIR (macOS/dev shell) or TMP (nix sandbox) or /tmp as fallback
            _tmp="''${TMPDIR:-''${TMP:-/tmp}}"
            export HOME="$_tmp"

            # Create temporary luarc config (avoids .luarc.json in repo conflicting with lazydev)
            cat > "$_tmp/.luarc.json" << 'EOF'
            {
              "runtime": { "version": "LuaJIT" },
              "diagnostics": { "globals": ["vim"] },
              "workspace": { "library": [], "checkThirdParty": false }
            }
            EOF

            # lua-language-server --check always exits 0, so we check output for success message
            lua_output=$(lua-language-server --check="$PWD/config/nvim/lua" --configpath="$_tmp/.luarc.json" --check_format=pretty --checklevel=Warning 2>&1 || true)
            if echo "$lua_output" | grep -q "no problems found"; then
              echo "✓ Lua checks passed"
            else
              echo "Lua diagnostics found:"
              echo "$lua_output"
              exit 1
            fi

            echo "Checking Nix formatting..."
            nixfmt --check flake.nix
            echo "✓ Nix formatting OK"
          '';
        };
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = [
            update
            build
            switch
            nvim-local
            ci

            pkgs.lua-language-server
            pkgs.nh
          ];
        };

        checks = {
          ci = pkgs.runCommand "ci" { } ''
            # checks expects an out path , so we need to create it explicitly
            mkdir -p $out

            # copy over source to a temp dir so we can run the `ci` script self-contained
            # as nix flake check -L without changing the `ci` script itself
            # inspo https://github.com/numtide/treefmt-nix/blob/2fba33a182602b9d49f0b2440513e5ee091d838b/module-options.nix#L156
            PRJ=$TMP/dotfiles
            cp -r ${self} $PRJ
            chmod -R a+w $PRJ
            cd $PRJ

            ${ci}/bin/ci
            echo "✅ All CI checks passed!"
          '';
        };
        formatter = nixfmt;
      }
    );
}
