{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "rg --files --hidden --follow --glob '!.git/*'";
    defaultOptions = let
      # Base16 Tomorrow Night
      # Author: Chris Kempson (http://chriskempson.com)
      color00 = "#1d1f21";
      color01 = "#282a2e";
      color02 = "#373b41";
      color03 = "#969896";
      color04 = "#b4b7b4";
      color05 = "#c5c8c6";
      color06 = "#e0e0e0";
      color07 = "#ffffff";
      color08 = "#cc6666";
      color09 = "#de935f";
      color0A = "#f0c674";
      color0B = "#b5bd68";
      color0C = "#8abeb7";
      color0D = "#81a2be";
      color0E = "#b294bb";
      color0F = "#a3685a";
    in [
      "--height 40%"
      "--border"
      "--color=bg+:${color01},bg:${color00},spinner:${color0C},hl:${color0D}"
      "--color=fg:${color04},header:${color0D},info:${color0A},pointer:${color0C}"
      "--color=marker:${color0C},fg+:${color06},prompt:${color0A},hl+:${color0D}"
    ];

    tmux.enableShellIntegration = true;
  };
}
