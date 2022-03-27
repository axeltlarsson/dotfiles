# Home Manager common config for all my machines
{ config, pkgs, ... }: {

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # common pacakges I always want
    nix
    nixfmt
    ripgrep
    jq
    diff-so-fancy
    bat
    neovim
    git
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
