# home-manager common macOS configuration
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../config/home.nix
    ../config/alacritty.nix
    ../config/claude-code.nix
  ];

  # Use XDG paths on macOS (some programs like k9s look in ~/.config/ not ~/Library/Application Support/)
  xdg.enable = true;

  home = {
    username = "axel";
    homeDirectory = lib.mkForce "/Users/axel";
    stateVersion = "21.11";
  };

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    # shell
    shellcheck
    shfmt

    pgformatter

    # python
    uv
    ruff
    ty

    terminal-notifier

    nodejs
    nerd-fonts.hasklug
  ];

  home.sessionPath = [ "${config.home.homeDirectory}/.npm-packages/bin" ];
  home.file.".npmrc".source = ../config/npmrc.conf;

  nix.settings = {
    netrc-file = "${config.home.homeDirectory}/.config/nix/netrc";
  };
}
