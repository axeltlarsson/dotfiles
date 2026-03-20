{ pkgs }:
let
  version = "2026-03-19";
  src = pkgs.fetchFromGitHub {
    owner = "pbakaus";
    repo = "impeccable";
    rev = "d6b1a56bc5b79e9375be0f8508b4daa1678fb058";
    hash = "sha256-xt9oIszoAwprFe3UKf4id+DLPoObWj0BRlIuTAldlvc=";
  };
  skillNames = [
    "adapt"
    "animate"
    "arrange"
    "audit"
    "bolder"
    "clarify"
    "colorize"
    "critique"
    "delight"
    "distill"
    "extract"
    "frontend-design"
    "harden"
    "normalize"
    "onboard"
    "optimize"
    "overdrive"
    "polish"
    "quieter"
    "teach-impeccable"
    "typeset"
  ];
in
{
  pname = "impeccable-claude-skills";
  inherit version src;
  description = "Design fluency skills for Claude Code";
  homepage = "https://impeccable.style";
  license = "Apache-2.0";
  skills = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = "${src}/.claude/skills/${name}";
    }) skillNames
  );
}
