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
        print_success "After a relogin, zsh should be your default shell!"
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
    if ls $HOME/.fonts 2> /dev/null | grep -q Powerline.ttf ; then
        return
    else
        ask_for_confirmation "Do you want to install powerline fonts?"
        if answer_is_yes; then
            execute "./fonts/install.sh" "powerline fonts installed"
        fi
    fi
}

install_solarized() {
    if installed dconf-cli; then
        ask_for_confirmation "Do you want to install gnome-terminal-colors-solarized, dark theme?"
        if answer_is_yes; then
            print_info "Installing prerequisites for gnome-terminal-colors-solarized"
            sudo apt-get install dconf-cli
            ./gnome-terminal-colors-solarized/set_dark.sh
        fi
    fi
}

install_sublime_text_3() {
    if installed sublime-text-installer; then
        ask_for_confirmation "Do you want to install Sublime Text 3?"
        if answer_is_yes; then
            sudo add-apt-repository ppa:webupd8team/sublime-text-3 # not using execute_su here since I want the output
            execute_su apt-get update
            execute_su apt-get install sublime-text-installer
            symlink /opt/sublime_text/sublime_text /usr/local/bin/subl
            print_info "Do not forget to install Package Control and the Afterglow theme in subl"
        fi
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
                execute "cp --preserve $sourceFile $targetFile" "$targetFile → $sourceFile"
            else
                print_error "$targetFile → $sourceFile"
            fi

        else
            print_success "$targetFile → $sourceFile"
        fi
    else
        execute "cp --preserve $sourceFile $targetFile" "$targetFile → $sourceFile"
    fi
}

# Symlinks the files in the $1 directory to their respective locations
# as given by their directory structure. Optional: prepend ($HOME) with $2
# Ex: "symlink_files dir" with "dir" containing "dir/subdir/subsubdir/file"
# will do "symlink dir/subdir/subsubdir/file /subdir/subsubdir/file"
symlink_dir() {
    OLDIFS=$IFS
    IFS=$'\n'
    declare -a files=($(find $1 -type f -not -iname '*.md'))

    for file in "${files[@]}"; do
        sourceFile=$(readlink -f "${file}")
        targetFile="${2}/${file#$1/}"
        symlink ${sourceFile} ${targetFile}
    done
    IFS=$OLDIFS
}

# Like symlink_dir() but using copy() instead
copy_dir() {
    OLDIFS=$IFS
    IFS=$'\n'
    declare -a files=($(find $1 -type f -not -iname '*.md'))

    for file in "${files[@]}"; do
        sourceFile=$(readlink -f "${file}")
        targetFile="${2}/${file#$1/}"
        copy ${sourceFile} ${targetFile}
    done
    IFS=$OLDIFS
}



# Returns true if package-name given by  $1 is installed
installed() {
   pkg=$1
   if dpkg --get-selections | grep -q "^$pkg[[:space:]]*install$" >/dev/null; then
	return 1
   else
        return 0
  fi
}

#----------------- actual stuff happening ----------------
install_zsh
print_info "Setting up prezto configuration framework"
symlink_dir prezto $HOME

ask_for_confirmation "Do you want to symlink files from \"desktop\"?"
if answer_is_yes; then
    symlink_dir desktop
    git config --global core.excludesfile $HOME/.gitignore_global
fi

# Doing copy for Ubuntuservern because /home/axel is likely encrypted
ask_for_confirmation "Do you want to copy files from \"Ubuntuservern\"?"
if answer_is_yes; then
    copy_dir Ubuntuservern
fi

ask_for_confirmation "Do you want to symlink files from \"Backupservern\"?"
if answer_is_yes; then
    symlink_dir Backupservern $HOME
fi

ask_for_confirmation "Do you want to symlink files from \"Kodi-Rpi2\"?"
if answer_is_yes; then
    symlink_dir Kodi-Rpi2
fi

install_powerline_fonts
install_solarized
install_sublime_text_3
zsh
exit 0
