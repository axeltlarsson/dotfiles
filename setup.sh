#!/bin/bash

#----------------- Variables ----------------
source functions
install_zsh () {
# Test to see if zshell is installed.  If it is:
if [ -f /bin/zsh -o -f /usr/bin/zsh ]; then
    # Set the default shell to zsh if it isn't currently set to zsh
    if [[ ! $(echo $SHELL) == $(which zsh) ]]; then
    	print_info "Setting default shell to zsh, please enter your password"
        chsh -s $(which zsh)
        if [[ $(echo $SHELL) == $(which zsh) ]]; then
            print_success "zsh is now your shell"
        fi
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

install_zsh

