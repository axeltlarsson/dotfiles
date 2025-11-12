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
    key = "~/.ssh/id_ed25519";
  };

  programs.git.settings.user.email = lib.mkForce "axel@arthro.ai";

  home.file.".config/git/allowed_signers".text = ''
    ${config.programs.git.settings.user.email} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIaizpKc2t1Oowabm8WuRyOm+Fv50ai+vfpnP+Y0XtZz axel@jointacademy.com
  '';

  programs.k9s = {
    enable = true;
    skins = {
      skin = builtins.fromJSON (builtins.readFile ../config/k9s-rose-pine.json);
    };
  };

  home.packages = [ pkgs.kubie ];
}
