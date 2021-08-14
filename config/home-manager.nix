{ config, pkgs, ... }:

{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "axel";
  home.homeDirectory = "/Users/axel";

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
    exa
    nixfmt
    ripgrep
    jq
    diff-so-fancy
    bat
    elmPackages.elm-format
    elmPackages.elm-json
    elmPackages.elm-test
    elmPackages.create-elm-app
    nodejs
    pinentry_mac
    pinentry
    neovim
  ];

  home.sessionPath = [ "${config.home.homeDirectory}/.npm-packages/bin" ];

  home.file.".npmrc".source = ./npmrc.conf;
  home.file.".config/pgcli/config".source = ./pgcli.conf;
  home.file.".pspgconf".source = ./pspg.conf;
  home.file.".psqlrc".source = ./psqlrc.conf;
  home.file.".gnupg/gpg-agent.conf".text = ''
    use-standard-socket
    pinentry-program ${pkgs.pinentry}/bin/pinentry
  '';

  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };

  programs = {

    alacritty = import ./alacritty.nix pkgs;

    zsh = (import ./zsh.nix) { inherit pkgs config; };

    tmux = import ./tmux.nix pkgs;

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    fzf = import ./fzf.nix;

    git = import ./git.nix pkgs;

    gpg = { enable = true; };
  };
}
