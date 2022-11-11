# mbp14-ja-specific configuration goes here, see mbp.nix for common macOS configuration
{ config, pkgs, ... }: {
  imports = [ ./mbp.nix ];

  # folder "work"
  home.file."work" = {
    recursive = true;
    source = ./config/work;
  };

  # https://github.com/nix-community/home-manager/issues/2942
  nixpkgs.config.allowUnfreePredicate = (pkg: true);
  home.packages = with pkgs; [ _1password-gui ];
  programs.git.signing = { key = "381AE25298A4EFF6"; };
}
