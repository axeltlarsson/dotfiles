{ pkgs, lib, ... }:
{
  programs.ghostty = {
    enable = true;
    # On macOS, ghostty is installed externally (not via nixpkgs)
    package = lib.mkIf pkgs.stdenv.isDarwin null;
    enableZshIntegration = true;
    settings = {
      # Font
      font-family = "Hasklug Nerd Font";
      font-size = 13;

      # Theme
      theme = "Rose Pine";

      # Window
      window-decoration = false;
      fullscreen = true;
      macos-non-native-fullscreen = true;

      # Scrollback (~10000 lines)
      scrollback-limit = 1000000;

      # Mouse
      mouse-hide-while-typing = true;

      # Selection
      copy-on-select = "clipboard";

      # Keybindings
      keybind = "cmd+enter=toggle_fullscreen";
    };
  };
}
