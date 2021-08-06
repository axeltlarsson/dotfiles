{ config, pkgs, ... }:

{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "axel";
  home.homeDirectory = "/Users/axel";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "21.11";

  home.packages = with pkgs; [
    exa
    nixfmt
    ripgrep
    jq
    diff-so-fancy
    bat
    elmPackages.elm-format
    elmPackages.elm-json
    elmPackages.elm-test
    elmPackages.create-elm-app
    nodejs
    pinentry_mac
    pinentry
    neovim
  ];

  home.sessionPath = [ "${config.home.homeDirectory}/.npm-packages/bin" ];

  home.file.".npmrc".source = ./npmrc.conf;
  home.file.".config/pgcli/config".source = ./pgcli.conf;
  home.file.".pspgconf".source = ./pspg.conf;
  home.file.".psqlrc".source = ./psqlrc.conf;

  programs.zsh = {
    enable = true;
    initExtraFirst = "";

    envExtra = ''
      function zet {
        nvim "+Zet $*"
      }
      # TODO: why this required?
      if [ -e ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh ]; then
        . ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh;
      fi
    '';

    initExtra = ''
      alias vi=nvim
      alias vim=nvim
      alias ls=exa
    '';

    sessionVariables = {
      BAT_THEME = "Sublime Snazzy";
      EDITOR = "${pkgs.neovim}/bin/nvim";
      VISUAL = "${pkgs.neovim}/bin/nvim";
      GPG_TTY = "$(tty)";
    };

    prezto = {
      enable = true;
      editor.keymap = "vi";
      prompt.theme = "pure";

      pmodules = [
        "environment"
        "editor"
        "history"
        "directory"
        "spectrum"
        "utility"
        "completion"
        "fasd"
        "syntax-highlighting"
        "history-substring-search"
        "prompt"
        "tmux"
        "fzf-tab"
      ];
      pmoduleDirs = [ ../zprezto-modules ];
      extraConfig = ''
        # fzf-tab https://github.com/Aloxaf/fzf-tab
        # zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
        # disable sort when completing `git checkout`
        # set descriptions format to enable group support
        zstyle ':completion:*:descriptions' format '[%d]'
        # set list-colors to enable filename colorizing
        #zstyle ':completion:*' list-colors \$\{("s.:.")LS_COLORS\}
        # preview directory's content with exa when completing cd
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
        zstyle ':fzf-tab:complete:cd:*' popup-pad 30 0
        # switch group using `,` and `.`
        # TODO: not all of this works as expected
        zstyle ':fzf-tab:*' switch-group ',' '.'
        zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
          'git diff $word | delta'|
        zstyle ':fzf-tab:complete:git-log:*' fzf-preview \
          'git log --color=always $word'
        zstyle ':fzf-tab:complete:git-show:*' fzf-preview \
          'case "$group" in
          "commit tag") git show --color=always $word ;;
          *) git show --color=always $word | delta ;;
          esac'
        zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview \
          'case "$group" in
          "modified file") git diff $word | delta ;;
          "recent commit object name") git show --color=always $word | delta ;;
          *) git log --color=always $word ;;
          esac'
      '';

      tmux.autoStartLocal = true;
      tmux.defaultSessionName = "local";

    };

  };

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

  programs.alacritty = {
    enable = true;
    settings = import ./alacritty.nix pkgs;
  };

  programs.tmux = {
    enable = true;

    clock24 = true;
    escapeTime = 0;
    extraConfig = ''
      set-option -ga terminal-overrides ",xterm-256color:Tc"
      set -s default-terminal "xterm-256color"
      set -g mouse on
      set -g focus-events off
      # Match postgresql URLs, default url_search doesn't
      set -g @copycat_search_C-p '(https?://|git@|git://|ssh://|ftp://|postgresql://|file:///)[[:alnum:]?=%/_.:,;~@!#$&()*+-]*'
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

  programs.git = {
    enable = true;
    userName = "AxelTLarsson";
    userEmail = "mail@axellarsson.nu";

    aliases = {
      co = "checkout";
      ignore = "!gi() { curl -L -s https://www.gitignore.io/api/$@ ;}; gi";
      please = "push --force-with-lease";
      st = "status";
    };

    extraConfig = {
      core = {
        editor = "nvim";
        pager = "diff-so-fancy | less --tabs=4 -RFX";
        excludesFile = "~/.gitignore"; # TODO: inline?
      };

      push = {
        default = "simple";
        helper = "cache --timeout=18000";
      };

      pull.rebase = false;
      merge = {
        tool = "nvim";
        conflictstyle = "diff3";
      };
      mergeTool.keepBackup = false;
      mergeTool = {
        nvim = {
          prompt = false;
          cmd = "nvim -d $MERGED $LOCAL $BASE $REMOTE -c 'wincmd J'";
        };
      };

      color = {
        diff-highlight = {
          oldNormal = "red bold";
          oldHighlight = "red bold 52";
          newNormal = "green bold";
          newHighlight = "green bold 22";
        };

        diff = {
          meta = "227";
          frag = "magenta bold";
          commit = "227 bold";
          old = "red bold";
          new = "green bold";
          whitespace = "red reverse";
        };
      };
      submodule.recurse = true;

    };

    lfs.enable = true;

    signing = {
      key = "061876CE2CD14AE0";
      signByDefault = true;
    };

  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.gpg = { enable = true; };
  home.file.".gnupg/gpg-agent.conf".text = ''
    use-standard-socket
    pinentry-program ${pkgs.pinentry}/bin/pinentry
  '';

  programs.keychain = {
    enable = true;
    enableZshIntegration = true;
  };

}
