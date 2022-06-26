# Common macOS configuration
{ config, pkgs, ... }: {
  imports = [ ./config/home.nix ./config/alacritty.nix ];
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    elmPackages.elm
    elmPackages.elm-format

    # black - currently broken...
    nodejs
    nixfmt
    pinentry_mac
    (pkgs.nerdfonts.override { fonts = [ "Hasklig" ]; })
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
      '';
    };
  };
}
