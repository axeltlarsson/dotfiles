{
  pkgs,
  ...
}:
let
  aikido = pkgs.writers.writePython3Bin "aikido" {
    libraries = [ pkgs.python3Packages.httpx ];
    flakeIgnore = [
      "E501"
      "W503"
    ];
  } (builtins.readFile ./claude-skills/aikido/aikido.py);
in
{
  home.packages = [ aikido ];
  programs.claude-code.skills."aikido" = ./claude-skills/aikido;
}
