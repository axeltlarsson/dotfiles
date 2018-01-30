# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# TODO
# - refactor into different files for different envs (machines/os:es)
# - optimise calls to is_mac / is_linux (related to above)
#------------ functions --------------------------------------------------------
# usage: orElse nvim vim [args]
orElse() {
  $1 "${@:3}" 2> /dev/null || $2 "${@:3}"
}

installed() {
  if ! loc="$(type -p "$1")" || [ -z "$loc" ]; then
    false
  else
    true
  fi
}

# usage: if is_mac; then ... else ... fi // do not use [[ is_mac ]] !!!
is_mac () {
  case `uname` in
    Darwin)
      true
      ;;
    *)
      false
      ;;
  esac
}

is_linux () {
  case `uname` in
    Linux)
      true
      ;;
    *)
      false
      ;;
  esac
}

#------------ aliases ---------------------------------------------------------
# typing an address suffixed by .se, .com etc will open firefox w that page
alias -s se=firefox
alias -s com=firefox
alias -s nu=firefox
alias -s org=firefox

alias pp_json="python -m json.tool | pygmentize -l javascript" # e.g. "cat file.json | pp_json"
alias gcc="gcc -pedantic -Wall -Werror -std=c11 -O3"

if is_linux; then
  alias open="xdg-open"
fi

# ----------- conditional aliases ---------------------------------------------
if installed nvim; then
  alias vi=nvim
  alias vim=nvim
fi

if installed ag; then
  alias grep=ag
fi

# ------------ environment variables -------------------------------------------
# npm to not have to use sudo for global packages
NPM_PACKAGES="${HOME}/.npm-packages"
PATH="$NPM_PACKAGES/bin:$PATH"

export SCALA_HOME=$SCALA_HOME:/usr/local/bin/scala-2.12.2
export PATH=$PATH:$SCALA_HOME:$SCALA_HOME/bin

# Ruby - rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
# ruby-build
export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
if installed rbenv; then
  eval "$(rbenv init -)"
fi

if is_mac; then
  export PATH="/usr/local/opt/apache-spark@1.6/bin:$PATH"
  export PATH="/Library/TeX/texbin:$PATH"
fi

if is_linux; then
  export PATH="/home/axel/.linuxbrew/bin:$PATH"
  export MANPATH="/home/axel/.linuxbrew/share/man:$MANPATH"
  export INFOPATH="/home/axel/.linuxbrew/share/info:$INFOPATH"
fi

# allow pipe redirect to overwrite files
set -o clobber

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
# Setting ag as the default source for fzf
# export FZF_DEFAULT_COMMAND='ag'
