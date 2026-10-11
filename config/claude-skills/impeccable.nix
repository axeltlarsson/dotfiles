{ pkgs }:
let
  version = "skill-v4.5.2";
  engineVersion = "0.1.14";

  src = pkgs.fetchFromGitHub {
    owner = "pbakaus";
    repo = "impeccable";
    rev = version;
    hash = "sha256-0QpNzNnSon34/VVPPaitnSTBjpu9qJGXJzCJctS4gM0=";
  };

  engines = {
    aarch64-darwin = {
      asset = "darwin-arm64";
      hash = "sha256-q71p1UBTK5HpWZxB06YSffuquuXiS6/XT/fi+xj0+Hw=";
    };
    x86_64-darwin = {
      asset = "darwin-x64";
      hash = "sha256-36RXAwmTn0lhWkQbqpxz8cLTOb8HSUUXpsbrLrKKoPU=";
    };
    aarch64-linux = {
      asset = "linux-arm64";
      hash = "sha256-OWJj7mlHgNuUJIP8gJM6AS7wi/mB9fJrDaXha2IIyUg=";
    };
    x86_64-linux = {
      asset = "linux-x64";
      hash = "sha256-PTHsGmZKw1yBXqHXwQq60RVc42TQ9GEVfrg3o0No77Y=";
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
