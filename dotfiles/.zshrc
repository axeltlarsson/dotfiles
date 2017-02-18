# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

#------------ functions ----------------------------
# usage: orElse nvim vim [args]
orElse() {
  $1 "${@:3}" 2> /dev/null || $2 "${@:3}"
}

# set terminal title with this function
title() {
  echo -en "\e]2;$1\a"
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

#------------ aliases -------------------------------
# typing an address suffixed by .se, .com etc will open firefox w that page
alias -s se=firefox
alias -s com=firefox
alias -s nu=firefox
alias -s org=firefox

alias pp_json="python -m json.tool | pygmentize -l javascript" # e.g. "cat file.json | pp_json"
alias gcc="gcc -pedantic -Wall -Werror -std=c11 -O3"
alias grep="orElse ag grep"
alias vim="orElse nvim vim"

# npm to not have to use sudo for global packages
NPM_PACKAGES="${HOME}/.npm-packages"
PATH="$NPM_PACKAGES/bin:$PATH"

export SCALA_HOME=$SCALA_HOME:/usr/local/bin/scala-2.12.1
export PATH=$PATH:$SCALA_HOME:$SCALA_HOME/bin

# Ruby - rbenv
if is_mac; then
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
  export PATH="/usr/local/opt/apache-spark@1.6/bin:$PATH"
fi

# allow pipe redirect to overwrite files
set -o clobber

