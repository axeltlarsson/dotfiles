final: prev: {
  zsh-prezto = prev.zsh-prezto.overrideAttrs (old: {
    installPhase =
      old.installPhase
      + ''
        # Replace bundled Pure prompt with latest version (fixes Ghostty shell integration conflict)
        # See: https://github.com/sindresorhus/pure/pull/706
        rm -rf $out/share/zsh-prezto/modules/prompt/external/pure
        cp -r ${
          prev.fetchFromGitHub {
            owner = "sindresorhus";
            repo = "pure";
            rev = "dbefd0dcafaa3ac7d7222ca50890d9d0c97f7ca2";
            hash = "sha256-Fhk4nlVPS09oh0coLsBnjrKncQGE6cUEynzDO2Skiq8=";
          }
        } $out/share/zsh-prezto/modules/prompt/external/pure
      '';
  });
}
