# nixpi server config
{ config, pkgs, ... }: {
  imports = [ ../config/home.nix ];

  programs.git.signing = { key = "dummy"; };
  programs.git.userEmail = "mail@axellarsson.nu";

  home = {
    username = "axel";
    homeDirectory = "/home/axel";
    stateVersion = "24.05";
  };
}
