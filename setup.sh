#!/bin/bash
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
    e_msg=`$1 2>&1`
    code=$?
    print_result $code "${2:-$1} \n\t$e_msg" # ${2:-$1} prints $2 or if not given, $1
    # If fail: ask if user wants to try with su

    if [ $code -ne 0 ]; then
    	ask_for_confirmation "Try with sudo?"
    	if answer_is_yes; then
    		execute_su "$1" "$2"
		fi
    fi
}

execute_su() {
	export -f ask_for_confirmation
	export -f answer_is_yes
	export -f execute
	export -f print_error
	export -f print_success
	export -f print_result
	e_msg=`sudo ${1} 2>&1`
	print_result $? "${2:-$1} \n\t$e_msg" # ${2:-$1} prints $2 or if not given, $1
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

install_powerline_fonts() {
	ask_for_confirmation "Do you want to install powerline fonts?"
	if answer_is_yes; then
	    execute "./fonts/install.sh" "powerline fonts installed"
	fi
}

install_solarized() {
	ask_for_confirmation "Do you want to install gnome-terminal-colors-solarized, dark theme?"
	if answer_is_yes; then
	    print_info "Installing prerequisites for gnome-terminal-colors-solarized"
	    sudo apt-get install dconf-cli
	    ./gnome-terminal-colors-solarized/set_dark.sh
	fi
}

# Basically does ln -fs $sourceFile $targetFile with some fancy cli graphics
symlink() {
    local sourceFile=$1
    local targetFile=$2
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
        execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
    fi
}

# Basically does cp $sourceFile $targetFile with some fancy cli graphics
copy() {
    local sourceFile=$1
    local targetFile=$2
    if [ -e "$targetFile" ]; then
        if [ "$(readlink "$targetFile")" != "$sourceFile" ]; then
            ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"
            if answer_is_yes; then
                rm -rf "$targetFile"
                execute "cp $sourceFile $targetFile" "$targetFile → $sourceFile"
            else
                print_error "$targetFile → $sourceFile"
            fi

        else
            print_success "$targetFile → $sourceFile"
        fi
    else
        execute "cp $sourceFile $targetFile" "$targetFile → $sourceFile"
    fi
}

# Symlinks the files in the $1 directory to their respective locations
# as given by their directory structure. Optional: prepend ($HOME) with $2
# Ex: "symlink_files dir" with "dir" containing "dir/subdir/subsubdir/file"
# will do "symlink dir/subdir/subsubdir/file /subdir/subsubdir/file"
symlink_dir() {
    declare -a files=$(find $1 -type f -not -iname '*.md')
   
    for file in ${files[@]}; do
        sourceFile=$(readlink -f "$file")
        targetFile="$2/${file#$1/}"
        symlink $sourceFile $targetFile
    done
}

# Like symlink_dir() but using copy() instead
copy_dir() {
    declare -a files=$(find $1 -type f -not -iname '*.md')
   
    for file in ${files[@]}; do
        sourceFile=$(readlink -f "$file")
        targetFile="$2/${file#$1/}"
        copy $sourceFile $targetFile
    done
}

#----------------- actual stuff happening ----------------
install_zsh
print_info "Setting up prezto configuration framework"
symlink_dir prezto $HOME

ask_for_confirmation "Do you want to symlink files from \"desktop\"?"
if answer_is_yes; then
    symlink_dir desktop
fi

ask_for_confirmation "Do you want to symlink files from \"Kodi-Rpi2\"?"
if answer_is_yes; then
    symlink_dir Kodi-Rpi2
fi

ask_for_confirmation "Do you want to symlink files from \"Ubuntuservern\"?"
if answer_is_yes; then
    copy Ubuntuservern
fi

ask_for_confirmation "Do you want to symlink files from \"Backupervern\"?"
if answer_is_yes; then
    symlink_dir Backupservern $HOME
fi


install_powerline_fonts
install_solarized
zsh
exit 0
