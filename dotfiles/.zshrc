#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# aliases
# typing an address suffixed by .se, .com etc will open firefox w that page
alias -s se=firefox
alias -s com=firefox
alias -s nu=firefox

alias wakeBackupserver="wakeonlan 00:23:54:37:4e:9e"
alias pp_json="python -m json.tool | pygmentize -l javascript"
alias act="activator"
alias gcc="gcc -pedantic -Wall -Werror -std=c11 -O3"
export PATH=.cabal-sandbox/bin:~/.cabal/bin:/opt/cabal/1.22/bin:/opt/ghc/7.10.3/bin:/opt/happy/1.19.5/bin:/opt/alex/3.1.4/bin:$PATH
export PATH=/usr/local/bin/activator:$PATH

# set terminal title with this function
title() {
	echo -en "\e]2;$1\a"
}

# npm to not have to use sudo for global packages
NPM_PACKAGES="${HOME}/.npm-packages"
PATH="$NPM_PACKAGES/bin:$PATH"
# unset manpath so we can inherit from /etc/manpath via the `manpath` command
#unset MANPATH
#export MANPATH="$NPM_PACKAGES/share/man:$(manpath)"

export SCALA_HOME=$SCALA_HOME:/usr/local/bin/scala-2.11.8
export PATH=$PATH:$SCALA_HOME:$SCALA_HOME/bin

# Ruby - rbenv
#export PATH="$HOME/.rbenv/bin:$PATH"
#eval "$(rbenv init -)"

export PATH=/home/axel/.local/lib/python2.7/site-packages:$PATH
set -o clobber

