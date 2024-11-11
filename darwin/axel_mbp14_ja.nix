# home-manager module for mbp14-ja-specific configuration
# see mbp.nix for common macOS configuration
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [ ./mbp.nix ];

  # folder "work"
  home.file."work" = {
    recursive = true;
    source = ../config/work;
  };

  programs.git.signing = {
    key = "935032DCD5C2BAEF";
  };
  programs.git.userEmail = lib.mkForce "axel@arthro.ai";

  programs.k9s = {
    enable = true;
    skins = {
      skin = builtins.fromJSON (builtins.readFile ../config/k9s-rose-pine.json);
    };
  };

  home.packages = [ pkgs.kubie ];
}
