# andrimner server config
{ config, pkgs, ... }: {
  imports = [ ./config/home.nix ];
  home.homeDirectory = "/home/axel";
}
