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

  # Workaround: nix-darwin unconditionally creates /etc/ssh/ssh_config.d/100-nix-darwin.conf
  # even when extraConfig is empty. Empty files in the Nix store on macOS get rwxrwxrwx perms,
  # which causes OpenSSH to reject the file ("Bad owner or permissions"), breaking all SSH.
  # Setting a non-empty value ensures the store file gets proper r--r--r-- permissions.
  # Upstream: https://github.com/nix-darwin/nix-darwin/issues/913
  programs.ssh.extraConfig = "# nix-darwin managed";

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
      enable = false;
      ephemeral = true;
      maxJobs = 4;
      # Bootstrap with defaults first, then restore custom VM config:
      # config.virtualisation = {
      #   darwin-builder = { diskSize = 10 * 1024; memorySize = 8 * 1024; };
      #   cores = 6;
      # };
    };
  };

  nixpkgs.overlays = [
    (import ../overlays/python.nix)
    (import ../overlays/tmux-plugins.nix)
  ];

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code-bin"
      "1password-cli"
    ];

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true; # Needed for TouchID to work in tmux
  };

  # Multi-monitor: each display has its own Spaces (fullscreen won't blank other monitors)
  system.defaults.spaces.spans-displays = false;

  # Tailscale SSH with mosh setup
  services.tailscale.enable = true;
  services.openssh.enable = false; # allow access through tailscale only
  environment.systemPackages = with pkgs; [
    tailscale
    mosh
  ];
}
