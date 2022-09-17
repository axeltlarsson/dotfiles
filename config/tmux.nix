{ pkgs, ... }: {
  programs.tmux = {
    enable = true;

    clock24 = true;
    escapeTime = 0;
    extraConfig = let theme = import ./rose-pine.nix;
    in with theme; ''
      set-option -ga terminal-overrides ",xterm-256color:Tc"
      set -s default-terminal "xterm-256color"
      set -g mouse on
      set -g focus-events on
      # Match postgresql URLs, default url_search doesn't
      set -g @copycat_search_C-p '(https?://|git@|git://|ssh://|ftp://|postgresql://|file:///)[[:alnum:]?=%/_.:,;~@!#$&()*+-]*'
      # Theme
      set-window-option -g window-status-current-style fg='${base}',bg='${gold}'
    '';
    keyMode = "vi";
    plugins = with pkgs; [
      { plugin = tmuxPlugins.pain-control; }
      { plugin = tmuxPlugins.yank; }
      { plugin = tmuxPlugins.open; }
      { plugin = tmuxPlugins.copycat; }
    ];
    shell = "${pkgs.zsh}/bin/zsh";
  };
}
