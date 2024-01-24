# nixpi server config
{ config, pkgs, ... }: {
  imports = [ ../config/home.nix ];

  programs.git.signing = { key = "89006B84F7EC0084"; };

  home = {
    username = "axel";
    homeDirectory = "/home/axel";
    stateVersion = "24.05";
  };

  home.packages = [
    pkgs.pinentry-curses
  ];


  programs = {
    gpg = { enable = true; };
    ssh = {
      enable = true;
      addKeysToAgent = "confirm";
    };
  };

  services.gpg-agent = {
    enable = true;
    enableZshIntegration = true;
    extraConfig = ''
      pinentry-program ${pkgs.pinentry-curses}/bin/pinentry-curses
    '';
  };

  services.ssh-agent.enable = true;

  systemd.user.startServices = "sd-switch";
}
