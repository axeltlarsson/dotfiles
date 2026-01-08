# common nix-darwin configuration.nix
{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 4;
  system.primaryUser = "axel";
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  programs.zsh.enable = true;

  nix = {
    package = pkgs.nix;
    settings.experimental-features = "nix-command flakes";
    settings.trusted-users = [ "axel" ];
    settings.system-features = [
      "nixos-test"
      "apple-virt"
    ];
    settings.substituters = [
      "https://cache.garnix.io"
      "https://postgrest.cachix.org"
      "https://aseipp-nix-cache.global.ssl.fastly.net"
    ];
    settings.trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "postgrest.cachix.org-1:icgW4R15fz1+LqvhPjt4EnX/r19AaqxiVV+1olwlZtI="
    ];
    linux-builder = {
      enable = true;
      ephemeral = true;
      maxJobs = 4;
      config = {
        # try to leave this blank first-time setup if facing issues
        # enable a NixOS VM
        virtualisation = {
          darwin-builder = {
            diskSize = 10 * 1024; # 10 Gib
            memorySize = 8 * 1024;
          };
          cores = 6;
        };
      };
    };
  };

  nixpkgs.overlays = [ (import ../overlays/python.nix) ];

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;  # Needed for TouchID to work in tmux
  };

  # Multi-monitor: each display has its own Spaces (fullscreen won't blank other monitors)
  system.defaults.spaces.spans-displays = false;
}
