{ config, lib, pkgs, ... }:

{
  imports = [
    # Use Nixos/nixos-hardware to configure the RPI 4 hw
    "${
      builtins.fetchGit { url = "https://github.com/NixOS/nixos-hardware.git"; }
    }/raspberry-pi/4"
  ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  # Enable OpenSSH out of the box.
  services.sshd.enable = true;

  time.timeZone = "Europe/Stockholm";

  system.autoUpgrade.enable = true;

  users = {
    mutableUsers = false;
    users = {
      axel = {
        shell = pkgs.zsh;
        isNormalUser = true;
        extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
        home = "/home/axel";
        password = "duh"; # or initialHashedPassword?
        description = "Axel Larsson";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID8afXGSxXnnz5ydf/AHGH65b2SpHvd1bEE6Q5JASQIM axel@axel-mbp16 "
        ];
      };
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.avahi = {
    enable = true;
    nssmdns = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };
  };

  # packages to install
  environment.systemPackages = with pkgs; [ vim ];
  environment.variables = { EDITOR = "vim"; };

  networking.hostName = "nixpi";

  nix = {
    autoOptimiseStore = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    # Free up to 1GiB whenever there is less than 100MiB left.
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
  };

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;
  networking.interfaces.wlan0.useDHCP = true;

  # NTP time sync.
  services.timesyncd.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.03"; # Did you read the comment?
}

