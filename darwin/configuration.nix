# common nix-darwin configuration.nix
{ pkgs, inputs, ... }: {
  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 4;
  system.configurationRevision =
    inputs.self.rev or inputs.self.dirtyRev or null;

  programs.zsh.enable = true;

  nix = {
    package = pkgs.nix;
    settings.experimental-features = "nix-command flakes";
    settings.trusted-users = [ "axel" ];
    settings.system-features = [ "nixos-test" "apple-virt" ];
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

  security.pam.enableSudoTouchIdAuth = true;
}
