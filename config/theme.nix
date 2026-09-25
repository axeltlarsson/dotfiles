# Light/dark switching driven by the macOS system appearance (darwin only).
#
# `theme toggle` — bound below to tmux prefix + T, and to <Leader>tt in neovim —
# flips the OS appearance. Almost everything then follows on its own: ghostty via
# `theme = "light:...,dark:..."`, bat and yazi by probing the terminal
# background, and the tmux status bar, fzf and the pure prompt because their
# colours are ANSI palette slots rather than hex. Only delta, k9s and running
# neovim instances need pushing, which is what `theme sync` does — including when
# the appearance is changed from System Settings rather than from here.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  unwrapped = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [
      pkgs.neovim
      pkgs.coreutils # timeout, mv, mkdir, ln
      pkgs.tmux # display-message, to surface errors from prefix + T
    ];
    # A launchd agent gets PATH=/usr/bin:/bin:/usr/sbin:/sbin and no XDG_* at
    # all, so pass these in rather than relying on the script's fallbacks
    # silently agreeing with home-manager's xdg paths.
    runtimeEnv = {
      XDG_STATE_HOME = config.xdg.stateHome;
      XDG_CONFIG_HOME = config.xdg.configHome;
    };
    text = builtins.readFile ./scripts/theme.sh;
  };

  # writeShellApplication emits only bin/. Copy it into one store path with the
  # completions: bash-completion looks for share/ next to the command's realpath.
  theme =
    pkgs.runCommand "theme"
      {
        nativeBuildInputs = [
          pkgs.installShellFiles
          pkgs.shellcheck-minimal
          pkgs.zsh
        ];
        inherit (unwrapped) meta;
      }
      ''
        # Only theme.sh is checked by writeShellApplication; the completions hard-code
        # its subcommands, so lint them and fail the build when they drift.
        zsh -n ${./scripts/completions/_theme}
        bash -n ${./scripts/completions/theme.bash}
        shellcheck -S warning ${./scripts/completions/theme.bash}
        sed -n 's/^\([a-z][a-z |]*\))$/\1/p' ${./scripts/theme.sh} | tr -d ' ' | tr '|' '\n' | sort >arms
        sed -n "s/^ *'\([a-z]*\):.*/\1/p" ${./scripts/completions/_theme} | sort |
          diff -u --label theme.sh --label _theme arms -
        sed -n 's/.*_theme__words \([a-z ]*\) ;;.*/\1/p' ${./scripts/completions/theme.bash} | tr ' ' '\n' | sort |
          diff -u --label theme.sh --label theme.bash arms -

        install -Dm755 ${unwrapped}/bin/theme $out/bin/theme
        installShellCompletion --cmd theme \
          --bash ${./scripts/completions/theme.bash} \
          --zsh ${./scripts/completions/_theme}
      '';
in
{
  home.packages = [ theme ];

  # lowercase t is swap-window (see tmux.nix). -E so a failure shows a reason
  # rather than a bare exit status.
  programs.tmux.extraConfig = lib.mkAfter /* tmux */ ''

    # prefix + T toggles light/dark system-wide
    bind-key T run-shell -bE '${theme}/bin/theme toggle'
  '';

  launchd.agents.theme-sync = {
    enable = true;
    config = {
      ProgramArguments = [
        "${theme}/bin/theme"
        "sync"
      ];
      # Generate the delta/k9s outputs at login if they're missing.
      RunAtLoad = true;
      # .GlobalPreferences.plist is rewritten when the appearance changes, and is
      # the primary trigger...
      WatchPaths = [ "${config.home.homeDirectory}/Library/Preferences/.GlobalPreferences.plist" ];
      # ...but cfprefsd caches writes, so poll as a backstop. `theme sync` exits
      # early when nothing changed, so a tick is a `defaults read` and a compare.
      StartInterval = 60;
      # Otherwise a failing sync under launchd is completely silent.
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/theme-sync.log";
    };
  };
}
