# Shared by tmux.nix (status line) and claude-code.nix (hooks)
{ pkgs }:
pkgs.writeShellApplication {
  name = "tmux-ps";
  runtimeInputs = [
    pkgs.tmux
    pkgs.jq
    pkgs.coreutils
  ];
  text = builtins.readFile ./scripts/tmux-ps.sh;
}
