# mbp14-specific configuration goes here, see mbp.nix for common macOS configuration
{ config, pkgs, ... }: {
  imports = [ ./mbp.nix ];
  programs.git.signing = { key = "3AE85E14F3123D07"; };
}
