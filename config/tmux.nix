{ pkgs, ... }: {
  programs.tmux = {
    enable = true;

    clock24 = true;
    escapeTime = 0;
    extraConfig = ''
      set-option -ga terminal-overrides ",xterm-256color:Tc"
      set -s default-terminal "xterm-256color"
      set -g mouse on
      set -g focus-events on
      # Match postgresql URLs, default url_search doesn't
      set -g @copycat_search_C-p '(https?://|git@|git://|ssh://|ftp://|postgresql://|file:///)[[:alnum:]?=%/_.:,;~@!#$&()*+-]*'

      # prefix + left/right swaps window left/right
      bind-key left swap-window -t -1 -d
      bind-key right swap-window -t +1 -d
      # prefix + t swaps window to "top"
      bind-key t swap-window -t 0 -d

      # prefix + b swaps to last pane
      bind-key b last-pane

      # https://github.com/tmux/tmux/issues/4240
      set -gu default-command
      set -g default-shell "${pkgs.zsh}/bin/zsh"
    '';
    keyMode = "vi";
    plugins = with pkgs; [
      { plugin = tmuxPlugins.pain-control; }
      { plugin = tmuxPlugins.yank; }
      { plugin = tmuxPlugins.open; }
      { plugin = tmuxPlugins.copycat; }
      {
        plugin = tmuxPlugins.rose-pine;
        extraConfig = ''
          set -g @rose_pine_variant 'main'
          set -g @rose_pine_date_time '%Y-%m-%d %H:%M'
          set -g @rose_pine_directory 'on'
          set -g @rose_pine_disable_active_window_menu 'on'
        '';
      }
    ];
    shell = "${pkgs.zsh}/bin/zsh";
  };
}
