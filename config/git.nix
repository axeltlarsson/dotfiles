{ pkgs, config, ... }: {
  programs.git = {
    enable = true;
    userName = "axeltlarsson";

    delta = {
      enable = true;
      options = { };
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

      push = {
        default = "simple";
        helper = "cache --timeout=18000";
        autoSetupRemote = true;
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

      color = { };
      submodule.recurse = true;
    };

    lfs.enable = true;

    signing = { signByDefault = true; };
  };
}
