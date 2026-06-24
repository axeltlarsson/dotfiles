{ pkgs }:
let
  version = "2026-03-19";
  src = pkgs.fetchFromGitHub {
    owner = "pbakaus";
    repo = "impeccable";
    rev = "d2ab4ddee6fa63002fae680652b5fbd31735e280";
    hash = "sha256-r13nUfAlDXNckyY+9+AldJNY8RQNy0gk97xQpcWGSsc=";
  };
in
{
  pname = "impeccable-claude-skills";
  inherit version src;
  description = "Design fluency skills for Claude Code";
  homepage = "https://impeccable.style";
  license = "Apache-2.0";
  skills.impeccable = "${src}/.claude/skills/impeccable";
}
