# home-manager module for mbp14-specific configuration,
# see mbp.nix for common macOS configuration

{ config, pkgs, ... }:
{
  imports = [ ./mbp.nix ];

  programs.git.signing = {
    key = "~/.ssh/id_ed25519.pub";
  };

  home.file.".config/git/allowed_signers".text = ''
    ${config.programs.git.settings.user.email} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTagaZ9d/J57JmYQja2uUiDj6PKctEJCvHg/vhkEuIN mail@axellarsson.nu
  '';
}
