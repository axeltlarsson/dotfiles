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
alias sshServer="ssh -p512 axel@192.168.0.199"
alias sshBackupserver="ssh axel@192.168.0.179"
alias wakeBackupserver="wakeonlan 00:23:54:37:4e:9e"
alias pp_json="python -m json.tool | pygmentize -l javascript"
export PATH=/usr/local/bin/activator:$PATH
alias act="activator"
alias gcc="gcc -pedantic -Wall -Werror -std=c11 -O3"

# set terminal title with this function
title() {
	echo -en "\e]2;$1\a"
}