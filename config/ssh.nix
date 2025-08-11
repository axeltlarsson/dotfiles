{ pkgs, config, ... }:
{
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";

    extraConfig = ''
      ServerAliveInterval 15
      ServerAliveCountMax 3
      # `ssh-add --apple-load-keychain` might be required after reboot
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
}
