# A .tmTheme (TextMate/Sublime syntax theme) as a function of a Rosé Pine
# palette, for bat and delta. Same shape as k9s-skin.nix — one structure, both
# variants, so light and dark can't drift.
#
# Upstream rose-pine/sublime-text only ever shipped a dark .tmTheme, and newer
# revs moved to .sublime-color-scheme which syntect (and therefore bat) can't
# load — hence generating it here. Scope coverage mirrors that upstream port;
# `comment` is the one deliberate change, from highlightMed to muted, which the
# old port had too dim to read at all against a light background.
palette:
with palette;
{
  name = "Rosé Pine";
  settings = [
    {
      settings = {
        background = base;
        foreground = text;
        caret = text;
        invisibles = highlightMed;
        lineHighlight = highlightLow;
        selection = highlightMed;
      };
    }
    {
      scope = "comment";
      settings.foreground = muted;
    }
    {
      scope = "string";
      settings.foreground = gold;
    }
    {
      scope = "constant.numeric";
      settings.foreground = iris;
    }
    {
      scope = "constant.language";
      settings.foreground = iris;
    }
    {
      scope = "constant.character, constant.other";
      settings.foreground = iris;
    }
    {
      scope = "keyword";
      settings.foreground = love;
    }
    {
      scope = "storage";
      settings.foreground = love;
    }
    {
      scope = "storage.type";
      settings.foreground = foam;
    }
    {
      scope = "entity.name.class";
      settings.foreground = pine;
    }
    {
      scope = "entity.other.inherited-class";
      settings.foreground = pine;
    }
    {
      scope = "entity.name.function";
      settings.foreground = pine;
    }
    {
      scope = "variable.parameter";
      settings.foreground = gold;
    }
    {
      scope = "entity.name.tag";
      settings.foreground = love;
    }
    {
      scope = "entity.other.attribute-name";
      settings.foreground = pine;
    }
    {
      scope = "support.function";
      settings.foreground = foam;
    }
    {
      scope = "support.constant";
      settings.foreground = foam;
    }
    {
      scope = "support.type, support.class";
      settings.foreground = foam;
    }
    {
      scope = "invalid";
      settings = {
        background = love;
        foreground = base;
      };
    }
    {
      scope = "invalid.deprecated";
      settings = {
        background = iris;
        foreground = base;
      };
    }
  ];
}
