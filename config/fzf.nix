{
  # TODO: use https://github.com/rose-pine/fzf
  # basically it's just:
  # --color=fg:#e0def4,bg:#1f1d2e,hl:#6e6a86
  # --color=fg+:#908caa,bg+:#191724,hl+:#908caa
  # --color=info:#9ccfd8,prompt:#f6c177,pointer:#c4a7e7
  # --color=marker:#ebbcba,spinner:#eb6f92,header:#ebbcba"
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
