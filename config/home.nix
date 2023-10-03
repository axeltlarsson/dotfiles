# Home Manager common config for all my machines
{ config, pkgs, ... }: {

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  nixpkgs.overlays = [ (import ../overlays/python.nix) ];

  home.packages = with pkgs; [
    # common packages I always want
    nix
    rnix-lsp
    ripgrep
    jq
    fd
    nvd
    diff-so-fancy
    shellcheck
    shfmt
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

  imports = [

    ./fzf.nix
    ./zsh.nix
    ./tmux.nix
    ./git.nix
  ];
  programs = {

    bat = {
      enable = true;
      themes = {
        # do `bat cache --build` for bat to pick this up
        rose-pine = builtins.readFile (pkgs.fetchFromGitHub {
          owner = "rose-pine";
          repo = "sublime-text"; # Bat uses sublime syntax for its themes
          rev = "ed9ace4c571426070e1046853c13c45d9f12441c";
          sha256 = "sha256-d5CCk15KaIEXFd1LP7q82tcX9evE5G/ZS2GxPCA1K0I=";
        } + "/rose-pine.tmTheme");
      };
      config = { theme = "rose-pine"; };
    };

    eza = {
      enable = true;
      enableAliases = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

  };

}
