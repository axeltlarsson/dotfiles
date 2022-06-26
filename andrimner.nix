# andrimner server config
{ config, pkgs, ... }: {
  imports = [ ./config/home.nix ];
  home = {
    homeDirectory = "/home/axel";
    username = "axel";
    stateVersion = "21.11";
  };
}
