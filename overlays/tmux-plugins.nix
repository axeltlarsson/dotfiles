final: prev: {
  tmuxPlugins = prev.tmuxPlugins // {
    rose-pine = prev.tmuxPlugins.rose-pine.overrideAttrs (old: {
      version = "0-unstable-2026-01-02";
      src = prev.fetchFromGitHub {
        owner = "rose-pine";
        repo = "tmux";
        rev = "8613447e75a2acead1cf2947e01991574b6371b9";
        hash = "sha256-Nd84SLB2UvqA/qYou8YSrqvt8/RWhJZgU9Nfw/nwxEA=";
      };
    });
  };
}
