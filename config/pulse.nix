{ pkgs, ... }:
let
  pulse = pkgs.writers.writePython3Bin "pulse" {
    flakeIgnore = [
      "E501"
      "W503"
      "E203"
    ];
  } (builtins.readFile ./claude-skills/pulse/pulse.py);
in
{
  home.packages = [ pulse ];
  programs.claude-code.skills.pulse = ./claude-skills/pulse;
  programs.claude-code.settings.sandbox.excludedCommands = [ "pulse *" ];
}
