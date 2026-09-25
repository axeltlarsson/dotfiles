{
  pkgs,
  ...
}:
let
  script = ./claude-skills/publish-report/publish_report.py;
  zshCompletion = ./scripts/completions/_publish-report;
  bashCompletion = ./scripts/completions/publish-report.bash;

  unwrapped = pkgs.writers.writePython3Bin "publish-report" {
    libraries = [ pkgs.python3Packages.boto3 ];
    flakeIgnore = [
      "E501"
      "W503"
    ];
  } (builtins.readFile script);

  # bash-completion looks for share/ next to the command's realpath, so ship both in one path
  publish-report =
    pkgs.runCommand "publish-report"
      {
        nativeBuildInputs = [
          pkgs.installShellFiles
          pkgs.shellcheck-minimal
          pkgs.zsh
        ];
        meta = unwrapped.meta or { };
      }
      ''
        # The completions hard-code argparse's long options: fail the build when they drift
        zsh -n ${zshCompletion}
        bash -n ${bashCompletion}
        shellcheck -S warning ${bashCompletion}
        grep -oE '"--[a-z-]+"' ${script} | tr -d '"' | sort >opts
        sed -n "s/^ *'\(--[a-z-]*\)[=[].*/\1/p" ${zshCompletion} | sort |
          diff -u --label publish_report.py --label _publish-report opts -
        sed -n 's/.*for o in -h --help \(.*\); do/\1/p' ${bashCompletion} | tr ' ' '\n' | tr -d = | sort |
          diff -u --label publish_report.py --label publish-report.bash opts -

        install -Dm755 ${unwrapped}/bin/publish-report $out/bin/publish-report
        installShellCompletion --cmd publish-report \
          --bash ${bashCompletion} \
          --zsh ${zshCompletion}
      '';
in
{
  home.packages = [ publish-report ];
  programs.claude-code.skills."publish-report" = ./claude-skills/publish-report;
}
