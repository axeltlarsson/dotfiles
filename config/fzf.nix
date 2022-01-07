{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "rg --files --hidden --follow --glob '!.git/*'";
    defaultOptions = let
      # Rose Pine palette https://rosepinetheme.com/palette.html#rose-pine
      base = "#191724";
      surface = "#1f1d2e";
      overlay = "#26233a";
      inactive = "#555169";
      subtle = "#6e6a86";
      text = "#e0def4";
      love = "#eb6f92";
      gold = "#f6c177";
      rose = "#ebbcba";
      pine = "#31748f";
      foam = "#9ccfd8";
      iris = "#c4a7e7";
      highlight = "#2a2837";
      highlightInactive = "#211f2d";
      highlightOverlay = "#3a384a";

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
    in [
      "--height 40%"
      "--border"
      "--color=fg:${text},bg:${surface}"
      "--color=hl:${foam},fg+:${text},bg+:${highlight}"
      "--color=hl+:${gold}"
      "--color=query:${gold}"
      "--color=spinner:${foam},header:${gold}"
      "--color=info:${pine},pointer:${gold}"
      "--color=marker:${pine},prompt:${iris}"
    ];

    tmux.enableShellIntegration = true;
  };
}
