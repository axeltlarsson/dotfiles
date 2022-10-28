{ pkgs, config, ... }: {
  programs.zsh = {
    enable = true;

    envExtra = ''
      # TODO: autolaod
      function zet {
        nvim "+Zet $*"
      }

      if [ -e ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh ]; then
        . ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh;
      fi
    '';

    initExtra = ''
      alias vi=nvim
      alias vim=nvim
    '';

    sessionVariables = {
      EDITOR = "${pkgs.neovim}/bin/nvim";
      VISUAL = "${pkgs.neovim}/bin/nvim";
      GPG_TTY = "$(tty)";
      KEYTIMEOUT = 1;
    };

    prezto = {
      enable = true;
      editor.keymap = "vi";
      prompt.theme = "pure";
      # ensures performant shell https://github.com/nix-community/home-manager/issues/2255
      caseSensitive = true;

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

    };

  };
}
