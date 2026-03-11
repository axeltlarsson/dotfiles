{ pkgs, config, ... }:
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";

    defaultKeymap = "viins";
    enableCompletion = true;

    autosuggestion.enable = true;

    # Use fast-syntax-highlighting (F-Sy-H) instead of zsh-syntax-highlighting:
    # faster, better per-command chroma highlighting. Loaded via initContent.

    historySubstringSearch = {
      enable = true;
    };

    history = {
      size = 10000;
      save = 10000;
      path = "${config.xdg.configHome}/zsh/.zsh_history";
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      extended = true;
      share = true;
      findNoDups = true;
      saveNoDups = true;
    };

    sessionVariables = {
      EDITOR = "${pkgs.neovim}/bin/nvim";
      VISUAL = "${pkgs.neovim}/bin/nvim";
      GPG_TTY = "$(tty)";
      KEYTIMEOUT = 1;
      NOTES_DIR = "${config.home.homeDirectory}/Google Drive/My Drive/notes";
      WORDCHARS = "*?_-.[]~&;!#$%^(){}<>";
    };

    shellAliases = {
      vi = "nvim";
      vim = "nvim";
      "-" = "cd -";
    };

    initContent = ''
      # === Options (from prezto environment + directory modules) ===
      setopt nonomatch           # allow `nix run nixpkgs#whatever`
      setopt AUTO_CD             # cd by typing directory name
      setopt AUTO_PUSHD          # push dirs onto stack on cd
      setopt PUSHD_IGNORE_DUPS
      setopt PUSHD_SILENT
      setopt PUSHD_TO_HOME
      setopt CDABLE_VARS
      setopt MULTIOS
      setopt EXTENDED_GLOB
      setopt INTERACTIVE_COMMENTS
      setopt RC_QUOTES
      setopt LONG_LIST_JOBS
      setopt AUTO_RESUME
      setopt NOTIFY
      unsetopt CLOBBER           # don't overwrite with >
      unsetopt BG_NICE
      unsetopt HUP
      unsetopt CHECK_JOBS

      # === Smart URLs ===
      # Auto-quote special chars in URLs so `?`, `&`, etc. aren't globbed
      if [[ $TERM != dumb ]]; then
        autoload -Uz bracketed-paste-url-magic
        zle -N bracketed-paste bracketed-paste-url-magic
        autoload -Uz url-quote-magic
        zle -N self-insert url-quote-magic
      fi

      # === Fast syntax highlighting (replaces zsh-syntax-highlighting) ===
      source ${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh

      # === Vi mode enhancements ===
      autoload -Uz edit-command-line
      zle -N edit-command-line
      bindkey -M vicmd '^G' edit-command-line

      # fzf: make alt-c cd work https://github.com/junegunn/fzf/issues/164
      bindkey "ç" fzf-cd-widget

      # === Pure prompt ===
      fpath+=(${pkgs.pure-prompt}/share/zsh/site-functions)
      autoload -U promptinit; promptinit
      prompt pure

      # === Tmux autostart ===
      if [[ -z "$TMUX" && -z "$EMACS" && -z "$VIM" && -z "$INSIDE_EMACS" && -z "$VSCODE_RESOLVING_ENVIRONMENT" && "$TERM_PROGRAM" != "vscode" && -z "$SSH_TTY" ]]; then
        tmux start-server
        if ! tmux has-session 2>/dev/null; then
          tmux new-session -d -s "local" \; set-option -t "local" destroy-unattached off &>/dev/null
        fi
        exec tmux attach-session -d
      fi
    '';
  };
}
