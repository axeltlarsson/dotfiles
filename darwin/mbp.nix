# home-manager common macOS configuration
{ config, pkgs, lib, ... }: {
  imports = [ ../config/home.nix ../config/alacritty.nix ];

  home = {
    username = "axel";
    homeDirectory = lib.mkForce "/Users/axel";
    stateVersion = "21.11";
  };

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    # shell
    shellcheck
    shfmt

    # python
    ruff

    nodejs
    pinentry_mac
    (pkgs.nerdfonts.override { fonts = [ "Hasklig" ]; })
    cachix
  ];

  home.sessionPath = [ "${config.home.homeDirectory}/.npm-packages/bin" ];

  home.file.".npmrc".source = ../config/npmrc.conf;
  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${pkgs.pinentry_mac}/Applications/pinentry-mac.app/Contents/MacOS/pinentry-mac
  '';

  programs = {
    # TODO: use SSH keys for GH instead
    gpg = { enable = true; };

    # TODO: probably want this ssh config for all my machines, so could move to config/home.nix
    ssh = {
      enable = true;
      extraConfig = ''
        ServerAliveInterval 15
        ServerAliveCountMax 3
        # `ssh-add --apple-load-keychain` might be required after reboot
        AddKeysToAgent yes
        UseKeychain yes

        IdentityFile ~/.ssh/id_ed25519

        HOST andrimner
          HostName andrimner.axellarsson.nu
          Port 1022
          IdentityFile ~/.ssh/id_ed25519

        HOST andrimner_local
          HostName 192.168.0.160
          IdentityFile ~/.ssh/id_ed25519

        HOST unlock_andrimner_local
          HostName 192.168.0.160
          User root
          HostKeyAlias unlock_andrimner
          IdentityFile ~/.ssh/andrimner_dropbear

        HOST unlock_andrimner
          HostName andrimner.axellarsson.nu
          Port 1022
          HostKeyAlias unlock_andrimner
          User root
          IdentityFile ~/.ssh/andrimner_dropbear

        HOST nixpi
          HostName nixpi.local
          User axel
          IdentityFile ~/.ssh/id_ed25519

        HOST leif
          HostName leif.arthro.ai
          Port 1022
          User axel
          IdentityFile ~/.ssh/id_ed25519

        HOST unlock_leif
          HostName 192.168.128.94
          HostName leif.arthro.ai
          User root
          HostKeyAlias unlock_leif
          IdentityFile ~/.ssh/leif_dropbear
      '';
    };
  };

  nix.settings = {
    netrc-file = "${config.home.homeDirectory}/.config/nix/netrc";
  };
}
