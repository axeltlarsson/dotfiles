{
  programs.fzf = {
    # N.B! `tmux kill-server` after changing — tmux caches env vars int is global server environment
    enable = true;
    # `fzf --zsh` output is baked into the zshrc at build time (see zsh.nix)
    enableZshIntegration = false;
    defaultCommand = "fd --type f | sort -r";
    # Colours are ANSI palette indices, not hex, so they follow whatever palette
    # ghostty has loaded (Rosé Pine main or dawn) with no reload. Rosé Pine maps
    # the same roles to the same slots in both variants:
    #   0 overlay  1 love  2 pine  3 gold  4 foam  5 iris  6 rose  7 text  8 muted
    # N.B. slots 9-15 are duplicates of 1-7 in this palette, so "bright" variants
    # buy nothing — the current line is distinguished by bg+ (overlay) instead.
    defaultOptions =
      let
        # fzf COLOR NAMES:
        # fg         Text
        # bg         Background
        # preview-fg Preview window text
        # preview-bg Preview window background
        # hl         Highlighted substrings
        # fg+        Text (current line)
        # bg+        Background (current line)
        # gutter     Gutter on the left (defaults to bg+)
        # hl+        Highlighted substrings (current line)
        # query      Query string
        # disabled   Query string when search is disabled
        # info       Info line (match counters)
        # border     Border around the window (--border and --preview)
        # prompt     Prompt
        # pointer    Pointer to the current line
        # marker     Multi-select marker
        # spinner    Streaming input indicator
        # header     Header
      in
      [
        "--height 40%"
        "--border"
        "--color=fg:7,bg:-1" # -1 = terminal default background
        "--color=hl:5,fg+:7,bg+:0"
        "--color=hl+:5"
        "--color=query:3"
        "--color=spinner:1,header:6"
        "--color=info:4,pointer:5"
        "--color=marker:6,prompt:3"
        "--color=border:8"
      ];

    # FileWidget Ctrl-T
    fileWidget.command = "fd --type f | sort -r";
    fileWidget.options = [
      "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
      "--layout=reverse"
      "--preview-window=right:60%"
    ];

    tmux.enableShellIntegration = true;
  };
}
