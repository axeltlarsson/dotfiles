# mbp14-ja-specific configuration goes here, see mbp.nix for common macOS configuration
{ config, pkgs, ... }: {
  imports = [ ./mbp.nix ];

  # folder "work"
  home.file."work" = {
    recursive = true;
    source = ./config/work;
  };

  programs.git.signing = { key = "381AE25298A4EFF6"; };
}
