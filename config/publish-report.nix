{
  pkgs,
  ...
}:
let
  publish-report = pkgs.writers.writePython3Bin "publish-report" {
    libraries = [ pkgs.python3Packages.boto3 ];
    flakeIgnore = [
      "E501"
      "W503"
    ];
  } (builtins.readFile ./claude-skills/publish-report/publish_report.py);
in
{
  home.packages = [ publish-report ];
  programs.claude-code.skills."publish-report" = ./claude-skills/publish-report;
}
