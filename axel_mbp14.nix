# mbp14-specific configuration goes here, see mbp.nix for common macOS configuration
{ config, pkgs, ... }: {
  imports = [ ./mbp.nix ];
  programs.git.signing = { key = "962B43506E2DAB3C"; };
  programs.git.userEmail = "mail@axellarsson.nu";
}
