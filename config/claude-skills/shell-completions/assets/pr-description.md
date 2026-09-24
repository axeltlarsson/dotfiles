### What

Tab completion for every `CMD` subcommand and argument, shipped with the package
(`share/zsh/site-functions/_CMD`, `share/bash-completion/completions/CMD.bash`).
<one sentence on the packaging change, e.g. writeShellApplication only emits bin/, so it is wrapped …>

### Using it

**bash** — nothing to do with bash-completion ≥ 2 (it loads the file from `XDG_DATA_DIRS`
inside the devShell on the first `<TAB>`). Without it, e.g. macOS `/bin/bash`:
`source "$(dirname "$(command -v CMD)")/../share/bash-completion/completions/CMD.bash"`.

**zsh** — `compinit` only registers what is on `fpath` at startup, so either a lazy loader for
`XDG_DATA_DIRS` (e.g. `_xdg_lazy_complete` in axeltlarsson/dotfiles `config/zsh.nix`, or
zsh-completion-sync), or one line in `.zshrc` after `compinit`:

```zsh
(( $+commands[CMD] )) && { fpath+=(${commands[CMD]:h:h}/share/zsh/site-functions); autoload -Uz _CMD; compdef _CMD CMD; }
```

### Grammar (from `<script> @ <sha>`, not from `--help`)

| subcommand | position | accepts | notes |
|---|---|---|---|
| … | … | … | … |

Help-vs-code drift found (completion follows the code; fix the help text or the code separately):
- …

### Verification

`scripts/verify.sh` (static checks, zsh and bash through a real pty):

```
static  PASS n FAIL 0
zsh 5.9.2  PASS n FAIL 0
bash 5.3.15(1)-release  PASS n FAIL 0
bash 3.2.57(1)-release  PASS n FAIL 0
controls  PASS 2 FAIL 0
```

Not shipped: fish (`installShellCompletion --fish` is the follow-up if anyone needs it).
