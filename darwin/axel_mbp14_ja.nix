# home-manager module for mbp14-ja-specific configuration
# see mbp.nix for common macOS configuration
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./mbp.nix
    ../config/linear.nix
    ../config/aikido.nix
    ../config/publish-report.nix
  ];

  programs.claude-code = {
    # Auto mode (permissions.defaultMode) is set for both machines in
    # ../config/claude-code.nix; Remote Control is wanted only on this one.
    settings.remoteControlAtStartup = true;

    mcpServers = {
      vanta = {
        type = "http";
        url = "https://mcp.eu.vanta.com/mcp";
      };
    };
  };

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

  programs.k9s =
    let
      palette = import ../config/rose-pine.nix;
      skin = import ../config/k9s-skin.nix;
    in
    {
      enable = true;
      skins = {
        rose-pine = skin palette.main;
        rose-pine-dawn = skin palette.dawn;
      };
      settings = {
        # `theme sync` points skins/current.yaml at one of the two above
        k9s.ui.skin = "current";
      };
    };

  home.packages = [
    pkgs.kubie
    pkgs.gh
  ];
}
