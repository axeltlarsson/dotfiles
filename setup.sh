#!/bin/bash

#----------------- utils ----------------
usage()
{
cat << EOF
usage: [-m]

Setups zsh with the prezto configuration framework: symlinks files from the "dotfiles" folder.

FLAG:
    -m Only symlink files in the "miscellaneous" folder that require root access.
EOF
}

SYMLINK_MISC=false
while getopts "h:m" OPTION
do
    case $OPTION in
        h)
            usage
            exit 1
            ;;
        m)
            SYMLINK_MISC=true
            ;;

        ?)
            usage
            exit
            ;;
    esac
done

answer_is_yes() {
    [[ "$REPLY" =~ ^[Yy]$ ]] \
        && return 0 \
        || return 1
}

ask() {
    print_question "$1"
    read
}

ask_for_confirmation() {
    print_question "$1 (y/n) "
    read -n 1
    printf "\n"
}

cmd_exists() {
    [ -x "$(command -v "$1")" ] \
        && printf 0 \
        || printf 1
}

execute() {
    $1 &> /dev/null
    print_result $? "${2:-$1}"
}

get_answer() {
    printf "$REPLY"
}

print_error() {
    # Print output in red
    printf "\e[0;31m  [✖] $1 $2\e[0m\n"
}

print_info() {
    # Print output in purple
    printf "\n\e[0;35m $1\e[0m\n\n"
}

print_question() {
    # Print output in yellow
    printf "\e[0;33m  [?] $1\e[0m"
}

print_result() {
    [ $1 -eq 0 ] \
        && print_success "$2" \
        || print_error "$2"

    [ "$3" == "true" ] && [ $1 -ne 0 ] \
        && exit
}

print_success() {
    # Print output in green
    printf "\e[0;32m  [✔] $1\e[0m\n"
}

ask_for_sudo() {

    # Ask for the administrator password upfront
    sudo -v

    # Update existing `sudo` time stamp until this script has finished
    # https://gist.github.com/cowboy/3118588
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done &> /dev/null &

}

install_zsh () {
# Test to see if zshell is installed.  If it is:
if [ -f /bin/zsh -o -f /usr/bin/zsh ]; then
    # Set the default shell to zsh if it isn't currently set to zsh
    if [[ ! $(echo $SHELL) == $(which zsh) ]]; then
    	print_info "Setting default shell to zsh, please enter your password"
        chsh -s $(which zsh)
        print_success "zsh is now your shell"
    elif [[ $(echo $SHELL) == $(which zsh) ]]; then
        print_info "zsh is already your shell"
    fi
else
    # If zsh isn't installed, get the platform of the current machine
    platform=$(uname);
    # If the platform is Linux, try an apt-get to install zsh and then recurse
    if [[ $platform == 'Linux' ]]; then
    	print_info "Installing zsh..."
        sudo apt-get install zsh
        install_zsh
    # If the platform is OS X, tell the user to install zsh :)
    elif [[ $platform == 'Darwin' ]]; then
        print_error "Please install zsh, then re-run this script!"
        exit
    fi
fi
}

# Performs symlink() on each of the files in the dotfiles dir
symlink_dotfiles() {
    declare -a dotfiles=$(find  dotfiles -type f -not -name README.md)
    local target=$1
    local file=""
    local sourceFile=""
    local targetFile=""

    for file in ${dotfiles[@]}; do

        sourceFile="$(pwd)/$file"
        targetFile="$target/$(printf "%s" "$file" | sed "s/.*\/\(.*\)/\1/g")"
    
        symlink "$sourceFile" "$targetFile"

    done

}

# Basically does ln -fs $sourceFile $targetFile with some fancy cli graphics
symlink() {
    sourceFile=$1
    targetFile=$2
    if [ -e "$targetFile" ]; then
        if [ "$(readlink "$targetFile")" != "$sourceFile" ]; then
            ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"
            if answer_is_yes; then
                rm -rf "$targetFile"
                execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
            else
                print_error "$targetFile → $sourceFile"
            fi

        else
            print_success "$targetFile → $sourceFile"
        fi
    else
        execute 'ln -fs $sourceFile $targetFile' "$targetFile → $sourceFile"
    fi

}






# Symlinks the files in the "miscellaneous" dir to their corresponding locations
# Does the symlinking with sudo since this is required in most cases
symlink_misc() {
    declare -a files=$(find miscellaneous -type f -not -name README.md)
    
    for i in ${files[@]}; do
        sourceFile=$(readlink -f "$i")
        targetFile="/${i#miscellaneous/}"
        ask_for_confirmation "Do you want to symlink $targetFile → $sourceFile?"
        if answer_is_yes; then
            symlink "$sourceFile" "$targetFile"
        fi
    done


}

#----------------- actual stuff happening ----------------
if ($SYMLINK_MISC); then
    if [[ $EUID -ne 0 ]]; then
        print_error "WARNING! No root access! The script may fail to symlink some files in this mode."
    fi
    symlink_misc
else
    install_zsh
    symlink_dotfiles $HOME


    ask_for_confirmation "Do you want to install powerline fonts?"
    if answer_is_yes; then
        execute "./fonts/install.sh" "powerline fonts installed"
    fi

    ask_for_confirmation "Do you want to install gnome-terminal-colors-solarized, dark theme?"
    if answer_is_yes; then
        print_info "Installing prerequisites for gnome-terminal-colors-solarized"
        sudo apt-get install dconf-cli
        ./gnome-terminal-colors-solarized/set_dark.sh
    fi
    zsh
fi


exit 0