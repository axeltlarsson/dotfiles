# Sourced inside the zsh test child started by test-zsh-completion.zsh (zsh -f -i under zpty).
# Env: COMPLETION_DIR (dir holding _<cmd>), CAP_FILE (where each <TAB> writes its capture).
# only zsh's own functions plus the dir under test: compinit then scans ~1k files, not the whole profile
fpath=("$COMPLETION_DIR" ${fpath:#*(site-functions|vendor-completions)*})
autoload -Uz compinit
compinit -D -u
setopt extendedglob
unsetopt beep
zstyle ':completion:*' menu no
zstyle ':completion:*:messages' format 'MSG:%d'
zstyle ':completion:*:descriptions' format 'DESC:%d'
zstyle ':completion:*:warnings' format 'WARN:%d'
LISTMAX=100000
typeset -ga _cap_matches _cap_msgs

# Shadow compadd: record what compsys adds (matches, their -S suffix, -x/-X messages),
# then add for real so the line and listing behave exactly as they would for a user.
# Calls with -O/-A/-D only filter into an array (e.g. _describe's own pre-filter) and
# add nothing: pass them through untouched or the caller's array ends up empty.
compadd() {
  local -a args=("$@") t
  local a c v suffix= i=1 j nonadding=
  while (( i <= $#args )); do
    a=$args[i]
    [[ $a == -- ]] && break
    [[ $a == -[^-]* ]] || break # first non-option word: the matches follow
    j=2
    while (( j <= $#a )); do
      c=$a[j]
      if [[ $c == [PSpsiIWJVXxrRdDOAEMo] ]]; then # options that take a value
        v=${a[j+1,-1]}
        if [[ -z $v ]]; then (( i++ )); v=$args[i]; fi
        case $c in
          S) suffix=$v ;;
          [xX]) _cap_msgs+=("$v") ;;
          [OAD]) nonadding=1 ;;
        esac
        break
      fi
      (( j++ ))
    done
    (( i++ ))
  done
  if [[ -n $nonadding ]]; then
    builtin compadd "$@"
    return
  fi
  builtin compadd -O t "$@"
  local m
  for m in "${t[@]}"; do
    [[ -n $suffix && $suffix != (/| ) ]] && m+=$suffix
    _cap_matches+=("${(Q)${m%/}}") # (Q): file names arrive backslash-quoted
  done
  builtin compadd "$@"
}

# _message does not always go through compadd -x (e.g. _arguments' "no more arguments"):
# wrap it and record the message text itself.
autoload +X _message
functions[_cap_message_orig]=$functions[_message]
_message() {
  _cap_msgs+=("${@[-1]}")
  _cap_message_orig "$@"
}

_cap_complete() {
  _cap_matches=()
  _cap_msgs=()
  zle expand-or-complete
  {
    print -r -- "LIST:${(j:|:)${(@u)_cap_matches}}"
    print -r -- "MSG:${(j:|:)${(@u)_cap_msgs}}"
    print -r -- "BUF:<$BUFFER>"
    print -r -- "END"
  } >>"$CAP_FILE"
}
zle -N _cap_complete
bindkey -e
bindkey '^I' _cap_complete
PS1='%% '
print READY
