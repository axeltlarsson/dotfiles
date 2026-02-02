# axel-mbp14ja-specific nix-darwin config

{
  pkgs,
  inputs,
  lib,
  ...
}:
{

  programs._1password.enable = true;
}
