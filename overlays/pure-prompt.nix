final: prev: {
  pure-prompt = prev.pure-prompt.overrideAttrs (old: {
    version = "1.27.1";
    src = prev.fetchFromGitHub {
      owner = "sindresorhus";
      repo = "pure";
      rev = "v1.27.1";
      hash = "sha256-Fhk4nlVPS09oh0coLsBnjrKncQGE6cUEynzDO2Skiq8=";
    };
  });
}
