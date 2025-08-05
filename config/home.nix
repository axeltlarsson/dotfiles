# Home Manager common config for all my machines
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./fzf.nix
    ./zsh.nix
    ./tmux.nix
    ./git.nix
  ];

  nix.registry = {
    nixpkgs-master = {
      from = {
        id = "nixpkgs-master";
        type = "indirect";
      };
      to = {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        ref = "master";
      };
    };
  };
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.git.userEmail = lib.mkDefault "mail@axellarsson.nu";

  home.packages = with pkgs; [
    # common packages I always want
    nix
    nil
    nixfmt-rfc-style
    ripgrep
    jq
    fd
    nvd
    shellcheck
    shfmt
    pgformatter
    uv
    # wget required by unicodemoji
    wget
    pandoc
    neovim

    pkgs.pythonEnv

    git
    pspg
  ];

  home.file.".config/pgcli/config".source = ./pgcli.conf;
  home.file.".pspgconf".source = ./pspg.conf;
  home.file.".psqlrc".source = ./psqlrc.conf;
  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };
  home.file."dev" = {
    source = ./dev;
    recursive = true;
  };

  programs = {
    bat = {
      enable = true;
      themes = {
        # do `bat cache --build` for bat to pick this up
        rose-pine = {
          src = pkgs.fetchFromGitHub {
            owner = "rose-pine";
            repo = "sublime-text"; # Bat uses sublime syntax for its themes
            rev = "ed9ace4c571426070e1046853c13c45d9f12441c";
            sha256 = "sha256-d5CCk15KaIEXFd1LP7q82tcX9evE5G/ZS2GxPCA1K0I=";
          };
          file = "/rose-pine.tmTheme";
        };
      };
      config = {
        theme = "rose-pine";
      };
    };

    eza = {
      enable = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    yazi = {
      enable = true;
      enableZshIntegration = true;
      flavors = {
        rose-pine =
          pkgs.runCommand "rose-pine-flavor"
            {
              buildInputs = [ pkgs.git ];
            }
            ''
              src=$(mktemp -d)
              cp -r ${
                pkgs.fetchFromGitHub {
                  owner = "Msouza91";
                  repo = "rose-pine.yazi";
                  rev = "4101d0d9c475f23d94b7262e7fd945930378807e";
                  sha256 = "sha256-Ygx3tyefGcq3Qqk/72RSJbT5K8G7wVqIk2rCI0vKkNQ=";
                }
              }/* $src

              # Rename files to match yazi's expectations
              mv $src/theme.toml $src/flavor.toml
              mv $src/rose-pine.tmTheme $src/tmtheme.xml
              cp $src/LICENSE $src/LICENSE-tmtheme

              # Move everything to the output directory
              mkdir -p $out
              cp -r $src/* $out
            '';
      };
    };
  };
}
