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

  # OSC 8 hyperlinks, bare URLs and paths: fzf picker and in-buffer jump.
  # The awk stages and icon table sit next to the script.
  tmuxLinks = pkgs.writeShellApplication {
    name = "tmux-links";
    runtimeInputs = [
      pkgs.tmux
      pkgs.fzf
      pkgs.gawk
      pkgs.coreutils
      pkgs.findutils
      # preview (images also need macOS sips and a kitty-graphics terminal)
      pkgs.bat
      pkgs.file
    ];
    runtimeEnv.TMUX_LINKS_LIB = "${./scripts/tmux-links}";
    text = builtins.readFile ./scripts/tmux-links/main.sh;
  };
in
{
  home.packages = [
    tmuxBufferManager
    tmuxLinks
  ];

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
      # tmux only forwards OSC 8 hyperlinks outward when the client terminal
      # advertises Hls, and ghostty's terminfo has no such capability.
      set -as terminal-features ",xterm-ghostty:hyperlinks"

      set -g mouse on
      set -g focus-events on
      # lets kitty-graphics image previews (tmux-links, yazi) reach ghostty
      set -g allow-passthrough on

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

      # Buffer manager (fzf+bat): preview/paste/delete/save/load.
      # display-popup does not expand formats in its arguments, so #{pane_id}
      # and friends have to be resolved by run-shell first.
      bind-key B run-shell -b 'tmux display-popup -E -w 90% -h 85% -T buffers -d "#{pane_current_path}" "${tmuxBufferManager}/bin/tmux-buffer-manager #{pane_id} #{pane_current_path}"'

      # Links: prefix + O picks from a list, prefix + L highlights them in
      # place (n/N to cycle), copy-mode o/O opens the selection or the link
      # under the cursor and p previews it. o supersedes tmux-open's, which
      # cannot resolve OSC 8.
      bind-key O run-shell -b "${tmuxLinks}/bin/tmux-links pick '#{pane_id}'"
      bind-key L run-shell -b "${tmuxLinks}/bin/tmux-links jump '#{pane_id}'"
      bind-key -T copy-mode-vi o run-shell -b "${tmuxLinks}/bin/tmux-links open-at '#{pane_id}'"
      bind-key -T copy-mode-vi O run-shell -b "${tmuxLinks}/bin/tmux-links open-at '#{pane_id}'"
      bind-key -T copy-mode-vi p run-shell -b "${tmuxLinks}/bin/tmux-links preview-at '#{pane_id}'"
      unbind-key C-u

    '';
    keyMode = "vi";
    plugins = with pkgs; [
      { plugin = tmuxPlugins.pain-control; }
      { plugin = tmuxPlugins.yank; }
      { plugin = tmuxPlugins.open; }
      # URL search (C-u) is unbound below: tmux-links' prefix + L covers it,
      # and copycat's pattern glues comma-separated URLs into one match.
      { plugin = tmuxPlugins.copycat; }
      # The rose-pine plugin used to live here; the status line above replaces it
      # so that light/dark needs no re-run of a plugin script.
    ];
    shell = "${pkgs.zsh}/bin/zsh";
  };
}
