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

# Customize to your needs...
alias sshServer="ssh -p512 axel@192.168.0.199"
alias sshBackupserver="ssh axel@192.168.0.179"
alias wakeBackupserver="wakeonlan 00:23:54:37:4e:9e"
alias pp_json="python -m json.tool | pygmentize -l javascript"
alias dotfiles="cd /home/axel/.zprezto/"
alias act="activator"
