final: prev: {
  tmuxPlugins = prev.tmuxPlugins // {
    rose-pine = prev.tmuxPlugins.rose-pine.overrideAttrs (old: {
      version = "0-unstable-2026-03-24";
      src = prev.fetchFromGitHub {
        owner = "rose-pine";
        repo = "tmux";
        rev = "b6138c51573425ccdc33c91464597323baec3b7e";
        hash = "sha256-HDmCCRhTCPfu7gL9VPHVGCiG5IcnkpQ4EaXN4IsQ0YE=";
      };
    });
  };
}
