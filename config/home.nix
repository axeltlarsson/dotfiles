# Home Manager common config for all my machines
{ config, pkgs, ... }: {

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.username = "axel";
  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "21.11";

  home.packages = with pkgs; [
    # common pacakges I always want
    nixfmt
    ripgrep
    jq
    diff-so-fancy
    bat
    neovim
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
