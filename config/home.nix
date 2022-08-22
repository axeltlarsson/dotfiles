# Home Manager common config for all my machines
{ config, pkgs, ... }: {

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  nixpkgs.overlays = [ (import ../overlays/python.nix) ];

  home.packages = with pkgs; [
    # common packages I always want
    nix
    nixfmt
    ripgrep
    jq
    fd
    nvd
    diff-so-fancy
    shellcheck
    # wget required by unicodemoji
    wget
    pandoc
    neovim

    pkgs.pythonEnv
  ];

  home.file.".config/pgcli/config".source = ./pgcli.conf;
  home.file.".pspgconf".source = ./pspg.conf;
  home.file.".psqlrc".source = ./psqlrc.conf;
  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };

  imports = [

    ./fzf.nix
    ./zsh.nix
    ./tmux.nix
    ./git.nix
  ];
  programs = {

    bat = { enable = true; };

    exa = {
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
