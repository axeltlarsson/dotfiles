# Common macOS configuration
{ config, pkgs, ... }: {
  imports = [ ./config/home.nix ./config/alacritty.nix ];

  home = {
    username = "axel";
    homeDirectory = "/Users/axel";
    stateVersion = "21.11";
  };

  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    elmPackages.elm
    elmPackages.elm-format

    # black - currently broken...
    nodejs
    nixfmt
    pinentry_mac
    (pkgs.nerdfonts.override { fonts = [ "Hasklig" ]; })
    cachix
  ];

  home.sessionPath = [ "${config.home.homeDirectory}/.npm-packages/bin" ];

  home.file.".npmrc".source = ./config/npmrc.conf;
  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${pkgs.pinentry_mac}/Applications/pinentry-mac.app/Contents/MacOS/pinentry-mac
  '';

  programs = {

    gpg = { enable = true; };

    ssh = {
      enable = true;
      extraConfig = ''
        AddKeysToAgent yes
        UseKeychain yes
        IdentityFile ~/.ssh/id_ed25519

        HOST andrimner
          HostName andrimner.axellarsson.nu
          Port 512
          AddKeysToAgent yes
          UseKeyChain yes
          IdentityFile ~/.ssh/id_ed25519

        HOST andrimner_local
          HostName 192.168.0.160
          AddKeysToAgent yes
          UseKeyChain yes
          IdentityFile ~/.ssh/id_ed25519

        HOST unlock_andrimner_local
          HostName 192.168.0.160
          User root
          HostKeyAlias unlock_andrimner
          IdentityFile ~/.ssh/andrimner_rsa_dropbear

        HOST unlock_andrimner
          HostName andrimner.axellarsson.nu
          Port 512
          HostKeyAlias unlock_andrimner
          User root
          IdentityFile ~/.ssh/andrimner_rsa_dropbear
      '';
    };
  };
}
