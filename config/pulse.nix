{ config, pkgs, ... }:
let
  pulse = pkgs.writers.writePython3Bin "pulse" {
    libraries = [ pkgs.python3Packages.boto3 ];
    flakeIgnore = [
      "E501"
      "W503"
      "E203"
    ];
  } (builtins.readFile ./claude-skills/pulse/pulse.py);

  # Opens a fresh "pulse" window in tmux session "local" running `claude /pulse`,
  # so the report is waiting there with a live session for follow-ups.
  pulse-morning = pkgs.writeShellApplication {
    name = "pulse-morning";
    runtimeInputs = [ pkgs.tmux ];
    text = ''
      tmux start-server
      if ! tmux has-session -t local 2>/dev/null; then
        tmux new-session -d -s local \; set-option -t local destroy-unattached off
      fi
      tmux kill-window -t local:pulse 2>/dev/null || true
      # login shell: launchd's env lacks the PATH and secrets zsh sets up
      tmux new-window -d -t local: -n pulse -c "$HOME/work" \
        "zsh -lic 'claude /pulse; exec zsh -l'"
    '';
  };
in
{
  home.packages = [
    pulse
    pulse-morning
  ];
  programs.claude-code.skills.pulse = ./claude-skills/pulse;
  programs.claude-code.settings.sandbox.excludedCommands = [ "pulse *" ];

  # A missed slot (asleep at 08:30) fires on wake.
  launchd.agents.pulse-morning = {
    enable = true;
    config = {
      ProgramArguments = [ "${pulse-morning}/bin/pulse-morning" ];
      StartCalendarInterval = map (Weekday: {
        inherit Weekday;
        Hour = 8;
        Minute = 30;
      }) [ 1 2 3 4 5 ];
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/pulse-morning.log";
    };
  };
}
