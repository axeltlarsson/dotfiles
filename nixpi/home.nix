# nixpi server config
{ config, pkgs, ... }: {
  imports = [ ../config/home.nix ];

  programs.git.signing = { key = "89006B84F7EC0084"; };

  home = {
    username = "axel";
    homeDirectory = "/home/axel";
    stateVersion = "24.05";
  };

  home.packages = [];

  programs = {
    ssh = {
      enable = true;
      addKeysToAgent = "confirm";
    };
  };

  services.ssh-agent.enable = true;

  systemd.user.startServices = "sd-switch";
  nixpkgs.overlays = [ (import ../overlays/python.nix) ];
}
