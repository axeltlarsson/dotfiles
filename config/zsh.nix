{ pkgs, config, ... }:
{
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";

    initContent = ''
      alias vi=nvim
      alias vim=nvim
      # allows e.g. `nix run nixpkgs#whatever`
      setopt nonomatch

      # fzf: make alt-c cd work https://github.com/junegunn/fzf/issues/164
      bindkey "ç" fzf-cd-widget
    '';

    sessionVariables = {
      EDITOR = "${pkgs.neovim}/bin/nvim";
      VISUAL = "${pkgs.neovim}/bin/nvim";
      GPG_TTY = "$(tty)";
      KEYTIMEOUT = 1;
      NOTES_DIR = "${config.home.homeDirectory}/Google Drive/My Drive/notes";
    };

    autosuggestion.enable = true;

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
