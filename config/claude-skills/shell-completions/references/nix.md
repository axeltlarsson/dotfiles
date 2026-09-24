# Packaging completions with Nix — and how shells find them

Sources: nixpkgs `pkgs/stdenv/generic/setup.sh`, `pkgs/build-support/trivial-builders/default.nix`,
`pkgs/by-name/in/installShellFiles/setup-hook.sh`, `pkgs/build-support/mkshell/default.nix`;
home-manager `modules/programs/{zsh,bash}.nix`; nix-darwin `modules/programs/{zsh,bash}`;
bash-completion 2.18 `bash_completion` (`_comp_load`). Facts marked [V] were verified locally.

## Where the files must land

| shell | path inside the package | file name |
|---|---|---|
| zsh | `share/zsh/site-functions/` | `_<cmd>` — the file name **is** the function name |
| bash | `share/bash-completion/completions/` | `<cmd>.bash` — bash-completion 2.18 deprecates unsuffixed `<cmd>` and dropped `_<cmd>` |

`installShellCompletion --cmd <cmd> --bash FILE --zsh FILE` synthesises exactly these names. Mode 0644, no shebang.

## Builders

- `writeShellApplication` emits **only** `bin/<name>`; it shellchecks `text` at build (`bash -n -O extglob` + `shellcheck-minimal`) and sets `meta.mainProgram`. It has no install phase to hook, so completions need a wrapper derivation.
- `writers.writePython3Bin` likewise emits only `bin/`.
- `symlinkJoin { paths; postBuild; }` runs `lndir` per path: `bin/<cmd>` becomes a **symlink into the unwrapped package**. It does **not** inherit `meta` or `passthru` — pass `meta = app.meta;` or `lib.getExe`/`nix run` lose `mainProgram`.
- `installShellFiles` hook: `installShellCompletion [--cmd NAME] ([--bash|--zsh|--fish] [--name NAME] PATH)...`; destinations under `${!outputBin}/share/{bash-completion/completions,zsh/site-functions,fish/vendor_completions.d}`; a zero-byte or missing destination is a build failure; works inside `runCommand`/`symlinkJoin` once it is in `nativeBuildInputs`.

### Default recipe (real `bin/` file — findable by every loader)

```nix
let
  app = pkgs.writeShellApplication {
    name = "mytool";
    runtimeInputs = [ ];
    text = builtins.readFile ./mytool.sh;
  };
in
pkgs.runCommand "mytool"
  {
    nativeBuildInputs = [ pkgs.installShellFiles ];
    meta = app.meta; # keeps mainProgram for lib.getExe / nix run
    passthru = { unwrapped = app; };
  }
  ''
    install -Dm755 ${app}/bin/mytool $out/bin/mytool
    installShellCompletion --cmd mytool \
      --bash ${./completions/mytool.bash} \
      --zsh ${./completions/_mytool}
  ''
```

Why a copy and not `symlinkJoin`: bash-completion ≥ 2.12 also looks for `<prefix>/share/bash-completion/completions/<cmd>.bash` where `<prefix>` is derived from the **realpath** of the command (and from each `$PATH` entry ending in `/bin`). A symlink into the unwrapped package resolves to a prefix with no `share/`, and on nix-darwin `/etc/profiles/per-user/<u>/share` only links `environment.pathsToLink` (`/share/zsh` by default, **not** `/share/bash-completion`), so a `home.packages` tool wrapped with `symlinkJoin` has no reachable bash completion at all. The copy puts `bin/` and `share/` in one store path.

### Lighter alternative when only a devShell consumes it

```nix
pkgs.symlinkJoin {
  name = "mytool";
  paths = [ app ];
  nativeBuildInputs = [ pkgs.installShellFiles ];
  postBuild = ''installShellCompletion --cmd mytool --bash ${./completions/mytool.bash} --zsh ${./completions/_mytool}'';
  inherit (app) meta; # symlinkJoin drops it
}
```

### Generated completions (cobra, clap, click, typer, argparse+shtab)

```nix
postInstall = ''
  installShellCompletion --cmd mytool \
    --bash <($out/bin/mytool completion bash) \
    --zsh <($out/bin/mytool completion zsh)
'';
```
A named pipe needs the shell flag **and** `--cmd`/`--name`.

### Flake outputs

- `packages.<system>.<cmd> = mytool;` (and `packages.default`) if anyone will `nix run`/`nix build` it.
- `checks.<system>.<cmd>-completions`: `nix flake check` only *evaluates* devShells and `writeShellApplication` never looks at the completion files, so lint them yourself:
  ```nix
  checks.${system}.mytool-completions = pkgs.runCommand "mytool-completions" { nativeBuildInputs = [ pkgs.shellcheck pkgs.zsh pkgs.bash ]; } ''
    shellcheck -S warning ${./completions/mytool.bash}
    bash -n ${./completions/mytool.bash}
    zsh -n ${./completions/_mytool}
    head -c8 ${./completions/_mytool} | grep -qx '#compdef'
    # literal lists must mirror the script: diff them
    diff <(bash -c 'source <(grep -m1 "^clusters=" ${./mytool.sh}); printf "%s\n" "''${clusters[@]}"') \
         <(sed -n "s/.*'1:cluster:((\(.*\)))'.*/\1/p" ${./completions/_mytool} | tr ' ' '\n' | sed 's/\\\\:.*//')
    touch $out
  '';
  ```
  Interactive (pty) tests stay outside Nix (`scripts/verify.sh`); paste their output into the PR.
- **Untracked files do not exist to a flake**: `git add completions/` before `nix build`, or you get `path '/nix/store/…/completions/_mytool' does not exist`.
- `writeShellApplication`'s syntax check runs `bash -n -O extglob`, which hides a missing `shopt -s extglob`; check standalone completion files with plain `bash -n` and, on macOS, `/bin/bash -n`.

## How a devShell exposes completions (direnv / `nix develop`)

- `mkShell` puts `packages` and `nativeBuildInputs` into `nativeBuildInputs`; stdenv's `setup.sh` runs `addToSearchPath _XDG_DATA_DIRS "$pkg/share"` for every such input that has a `share/` dir (`hostOffset <= -1`), then exports `XDG_DATA_DIRS`. `buildInputs` are **not** added (they are still on `PATH`, so bash-completion's PATH-relative lookup finds them anyway).
- **bash**: bash-completion ≥ 2 (requires bash ≥ 4.2) loads `$XDG_DATA_DIRS/*/bash-completion/completions/<cmd>.bash` on the **first `<TAB>`** — nothing to configure. Gotcha: pressing `<TAB>` on the command *before* the file exists pins a minimal compspec for that shell session → `complete -r <cmd>` or a new shell.
- **zsh never reads `XDG_DATA_DIRS`**, and `compinit` registers only what is on `fpath` when it runs (startup). Options, in order of preference:
  1. a lazy loader in `.zshrc` — Axel's `_xdg_lazy_complete` (dotfiles `config/zsh.nix`, first entry in `zstyle ':completion:*' completer`) registers every `XDG_DATA_DIRS/*/zsh/site-functions` dir not yet on fpath the first time an unregistered command is completed; the public equivalent is `zsh-completion-sync`;
  2. per tool, in `.zshrc` after `compinit`:
     `(( $+commands[mytool] )) && { fpath+=(${commands[mytool]:h:h}/share/zsh/site-functions); autoload -Uz _mytool; compdef _mytool mytool; }`
     (works because `$commands` does not resolve the `bin/` symlink);
  3. `source` the installed `_mytool` — only if the file has the dual-mode footer (see `zsh.md`).

## How `home.packages` exposes completions

- **zsh**: nix-darwin's `/etc/zshenv` and home-manager's generated `.zshrc` (order 520) put `$p/share/zsh/site-functions` for every `$NIX_PROFILES` entry on `fpath` **before** `compinit` — `/etc/profiles/per-user/<u>` is one of them (`useUserPackages = true`), so a package there is found on the first shell after `switch`.
- **The dump**: default `compinit` (no `-C`) re-validates the `.zcompdump` on every start and regenerates it when the number of `_*` files on fpath changes — a new package is picked up automatically (~600 ms once). With `compinit -C` the dump is never validated; the dotfiles handle this with `home.activation.zshCompdump` deleting the dump on every `switch`. If completions for a *new* tool do not appear: `rm -f ~/.config/zsh/.zcompdump*` (or `~/.zcompdump*`) and open a new shell. A changed `#compdef` line also needs the dump deleted.
- **bash**: home-manager's `programs.bash.enableCompletion` sources bash-completion; nix-darwin links `/share/bash-completion/completions` into the per-user profile only with `programs.bash.completion.enable = true` (or `environment.pathsToLink = [ "/share/bash-completion" ]`). With the default recipe above the realpath lookup works regardless.
- macOS `/bin/bash` is 3.2 and can never run bash-completion 2.x; those users `source` the file directly, which is why the bash file must stay 3.2-compatible.

## What to put in the PR body

- bash: "nothing to do with bash-completion ≥ 2 (loaded from `XDG_DATA_DIRS` on first TAB). Without it: `source "$(dirname "$(command -v mytool)")/../share/bash-completion/completions/mytool.bash"`."
- zsh: the one-liner from option 2 above, or a pointer to the lazy loader.
- fish: not shipped (state it; `installShellCompletion --fish` is the follow-up).
