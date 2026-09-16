{ pkgs }:
let
  version = "skill-v4.3.1";
  engineVersion = "0.1.5";

  src = pkgs.fetchFromGitHub {
    owner = "pbakaus";
    repo = "impeccable";
    rev = version;
    hash = "sha256-EZ5bRlN38nRQM0a3eQYeOkbT7RjCmY0KMJgktnL14rQ=";
  };

  engines = {
    aarch64-darwin = {
      asset = "darwin-arm64";
      hash = "sha256-DUi24WqpdmT9vmB9XamuMg44mhhD4P8TKPjCUwUwMg0=";
    };
    x86_64-darwin = {
      asset = "darwin-x64";
      hash = "sha256-FTlxsMAHGd/566wTNwy327vhKDi2lvuvP3qwsbNya1I=";
    };
    aarch64-linux = {
      asset = "linux-arm64";
      hash = "sha256-vE+ii8jMuwGHlamaTs6VraiYpvGIXxQoE4nQ5u8qL5g=";
    };
    x86_64-linux = {
      asset = "linux-x64";
      hash = "sha256-z1IxpLGuZplshbAzgAsdrQeX5ZDq4vIe8leUMK8Yfxk=";
    };
  };

  inherit (pkgs.stdenv.hostPlatform) system;
  engine =
    engines.${system}
      or (throw "impeccable: no engine binary published for ${system}");

  engineBin = pkgs.fetchurl {
    url = "https://github.com/pbakaus/impeccable/releases/download/engine-v${engineVersion}/impeccable-${engine.asset}";
    inherit (engine) hash;
  };

  skill = pkgs.runCommand "impeccable-skill-${version}" { } ''
    cp -r ${src}/.claude/skills/impeccable $out
    chmod -R u+w $out

    # The launcher execs scripts/bin/<os>-<arch>/impeccable before it ever reads
    # scripts/VERSION, so a stale binary here would be used silently.
    want=$(tr -d '[:space:]' < $out/scripts/VERSION)
    if [ "$want" != "${engineVersion}" ]; then
      echo "impeccable: skill ${version} wants engine $want, packaged ${engineVersion}" >&2
      exit 1
    fi

    install -Dm755 ${engineBin} $out/scripts/bin/${engine.asset}/impeccable
  '';
in
{
  pname = "impeccable-claude-skills";
  inherit version src;
  description = "Design fluency skills for Claude Code";
  homepage = "https://impeccable.style";
  license = "Apache-2.0";
  skills.impeccable = skill;
}
