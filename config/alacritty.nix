{ pkgs, ... }:
let
  colors = builtins.fromTOML (builtins.readFile ./alacritty-rose-pine.toml);
  # let colors = import ./alacritty-rose-pine.nix;
in {
  programs.alacritty = {
    enable = true;
    settings = {
      env = { "TERM" = "xterm-256color"; };

      window = {
        # Window decorations
        #
        # Values for `decorations` =
        #     - full = Borders and title bar
        #     - none = Neither borders nor title bar
        #
        # Values for `decorations` (macOS only) =
        #     - transparent = Title bar, transparent background and title bar buttons
        #     - buttonless = Title bar, transparent background and no title bar buttons
        decorations = "buttonless";

        # Startup Mode (changes require restart)
        #
        # Values for `startup_mode` =
        #   - Windowed
        #   - Maximized
        #   - Fullscreen
        #
        # Values for `startup_mode` (macOS only) =
        #   - SimpleFullscreen
        startup_mode = "FullScreen";

        # Window title
        #title = Alacritty

        # Allow terminal applications to change Alacritty's window title.
        dynamic_title = true;
      };

      scrolling = {
        # Maximum number of lines in the scrollback buffer.
        # Specifying '0' will disable scrolling.
        history = 10000;

        # Scrolling distance multiplier.
        multiplier = 3;
      };
      # Font configuration
      font = {
        # Normal (roman) font face
        normal = {
          # Font family
          #
          # Default =
          #   - (macOS) Menlo
          #   - (Linux/BSD) monospace
          #   - (Windows) Consolas
          family = "Hasklug Nerd Font";
          # family = Menlo

          # The `style` can be specified to pick a specific face.
          style = "Regular";
        };

        # Bold font face
        bold = {
          # Font family
          #
          # If the bold family is not specified, it will fall back to the
          # value specified for the normal font.
          # family = "Hasklug Nerd Font";

          # The `style` can be specified to pick a specific face.
          style = "Bold";
        };

        # Italic font face
        italic = {
          # Font family
          #
          # If the italic family is not specified, it will fall back to the
          # value specified for the normal font.
          # family = "Hasklug Nerd Font";

          # The `style` can be specified to pick a specific face.
          style = "Italic";
        };

        # Bold italic font face
        #bold_italic =
        # Font family
        #
        # If the bold italic family is not specified, it will fall back to the
        # value specified for the normal font.
        #family = monospace

        # The `style` can be specified to pick a specific face.
        #style = Bold Italic

        # Point size
        size = 13.0;

        # Offset is the extra space around each character. `offset.y` can be thought
        # of as modifying the line spacing, and `offset.x` as modifying the letter
        # spacing.
        #offset =
        #  x = 0
        #  y = 0

        # Glyph offset determines the locations of the glyphs within their cells with
        # the default being at the bottom. Increasing `x` moves the glyph to the
        # right, increasing `y` moves the glyph upward.
        #glyph_offset =
        #  x = 0
        #  y = 0

        # Thin stroke font rendering (macOS only)
        #
        # Thin strokes are suitable for retina displays, but for non-retina screens
        # it is recommended to set `use_thin_strokes` to `false`.
        #use_thin_strokes = true
      };

      colors = colors // {
        # If `true`, bold text is drawn using the bright color variants.
        draw_bold_text_with_bright_colors = true;
      };

      # Bell
      bell = {
        # Visual Bell Animation
        #
        # Animation effect for flashing the screen when the visual bell is rung.
        #
        # Values for `animation` =
        #   - Ease
        #   - EaseOut
        #   - EaseOutSine
        #   - EaseOutQuad
        #   - EaseOutCubic
        #   - EaseOutQuart
        #   - EaseOutQuint
        #   - EaseOutExpo
        #   - EaseOutCirc
        #   - Linear
        animation = "EaseOutExpo";

        # Duration of the visual bell flash in milliseconds. A `duration` of `0` will
        # disable the visual bell animation.
        duration = 30;

        # Visual bell animation color.
        color = "#ffffff";
      };
      selection = {
        # This string contains all characters that are used as separators for
        # "semantic words" in Alacritty.
        semantic_escape_chars = '',│`|:"' ()[]{}<>	'';

        # When set to `true`, selected text will be copied to the primary clipboard.
        save_to_clipboard = true;
      };

      cursor = {
        # If this is `true`, the cursor will be rendered as a hollow box when the
        # window is not focused.
        unfocused_hollow = true;
      };

      shell = { program = "${pkgs.zsh}/bin/zsh"; };

      mouse = { hide_when_typing = true; };

      keyboard.bindings = [{
        key = "Return";
        mods = "Command";
        action = "ToggleFullscreen";
      }];
    };
  };
}
