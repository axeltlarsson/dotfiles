{
  pkgs,
  ...
}:
let
  kleer = pkgs.writers.writePython3Bin "kleer" {
    libraries = [ pkgs.python3Packages.httpx ];
    flakeIgnore = [
      "E501"
      "W503"
    ];
  } (builtins.readFile ./claude-skills/kleer/kleer.py);
in
{
  # pdftotext, for reading amounts and invoice numbers out of receipt PDFs
  home.packages = [
    kleer
    pkgs.poppler-utils
  ];
  programs.claude-code.skills."kleer" = ./claude-skills/kleer;
}
