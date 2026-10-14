{
  pkgs,
  ...
}:
let
  linear = pkgs.writers.writePython3Bin "linear" {
    libraries = [ pkgs.python3Packages.httpx ];
    flakeIgnore = [
      "E501"
      "W503"
    ];
  } (builtins.readFile ./claude-skills/linear/linear.py);
in
{
  home.packages = [ linear ];
  programs.claude-code.skills.linear = ./claude-skills/linear;
  programs.claude-code.settings.sandbox.excludedCommands = [ "linear *" ];

  # Scoped to the work machine (this module is only imported there). Merges
  # into the shared context via the `lines` type.
  programs.claude-code.context = ''
    - Tickets live in Linear - use the `linear` skill to read/manage them. Never use the Atlassian/Jira MCP unless explicitly asked
    - Never put Linear ticket IDs in PR titles (not "Split X into a package (DAT-1628)", just "Split X into a package"). The branch name links the PR to the ticket: use Linear's `branchName` (`linear issue DAT-123 --fields branchName`)
  '';
}
