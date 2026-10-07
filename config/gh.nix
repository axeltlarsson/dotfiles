{ pkgs, ... }:
{
  # gh finds extensions in its data dir, not on PATH, so gh-stack has to be
  # declared here rather than added to home.packages.
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      aliases.co = "pr checkout";
    };
    extensions = [ pkgs.gh-stack ];
  };
}
