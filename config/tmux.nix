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

      # Windows `other` than the current ringing the bell are highlithed in the status line with symbol "!"
      setw -g monitor-bell on
      set -g bell-action other
      set -g visual-bell on

      # set 3 s display time for messages by default
      set -g display-time 3000

      # === Rosé Pine status line ===
      # Transcribed from the rose-pine tmux plugin's output, with every hex
      # replaced by the ANSI palette slot holding that role, so the bar follows
      # whatever palette the terminal has loaded (main or dawn) with no reload
      # and no plugin. Slots, per rosepinetheme.com, in both variants:
      #   0 overlay  1 love  2 pine  3 gold  4 foam  5 iris  6 rose  7 text  8 muted
      # bg=default means the terminal's own background, so the bar always blends.
      set -g status on
      set -g status-justify left
      set -g status-left-length 200
      set -g status-right-length 200
      set -g status-style 'fg=colour2,bg=default'
      set -g status-left '#[fg=#{?client_prefix,colour1,colour7}] #[fg=colour7]#S#[fg=colour7]    '
      set -g status-right '#[fg=colour4]%Y-%m-%d %H:%M#[fg=colour8]  #[fg=colour8]󰃰 #[fg=colour7]#[fg=colour7]  #[fg=colour8] #[fg=colour6]#{b:pane_current_path}'

      setw -g window-status-separator '  '
      setw -g window-status-format '#I:#W#{?window_flags,#{window_flags}, }'
      setw -g window-status-current-format '#I:#W#{?window_flags,#{window_flags}, }'
      setw -g window-status-style 'fg=colour5,bg=default'
      setw -g window-status-current-style 'fg=colour3,bg=default'
      # reverse rather than a hardcoded fg/bg pair: swapping the terminal's own
      # colours is the only inversion that stays legible in both variants
      setw -g window-status-activity-style 'fg=colour6,reverse'

      set -g pane-border-style 'fg=colour8'
      set -g pane-active-border-style 'fg=colour3'
      set -g display-panes-colour colour3
      set -g display-panes-active-colour colour7

      # use "Rose" as message text colour to make it pop a bit more.
      # fill= is what paints the rest of the status line while a prompt is up
      # (tmux's default is bg=yellow,fg=black,fill=yellow) — without it,
      # `prefix + ,` leaves the old window list showing through the prompt.
      # fill=terminal, not fill=default: `default` inherits and paints nothing.
      set -g message-style 'fg=colour6,bold,bg=default,fill=terminal'
      set -g message-command-style 'fg=colour0,bg=colour3,fill=colour3'

      # prefix + u shows popup terminal
      bind-key u display-popup -E -w 90% -h 85% -d '#{pane_current_path}' "$SHELL -l"

      # Buffer manager (fzf+bat): preview/paste/delete/save/load
      bind-key B display-popup -E -w 90% -h 85% -T "buffers" -d '#{pane_current_path}' \
        "${tmuxBufferManager}/bin/tmux-buffer-manager #{pane_id} #{pane_current_path}"

    '';
    keyMode = "vi";
    plugins = with pkgs; [
      { plugin = tmuxPlugins.pain-control; }
      { plugin = tmuxPlugins.yank; }
      { plugin = tmuxPlugins.open; }
      {
        plugin = tmuxPlugins.copycat;
        # Overrides the C-u URL search. Must be set before copycat.tmux runs,
        # hence here and not in extraConfig, which lands after every run-shell.
        # Copycat's own pattern allows `,()` mid-URL, so it swallows trailing
        # `),` and glues comma-separated URLs into one match.
        extraConfig = ''
          set -g @copycat_search_C-u '(https?://|postgresql://|git@|git://|ssh://|ftp://|file:///)[[:alnum:]?=%/_.:~@!#$&*+-]*[[:alnum:]/#=_&+-]'
        '';
      }
      # The rose-pine plugin used to live here; the status line above replaces it
      # so that light/dark needs no re-run of a plugin script.
    ];
    shell = "${pkgs.zsh}/bin/zsh";
  };
}
