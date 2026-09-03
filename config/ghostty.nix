{ pkgs, lib, ... }:
{
  programs.ghostty = {
    enable = true;
    # On macOS, ghostty is installed externally (not via nixpkgs)
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin null;
    enableZshIntegration = true;
    settings = {
      # Font
      # font-family = "Hasklug Nerd Font";
      # font-size = 13;
      # font-thicken = true;
      # font-thicken-strength = 200;

      # Theme — follows the macOS appearance automatically, no config reload needed.
      # Flip it with `theme toggle` / tmux `prefix + T` (see config/theme.nix).
      theme = "light:Rose Pine Dawn,dark:Rose Pine";

      # Window
      window-decoration = false;
      macos-non-native-fullscreen = true;

      # Scrollback (~10000 lines)
      scrollback-limit = 1000000;

      # Mouse
      mouse-hide-while-typing = true;

      # Selection
      copy-on-select = "clipboard";

      # Security
      macos-auto-secure-input = true;
      macos-secure-input-indication = true;

      # Keybindings
      keybind = "cmd+enter=toggle_fullscreen";
    };
  };
}
