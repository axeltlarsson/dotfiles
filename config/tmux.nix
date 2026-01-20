{ pkgs, ... }:

let
  # Buffer manager: list/preview/paste/delete/save/load with fzf
  # Script source is in config/scripts/tmux-buffer-manager.sh
  tmuxBufferManager = pkgs.writeShellApplication {
    name = "tmux-buffer-manager";
    runtimeInputs = [
      pkgs.tmux
      pkgs.fzf
      pkgs.bat
      pkgs.fd
      pkgs.coreutils
    ];
    text = builtins.readFile ./scripts/tmux-buffer-manager.sh;
  };
in
{
  home.packages = [ tmuxBufferManager ];

  programs.tmux = {
    enable = true;

    clock24 = true;
    escapeTime = 0;
    extraConfig = /* tmux */ ''
      # https://github.com/tmux/tmux/issues/4240
      set -gu default-command
      set -g default-shell "${pkgs.zsh}/bin/zsh"

      set -g default-terminal "tmux-256color"
      set -ga terminal-overrides ",alacritty:RGB"
      set -ga terminal-overrides ",xterm-ghostty:RGB"

      set -g mouse on
      set -g focus-events on

      # prefix + left/right swaps window left/right
      bind-key left swap-window -t -1 -d
      bind-key right swap-window -t +1 -d
      # prefix + t swaps window to "top"
      bind-key t swap-window -t 0 -d

      # prefix + b jumps to last window
      bind-key b last-window

      # notifications/monitoring for background activity and bells
      # Windows `other` than the current with activity are highlighted in the status line with symbol "#"
      setw -g monitor-activity on
      set -g activity-action other
      set -g visual-activity off

      # Windows `other` than the current ringing the bell are highlithed in the status line with symbol "!"
      setw -g monitor-bell on
      set -g bell-action other
      set -g visual-bell on

      # set 5 s display time for messages by default
      set -g display-time 5000

      # style message-display - use "Rose" as text colour to make it pop a bit more
      set -g message-style 'fg=#ebbcba,bold'

      # prefix + u shows popup terminal
      bind-key u display-popup -E -w 90% -h 85% -d '#{pane_current_path}' "$SHELL -l"

      # Buffer manager (fzf+bat): preview/paste/delete/save/load
      bind-key B display-popup -E -w 90% -h 85% -T "buffers" -d '#{pane_current_path}' \
        "${tmuxBufferManager}/bin/tmux-buffer-manager #{pane_id} #{pane_current_path}"

      # Match postgresql URLs, default url_search doesn't
      set -g @copycat_search_C-p '(https?://|git@|git://|ssh://|ftp://|postgresql://|file:///)[[:alnum:]?=%/_.:,;~@!#$&()*+-]*'

    '';
    keyMode = "vi";
    plugins = with pkgs; [
      { plugin = tmuxPlugins.pain-control; }
      { plugin = tmuxPlugins.yank; }
      { plugin = tmuxPlugins.open; }
      { plugin = tmuxPlugins.copycat; }
      {
        plugin = tmuxPlugins.rose-pine;
        extraConfig = /* tmux */ ''
          set -g @rose_pine_variant 'main'
          set -g @rose_pine_date_time '%Y-%m-%d %H:%M'
          set -g @rose_pine_directory 'on'
          set -g @rose_pine_disable_active_window_menu 'on'
          set -g @rose_pine_status_left_append_section ' '
        '';
      }
    ];
    shell = "${pkgs.zsh}/bin/zsh";
  };
}
