# nixpi server config
{ config, pkgs, ... }: {
  imports = [ ../config/home.nix ];
  home = {
    username = "axel";
    homeDirectory = "/home/axel";
    stateVersion = "24.05";
  };
}
