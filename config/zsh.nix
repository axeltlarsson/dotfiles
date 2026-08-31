{ pkgs, config, ... }:
let
  # `<tool> init zsh` output is a pure function of the package, so generate it
  # at build time instead of forking the tool at every shell startup
  # (~4 ms saved per tool per shell).
  zoxideInit = pkgs.runCommand "zoxide-init.zsh" { } ''
    ${config.programs.zoxide.package}/bin/zoxide init zsh > $out
  '';
  direnvHook = pkgs.runCommand "direnv-hook.zsh" { } ''
    ${config.programs.direnv.package}/bin/direnv hook zsh > $out
  '';
  fzfInit = pkgs.runCommand "fzf-init.zsh" { } ''
    ${config.programs.fzf.package}/bin/fzf --zsh > $out
  '';

  # Rosé Pine theme for zsh-patina. Colours are ANSI palette slots (like the
  # prompt and fzf) so highlighting follows the ghostty palette (main or dawn)
  # instantly. Slot roles: 0 overlay, 1 love, 2 pine, 3 gold, 4 foam, 5 iris,
  # 6 rose, 7 text, 8 muted. Scope layout mirrors patina's built-in default:
  # https://github.com/michel-kraemer/zsh-patina/blob/main/themes/patina.toml
  patinaTheme = pkgs.writeText "patina-rose-pine.toml" ''
    "comment" = "8"

    "string" = "3"
    "keyword.operator.regexp" = "3"
    "constant.character.escape" = "4"
    "constant.numeric.integer.decimal.file-descriptor" = "3"

    # -f/--flags
    "variable.parameter" = "5"

    # $VARIABLES
    "variable.other" = "4"
    "punctuation.definition.variable" = "4"

    # commands (static fallback when dynamic detection is off)
    "variable.function" = "6"
    "variable.language.tilde" = "5"

    # if/for/while, pipes, redirects, assignments, builtins
    "keyword" = "2"
    "storage" = "2"
    "support" = "2"

    "entity.name.function" = "6"
    "punctuation.section" = "3"
    "meta.group.expansion.history" = "3"

    # reset command substitutions to terminal defaults
    "meta.group.expansion.command.parens" = {}

    # dynamic detection: valid command / unknown command / existing path
    "dynamic.callable" = "6"
    "dynamic.callable.missing" = "1"
    "dynamic.path" = { underline = true }
  '';
in
{
  # After changing the theme or config, run `zsh-patina restart` so the daemon
  # picks it up (ANSI palette changes via ghostty need no restart).
  xdg.configFile."zsh-patina/config.toml".text = ''
    [highlighting]
    theme = "file:${patinaTheme}"
  '';

  # zsh sources a .zwc next to each startup file if present and newer; compile
  # on activation (the store copies are read-only, but the .zwc can live next
  # to the symlinks in ZDOTDIR). Saves ~5 ms of parsing per shell.
  home.activation.zcompileZshFiles = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    run ${pkgs.zsh}/bin/zsh -fc '
      for f in ${config.xdg.configHome}/zsh/.zshenv \
               ${config.xdg.configHome}/zsh/.zprofile \
               ${config.xdg.configHome}/zsh/.zshrc; do
        [[ -e $f ]] && zcompile -R "$f.zwc" "$f"
      done' || true
  '';

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";

    defaultKeymap = "viins";
    enableCompletion = false; # we handle compinit ourselves with dump caching

    autosuggestion.enable = true;

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
      GPG_TTY = "$TTY"; # zsh sets $TTY itself; $(tty) would fork
      KEYTIMEOUT = 1;
      NOTES_DIR = "${config.home.homeDirectory}/Google Drive/My Drive/notes";
      WORDCHARS = "*?_-.[]~&;!#$%^(){}<>";
    };

    shellAliases = {
      vi = "nvim";
      vim = "nvim";
      "-" = "cd -";
    };

    # Startup-fork shims: home-manager's generated .zshrc unconditionally runs
    # `mkdir -p "$(dirname "$HISTFILE")"` (two forks, ~6 ms). Shadow both with
    # builtins for the window between .zshenv and initContent; initContent
    # removes the shims again first thing.
    envExtra = ''
      if [[ -o interactive ]]; then
        zmodload -F zsh/files b:zf_mkdir
        mkdir() { zf_mkdir "$@" }
        dirname() { print -r -- "''${1:h}" }
      fi
    '';

    initContent = ''
      unfunction mkdir dirname 2>/dev/null # end of startup-fork shims (see envExtra)

      # zsh-autosuggestions by default re-wraps every zle widget on each precmd,
      # costing ~9 ms per prompt; bind once instead (all widgets exist before
      # the first precmd since every plugin loads from this file)
      ZSH_AUTOSUGGEST_MANUAL_REBIND=1

      # === Options ===
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
      unsetopt BG_NICE           # (also keeps the background zcompile below quiet)
      unsetopt HUP
      unsetopt CHECK_JOBS

      # === Completion (cached compinit — only regenerate dump once per day) ===
      autoload -Uz compinit
      _comp_dump="${config.xdg.configHome}/zsh/.zcompdump"
      if [[ -f "$_comp_dump" ]]; then
        # Regenerate if dump is older than 24h
        zmodload zsh/stat
        local -a _dump_stat
        zstat -A _dump_stat +mtime "$_comp_dump"
        if (( EPOCHSECONDS - _dump_stat[1] < 86400 )); then
          compinit -C -d "$_comp_dump"
        else
          compinit -d "$_comp_dump"
        fi
      else
        compinit -d "$_comp_dump"
      fi
      # keep a compiled copy of the dump; zsh loads .zwc ~2x faster
      if [[ -f "$_comp_dump" && ! "$_comp_dump.zwc" -nt "$_comp_dump" ]]; then
        zcompile "$_comp_dump" &!
      fi
      unset _comp_dump

      # === Smart URLs ===
      # Auto-quote special chars in URLs so `?`, `&`, etc. aren't globbed
      if [[ $TERM != dumb ]]; then
        autoload -Uz bracketed-paste-url-magic
        zle -N bracketed-paste bracketed-paste-url-magic
        autoload -Uz url-quote-magic
        zle -N self-insert url-quote-magic
      fi

      # === Syntax highlighting: zsh-patina (replaces fast-syntax-highlighting) ===
      # Rust daemon; ~25 ms less startup and ~4 ms less input lag than F-Sy-H.
      # The activate output embeds the runtime socket path, so it cannot be
      # baked at build time like the other integrations below.
      eval "$(${pkgs.zsh-patina}/bin/zsh-patina activate)"

      # === Vi mode enhancements ===
      autoload -Uz edit-command-line
      zle -N edit-command-line
      bindkey -M vicmd '^G' edit-command-line

      # === fzf (init baked at build time; enableZshIntegration is off) ===
      if [[ $options[zle] = on ]]; then
        ${builtins.readFile fzfInit}
      fi
      # fzf: make alt-c cd work https://github.com/junegunn/fzf/issues/164
      bindkey "ç" fzf-cd-widget

      # === zoxide (init baked at build time; enableZshIntegration is off) ===
      ${builtins.readFile zoxideInit}

      # === direnv (hook baked at build time; enableZshIntegration is off) ===
      ${builtins.readFile direnvHook}

      # === Pure prompt (rosé pine) ===
      # Ported from https://github.com/rose-pine/pure (fish, archived)
      # Colours are ANSI palette slots rather than hex, so the prompt follows the
      # ghostty palette (Rosé Pine main or dawn) instantly — no reload, and even
      # already-running shells adapt. See config/theme.nix.
      fpath+=(${pkgs.pure-prompt}/share/zsh/site-functions)
      zstyle ':prompt:pure:path' color 'cyan'                  # rose
      zstyle ':prompt:pure:git:branch' color '8'               # muted
      zstyle ':prompt:pure:git:branch:cached' color 'red'      # love
      zstyle ':prompt:pure:git:dirty' color 'red'              # love
      zstyle ':prompt:pure:git:arrow' color 'blue'             # foam
      zstyle ':prompt:pure:git:stash' color 'green'            # pine
      zstyle ':prompt:pure:git:action' color 'yellow'          # gold
      zstyle ':prompt:pure:execution_time' color 'yellow'      # gold
      zstyle ':prompt:pure:prompt:success' color 'magenta'     # iris
      zstyle ':prompt:pure:prompt:error' color 'red'           # love
      zstyle ':prompt:pure:prompt:continuation' color '8'      # muted
      zstyle ':prompt:pure:user' color 'magenta'               # iris
      zstyle ':prompt:pure:host' color 'magenta'               # iris
      zstyle ':prompt:pure:virtualenv' color '8'               # muted
      zstyle ':prompt:pure:suspended_jobs' color 'red'         # love
      # init pure directly — `promptinit` costs ~13 ms scanning fpath for every
      # available prompt theme; pure sets its own prompt options when called
      # standalone
      autoload -Uz prompt_pure_setup
      prompt_pure_setup

      # === Tmux autostart ===
      # $ZSH_NO_TMUX escape hatch is for benchmarking (zsh-bench unsets TMUX)
      if [[ -z "$TMUX" && -z "$ZSH_NO_TMUX" && -z "$EMACS" && -z "$VIM" && -z "$INSIDE_EMACS" && -z "$VSCODE_RESOLVING_ENVIRONMENT" && "$TERM_PROGRAM" != "vscode" && -z "$SSH_TTY" ]]; then
        tmux start-server
        if ! tmux has-session 2>/dev/null; then
          tmux new-session -d -s "local" \; set-option -t "local" destroy-unattached off &>/dev/null
        fi
        exec tmux attach-session -d
      fi
    '';
  };
}
