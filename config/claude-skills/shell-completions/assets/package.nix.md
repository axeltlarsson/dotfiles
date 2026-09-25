# Nix packaging snippets

Names are fixed by the loaders: `share/zsh/site-functions/_CMD` and
`share/bash-completion/completions/CMD.bash`. `installShellCompletion --cmd CMD` produces both.
Untracked files do not exist to a flake: `git add completions/` before `nix build`.

## Default: real `bin/` file + completions in one store path

Works for every consumer (devShell `XDG_DATA_DIRS`, PATH-relative and realpath lookups by
bash-completion, home-manager profiles that only link `/share/zsh`).

```nix
let
  app = pkgs.writeShellApplication {
    name = "CMD";
    runtimeInputs = [ ];
    text = builtins.readFile ./CMD.sh;
  };
in
pkgs.runCommand "CMD"
  {
    nativeBuildInputs = [ pkgs.installShellFiles ];
    meta = app.meta; # keeps mainProgram for lib.getExe / nix run
    passthru = {
      unwrapped = app;
    };
  }
  ''
    install -Dm755 ${app}/bin/CMD $out/bin/CMD
    installShellCompletion --cmd CMD \
      --bash ${./completions/CMD.bash} \
      --zsh ${./completions/_CMD}
  ''
```

## Alternative: `symlinkJoin` (devShell-only consumption)

```nix
pkgs.symlinkJoin {
  name = "CMD";
  paths = [ app ];
  nativeBuildInputs = [ pkgs.installShellFiles ];
  postBuild = ''
    installShellCompletion --cmd CMD --bash ${./completions/CMD.bash} --zsh ${./completions/_CMD}
  '';
  inherit (app) meta; # symlinkJoin drops meta and passthru
}
```
`bin/CMD` is then a symlink into `app`, whose realpath has no `share/`; bash-completion still
finds the file via `XDG_DATA_DIRS` (mkShell) or `$PATH`-relative lookup, but not in a
nix-darwin per-user profile (only `/share/zsh` is linked there).

## Tools that generate their own completions

```nix
postInstall = ''
  installShellCompletion --cmd CMD \
    --bash <($out/bin/CMD completion bash) \
    --zsh <($out/bin/CMD completion zsh)
'';
```

## Flake outputs

```nix
packages.${system}.CMD = CMD;        # if anyone will `nix run` / `nix build` it
devShells.${system}.default = pkgs.mkShell { packages = [ CMD ]; };

# nix flake check only *evaluates* devShells and writeShellApplication never sees the
# completion files: lint them, and diff the literal lists against the script's own arrays.
checks.${system}.CMD-completions =
  pkgs.runCommand "CMD-completions"
    { nativeBuildInputs = [ pkgs.shellcheck pkgs.zsh pkgs.bash ]; }
    ''
      shellcheck -S warning ${./completions/CMD.bash}
      bash -n ${./completions/CMD.bash}
      zsh -n ${./completions/_CMD}
      head -c8 ${./completions/_CMD} | grep -qx '#compdef'
      diff <(bash -c 'source <(grep -m1 "^regions=" ${./CMD.sh}); printf "%s\n" "''${regions[@]}"') \
           <(sed -n "s/.*'1:region:((\(.*\)))'.*/\1/p" ${./completions/_CMD} | tr ' ' '\n' | sed 's/\\\\:.*//')
      touch $out
    '';
```
Interactive (pty) verification stays outside Nix: `scripts/verify.sh`, output pasted into the PR.

## home-manager (dotfiles)

```nix
home.packages = [ CMD ];
```
zsh finds `share/zsh/site-functions` through `$NIX_PROFILES` on the first shell after `switch`
(the dotfiles delete the compdump on activation; a default `compinit` regenerates it when the
`_*` file count changes). bash needs `programs.bash.enableCompletion` and, on nix-darwin, either
the default recipe above (realpath lookup) or `programs.bash.completion.enable = true`.
