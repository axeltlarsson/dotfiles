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

  programs.git.userEmail = lib.mkForce "axel@arthro.ai";

  home.file.".config/git/allowed_signers".text = ''
    ${config.programs.git.userEmail} ssh-ed25519 abcTODO
  '';

  programs.k9s = {
    enable = true;
    skins = {
      skin = builtins.fromJSON (builtins.readFile ../config/k9s-rose-pine.json);
    };
  };

  home.packages = [ pkgs.kubie ];
}
