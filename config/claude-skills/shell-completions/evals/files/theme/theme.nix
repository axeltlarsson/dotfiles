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
  theme = pkgs.writeShellApplication {
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
