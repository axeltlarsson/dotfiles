{ config, lib, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  # Enable OpenSSH out of the box.
  services.sshd.enable = true;

  time.timeZone = "Europe/Stockholm";

  system.autoUpgrade.enable = true;

  users.users = {
    axel = {
      isNormalUser = true;
      extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
      home = "/home/axel";
      description = "Axel Larsson";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID8afXGSxXnnz5ydf/AHGH65b2SpHvd1bEE6Q5JASQIM axel@axel-mbp16 "
      ];
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

  # Use a default root SSH login.
  # services.openssh.permitRootLogin = "yes";
  # users.users.root.password = "nixos";

  # Wireless networking (1). You might want to enable this if your Pi is not attached via Ethernet.
  # networking.wireless = {
  #  enable = true;
  #  interfaces = [ "wlan0" ];
  #  networks = {
  #    "replace-with-my-wifi-ssid" = {
  #      psk = "replace-with-my-wifi-password";
  #    };
  #  };
  # };

  # Wireless networking (2). Enables `wpa_supplicant` on boot.
  # systemd.services.wpa_supplicant.wantedBy = lib.mkOverride 10 [ "default.target" ];

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

