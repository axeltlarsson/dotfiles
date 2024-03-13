final: prev: {
  pythonEnv = with final;
    buildEnv {
      name = "env-python";
      paths = [ (python3.withPackages (ps: with ps; [ pandas numpy ])) ];
    };
}
