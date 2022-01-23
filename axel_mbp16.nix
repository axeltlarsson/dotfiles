# My macbook pro 16" config
{ config, pkgs, ... }: {
  imports = [
    # Common home manager conf
    ./config/home.nix

    ./config/alacritty.nix
  ];

  home.packages = with pkgs; [
    elmPackages.elm
    elmPackages.elm-format

    black

    nodejs

    nixfmt

    pinentry_mac
  ];

  home.sessionPath = [ "${config.home.homeDirectory}/.npm-packages/bin" ];

  home.file.".npmrc".source = ./config/npmrc.conf;
  home.file.".gnupg/gpg-agent.conf".text = ''
    use-standard-socket
    pinentry-program ${pkgs.pinentry}/bin/pinentry
  '';

  programs = {

    gpg = { enable = true; };
  };

}
