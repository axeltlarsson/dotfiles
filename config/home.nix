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
    ./ssh.nix
    ./ghostty.nix
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
    # Stable channel for running pre-built packages without local compilation
    # e.g. `nix run nixpkgs-stable#foo`
    nixpkgs-stable = {
      from = {
        id = "nixpkgs-stable";
        type = "indirect";
      };
      to = {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        ref = "nixos-25.11";
      };
    };
  };
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.git.settings.user.email = lib.mkDefault "mail@axellarsson.nu";

  home.packages = with pkgs; [
    # common packages I always want
    nix
    nil
    nixfmt
    ripgrep
    jq
    fd
    nh
    shellcheck
    shfmt
    pandoc

    neovim
    tree-sitter

    pkgs.pythonEnv

    git
    pspg
    zsh-completions
  ];

  home.file.".kube/kubie.yaml".source = ./kubie.yaml;
  home.file.".config/pgcli/config".source = ./pgcli.conf;
  home.file.".pspgconf".source = ./pspg.conf;
  home.file.".psqlrc".source = ./psqlrc.conf;
  home.file.".config/nvim" = {
    source = lib.cleanSourceWith {
      src = ./nvim;
      filter = path: type: !(lib.hasSuffix "lazy-lock.json" path);
    };
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

    yazi =
      let
        rosePineSrc = pkgs.fetchFromGitHub {
          owner = "rose-pine";
          repo = "yazi";
          rev = "c89d745573d4fcfe0550fe6646f9f9ab1c0e51db";
          sha256 = "sha256-9e3dXViWl1rK9BPrGAFfs9ZL/tsG6Njz6ksuU6AIrFY=";
        };
      in
      {
        enable = true;
        enableZshIntegration = true;
        shellWrapperName = "y";
        theme = {
          flavor = {
            dark = "rose-pine";
            light = "rose-pine-dawn";
          };
        } // builtins.fromTOML (builtins.readFile "${rosePineSrc}/themes/rose-pine.toml");
        flavors = {
          rose-pine = "${rosePineSrc}/flavors/rose-pine.yazi";
          rose-pine-dawn = "${rosePineSrc}/flavors/rose-pine-dawn.yazi";
          rose-pine-moon = "${rosePineSrc}/flavors/rose-pine-moon.yazi";
        };
      };

    delta = {
      enable = true;
      options = {
        navigate = true;
      };
      enableGitIntegration = true;
    };

  };
}
