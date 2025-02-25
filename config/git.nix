{ pkgs, config, ... }:
{
  programs.git = {
    enable = true;
    userName = "axeltlarsson";

    delta = {
      enable = true;
      options = {
        navigate = true;
      };
    };

    aliases = {
      co = "checkout";
      ignore = "!gi() { curl -L -s https://www.gitignore.io/api/$@ ;}; gi";
      please = "push --force-with-lease";
      st = "status";
    };

    extraConfig = {
      core = {
        editor = "nvim";
        excludesFile = "~/.gitignore"; # TODO: inline?
      };

      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      init.defaultBranch = "main";

      diff = {
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };

      push = {
        default = "simple";
        helper = "cache --timeout=18000";
        autoSetupRemote = true;
        followTags = true;
      };

      fetch = {
        prune = true;
        pruneTags = true;
        all = true;
      };

      grep.patternType = "perl";

      help.autocorrect = "prompt";

      commit.verbose = true;

      rerere = {
        enabled = true;
        autoupdate = true;
      };

      rebase = {
        autoSquash = true;
        autoStash = true;
        updateRef = true;
      };

      pull.rebase = false;
      merge = {
        tool = "nvim";
        conflictstyle = "zdiff3";
      };
      mergeTool.keepBackup = false;
      mergeTool = {
        nvim = {
          prompt = false;
          cmd = "nvim -d $MERGED $LOCAL $BASE $REMOTE -c 'wincmd J'";
        };
      };

      color = { };
      submodule.recurse = true;
    };

    lfs.enable = true;

    signing = {
      signByDefault = true;
    };
  };
}
