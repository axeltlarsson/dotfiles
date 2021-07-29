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

  home.packages = with pkgs; [ nixfmt ripgrep diff-so-fancy ];

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

    # local: TODO - manage via Nix
    includes = [{ path = "~/.gitconfig_local"; }];

    lfs.enable = true;

    signing = {
      key = "061876CE2CD14AE0";
      signByDefault = true;
    };

  };

  programs.zsh = {
    enable = true;

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
      ];

      tmux.autoStartLocal = true;
      tmux.defaultSessionName = "local";

      # TODO
      # # fzf-tab https://github.com/Aloxaf/fzf-tab
      # zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
      # # disable sort when completing `git checkout`
      # zstyle ':completion:*:git-checkout:*' sort false
      # # set descriptions format to enable group support
      # zstyle ':completion:*:descriptions' format '[%d]'
      # # set list-colors to enable filename colorizing
      # zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
      # # preview directory's content with exa when completing cd
      # # zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
      # # switch group using `,` and `.`
      # zstyle ':fzf-tab:*' switch-group ',' '.'

    };

  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = ''rg --files --hidden --follow --glob "!.git/*"'';
    defaultOptions = [
      "--height 40%"
      "--border"
      # TODO: the rest of the options for Tomorrow Night Theme

    ];
  };
}
