{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "rg --files --hidden --follow --glob '!.git/*'";
    defaultOptions = let
      theme = import ./rose-pine.nix;
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
    in with theme; [
      "--height 40%"
      "--border"
      "--color=fg:${text},bg:${surface}"
      "--color=hl:${muted},fg+:${subtle},bg+:${base}"
      "--color=hl+:${subtle}"
      "--color=query:${gold}"
      "--color=spinner:${love},header:${rose}"
      "--color=info:${foam},pointer:${iris}"
      "--color=marker:${rose},prompt:${gold}"
    ];

    tmux.enableShellIntegration = true;
  };
}
