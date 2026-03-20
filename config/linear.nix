{
  pkgs,
  ...
}:
let
  linear = pkgs.writers.writePython3Bin "linear" {
    libraries = [ pkgs.python3Packages.httpx ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./claude-skills/linear/linear.py);
in
{
  home.packages = [ linear ];
  programs.claude-code.skills.linear = ./claude-skills/linear;
}
