# k9s skin as a function of a Rosé Pine palette (see rose-pine.nix), so the
# main and dawn skins can't drift apart.
#
# Structure ported from https://github.com/sasoria/k9s-theme/blob/main/rose-pine.yaml
#
# N.B. this has to be an attrset rather than a raw YAML string: home-manager's
# programs.k9s.skins runs the value through its YAML generator, so a string ends
# up serialised as a single quoted scalar that k9s can't read.
palette:
with palette;
{
  k9s = {
    body = {
      fgColor = text;
      bgColor = "default";
      logoColor = iris;
    };
    prompt = {
      fgColor = text;
      bgColor = surface;
      suggestColor = foam;
    };
    help = {
      fgColor = text;
      bgColor = "default";
      sectionColor = pine;
      keyColor = foam;
      numKeyColor = rose;
    };
    frame = {
      title = {
        fgColor = pine;
        bgColor = "default";
        highlightColor = iris;
        counterColor = gold;
        filterColor = pine;
      };
      border = {
        fgColor = iris;
        focusColor = foam;
      };
      menu = {
        fgColor = text;
        keyColor = foam;
        numKeyColor = rose;
      };
      crumbs = {
        fgColor = base;
        bgColor = iris;
        activeColor = rose;
      };
      status = {
        newColor = foam;
        modifyColor = foam;
        addColor = pine;
        pendingColor = love;
        errorColor = love;
        highlightColor = rose;
        killColor = iris;
        completedColor = subtle;
      };
    };
    info = {
      fgColor = love;
      sectionColor = text;
    };
    views = {
      table = {
        fgColor = text;
        bgColor = "default";
        cursorFgColor = text;
        cursorBgColor = highlightMed;
        markColor = iris;
        header = {
          fgColor = gold;
          bgColor = "default";
          sorterColor = rose;
        };
      };
      xray = {
        fgColor = text;
        bgColor = "default";
        cursorColor = highlightHigh;
        cursorTextColor = base;
        graphicColor = iris;
      };
      charts = {
        bgColor = "default";
        chartBgColor = "default";
        dialBgColor = "default";
        defaultDialColors = [
          pine
          love
        ];
        defaultChartColors = [
          pine
          love
        ];
        resourceColors = {
          cpu = [
            iris
            foam
          ];
          mem = [
            gold
            love
          ];
        };
      };
      yaml = {
        keyColor = foam;
        valueColor = text;
        colonColor = subtle;
      };
      logs = {
        fgColor = text;
        bgColor = "default";
        indicator = {
          fgColor = foam;
          bgColor = "default";
          toggleOnColor = pine;
          toggleOffColor = subtle;
        };
      };
    };
    dialog = {
      fgColor = gold;
      bgColor = muted;
      buttonFgColor = base;
      buttonBgColor = text;
      buttonFocusFgColor = base;
      buttonFocusBgColor = iris;
      labelFgColor = rose;
      fieldFgColor = text;
    };
  };
}
