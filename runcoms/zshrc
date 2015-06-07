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
# snatched from https://github.com/paulirish/dotfiles/blob/master/symlink-setup.sh

print_success() {
    # Print output in green
    printf "\e[0;32m  [✔] $1\e[0m\n"
}

print_error() {
    # Print output in red
    printf "\e[0;31m  [✖] $1 $2\e[0m\n"
}

execute() {
    $1 &> /dev/null
    print_result $? "${2:-$1}"
}

print_result() {
    [ $1 -eq 0 ] \
        && print_success "$2" \
        || print_error "$2"

    [ "$3" == "true" ] && [ $1 -ne 0 ] \
        && exit
}

mkd() {
    if [ -n "$1" ]; then
        if [ -e "$1" ]; then
            if [ ! -d "$1" ]; then
                print_error "$1 - a file with the same name already exists!"
            else
                print_success "$1"
            fi
        else
            execute "mkdir -p $1" "$1"
        fi
    fi
}

alias sshServer="ssh -p512 axel@192.168.0.199"
alias sshBackupserver="ssh axel@192.168.0.179"
alias wakeBackupserver="wakeonlan 00:23:54:37:4e:9e"

