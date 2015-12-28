#!/bin/bash
answer_is_yes() {
    [[ "$REPLY" =~ ^[Yy]$ ]] \
        && return 0 \
        || return 1
}

# ask $1
ask() {
    print_question "${1}"
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
    e_msg=$($1 2>&1)
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

# Basically does ln -fs $realFile $symFile with some fancy cli graphics
symlink() {
    local realFile=$1
    local symFile=$2
    if [ -e "${symFile}" ]; then
        if [ "$(readlink "${symFile}")" != "${realFile}" ]; then
            ask_for_confirmation "'${symFile}' already exists, do you want to overwrite it?"
            if answer_is_yes; then
                rm -rf "${symFile}"
                execute "ln -fs ${realFile} ${symFile}" "${symFile} → ${realFile}"
            else
                print_error "${symFile} → ${realFile}"
            fi

        else
            print_success "${symFile} → ${realFile}"
        fi
    else
        execute "ln -fs ${realFile} ${symFile}" "${symFile} → ${realFile}"
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

# Install the package given by $1 as long as it is available via apt and user accepts
install_conditional() {
    if not_installed ${1}; then
        ask_for_confirmation "Do you want to install ${1}?"
        if answer_is_yes; then
            execute "apt install -qq ${1}"
        fi
    fi
}

# Symlinks the files in the $1 directory to their respective locations
# as given by their directory structure. Optional: prepend ($HOME) with $2
# Ex: "symlink_files dir" with "dir" containing "dir/subdir/subsubdir/file"
# will do "symlink dir/subdir/subsubdir/file /subdir/subsubdir/file"
# NOTE! This function does not support any paths with spaces in them!
symlink_dir() {
    declare -a files=($(find $1 -type f -not -iname '*.md'))
    for file in "${files[@]}"; do
        realFile=$(readlink -f "${file}")
        symFile="${2}/${file#$1/}"
        symlink ${realFile} ${symFile}
    done
}

# Like symlink_dir() but using copy() instead
copy_dir() {
    declare -a files=($(find $1 -type f -not -iname '*.md'))

    for file in "${files[@]}"; do
        sourceFile=$(readlink -f "${file}")
        targetFile="${2}/${file#$1/}"
        copy ${sourceFile} ${targetFile}
    done
}

# Returns true if package-name given by $1 is not installed
not_installed() {
    pkg=$1
    if dpkg --get-selections | grep -q "^$pkg[[:space:]]*install$" >/dev/null; then
        return 1
    else
        return 0
    fi
}

install_powerline_fonts() {
    if ls $HOME/.fonts 2> /dev/null | grep -q Powerline.ttf ; then
        return
    else
        execute "./fonts/install.sh" "powerline fonts installed"
    fi
}

install_solarized() {
    if not_installed dconf-cli; then        
        print_info "Installing prerequisites for gnome-terminal-colors-solarized"
        apt install dconf-cli
        ./gnome-terminal-colors-solarized/set_dark.sh
        print_info "Do not forget to change the font in the terminal"
    fi
}

setup_sublime_text_3() {
    if not_installed sublime-text-installer; then
        print_info "Installing Sublime Text 3"
        apt add-repository ppa:webupd8team/sublime-text-3 > /dev/null 2>&1
        execute "apt update -qq"
        execute "apt install -qq sublime-text-installer"
        print_info "Please install package control"
        xdg-open "https://packagecontrol.io/installation"
        subl

        ask_for_confirmation "Have you installed Package Control?"
        if answer_is_yes; then
            print_info "Restart Sublime and allow Package Control some time to satisfy dependencies, you may have to change the color theme manually to AfterGlow."
            symlink /opt/sublime_text/sublime_text /usr/local/bin/subl
        fi
    fi
    mkdir -p $HOME/.config/sublime-text-3/Packages/User
    symlink $(readlink -f Sublime) $HOME/.config/sublime-text-3/Packages/User
}

setup_haskell() {
    print_info "Installing ghc-7.10.3 and cabal-install-1.22"
    # ghc and cabal
    execute "apt add-repository -y ppa:hvr/ghc > /dev/null 2>&1"
    execute "apt update -qq"
    execute "apt install -y -qq cabal-install-1.22 ghc-7.10.3"
    # deps for SublimeHaskell

}


# Always set up zsh + prezto
install_zsh
print_info "Setting up prezto configuration framework"
symlink_dir prezto $HOME

#---------- Show menu with tasks --------------------
print_info "Loading setup menu..."
sleep 2 # to give user a chance to see that previous task completed successfully
while :
do
    clear
    cat<<EOF
===============================================
    .dotfiles setup                             
-----------------------------------------------
    Common setup tasks:

    (1) Desktop setup       
        - Sublime, Fonts, Solarized theme,
          symlinking desktop, tree, etc
    
    (2) Haskell dev environment
        - ghc, cabal, hsdev etc
    

    (3) List more possibilities
    
    (q) Quit
-----------------------------------------------
EOF
    read -n1 -s
    case "$REPLY" in
    "1")
        setup_sublime_text_3
        
        install_powerline_fonts
        install_solarized

        ask_for_confirmation "Do you want to symlink files from \"desktop\"?"
        if answer_is_yes; then
            symlink_dir desktop
            git config --global core.excludesfile $HOME/.gitignore_global
        fi

        install_conditional tree
        install_conditional keepassx
    ;;

    "2")  setup_haskell             ;;
    "3")  submenu                   ;;
    "q")  exit                      ;;
     * )  echo "invalid option"     ;;
    esac
    sleep 1
done

# List more possibilities in a sub menu
submenu() {
while :
do
    clear
    cat<<EOF
===============================================
    .dotfiles setup                             
-----------------------------------------------
    All available tasks, dependencies in ():

    (1) Sublime Text 3 (fonts)

    (2) gnome-terminal-solarized (fonts)

    (3) Javascript dev environment
        - node, jspm, jshint etc

    (4) Symlink files from "desktop"

    (5) Symlink files from "Kodi-Rpi2"

    (6) Symlink files from "Backupservern"

    (7) Copy files from "Ubuntuservern"
    
    (*) Return to main menu
-----------------------------------------------
EOF
    read -n1 -s
    case "$REPLY" in
        "1")
            install_sublime_text_3
            mkdir -p $HOME/.config/sublime-text-3/Packages/User
            symlink $(readlink -f Sublime) $HOME/.config/sublime-text-3/Packages/User

            install_powerline_fonts
        ;;

        "2")
            install_solarized
        ;;

        "3") echo "not yet implemented!" ;;
        "4")
            symlink_dir desktop
            git config --global core.excludesfile $HOME/.gitignore_global 
        ;;

        "5") symlink_dir Kodi-Rpi2              ;;
        "6") symlink_dir Backupservern $HOME    ;;
        "7") copy_dir Ubuntuservern             ;;
         * ) return
    esac
    sleep 1
done
