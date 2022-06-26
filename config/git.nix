{ pkgs, config, ... }: {
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

    signing = { signByDefault = true; };

  };
}
