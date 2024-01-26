# andrimner server config
{
  config,
  pkgs,
  ...
}: {
  imports = [./config/home.nix];
  programs.git.signing = {key = "52F093DF8ECCB62A";};

  home = {
    homeDirectory = "/home/axel";
    username = "axel";
    stateVersion = "21.11";
  };
}
