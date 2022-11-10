# mbp14-ja-specific configuration goes here, see mbp.nix for common macOS configuration
{ config, pkgs, ... }: {
  imports = [ ./mbp.nix ];
  programs.git.signing = { key = "381AE25298A4EFF6"; };
}
