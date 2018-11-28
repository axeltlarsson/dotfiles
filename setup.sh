#!/bin/bash

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

is_linux () {
  case `uname` in
    Linux)
      true
      ;;
    *)
      false
      ;;
  esac
}

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
      execute "chsh -s $(which zsh)"
    elif [[ $(echo $SHELL) == $(which zsh) ]]; then
      print_info "zsh is already your shell"
    fi
  else
    # If the platform is Linux, try an apt-get to install zsh and then recurse
    if is_linux; then
      print_info "Installing zsh..."
      sudo apt-get install zsh
      install_zsh
    elif is_mac; then
      brew install zsh
      exit
    fi
  fi
}

# Basically does ln -fs $realFile $symFile with some fancy cli graphics
symlink() {
  local realFile=$1
  local symFile=$2
  if [ -e "${symFile}" ]; then
    if [ "$(fullpath "${symFile}")" != "${realFile}" ]; then
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
# NOTE! No support for spaces in filenames
copy() {
  local sourceFile="$1"
  local targetFile="$2"
  if [ -e "$targetFile" ]; then
    if [ "$(fullpath "$targetFile")" != "$sourceFile" ]; then
      ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"
      if answer_is_yes; then
        rm -rf "$targetFile"
        execute 'cp --preserve "$sourceFile" "$targetFile"' '"$targetFile" → "$sourceFile"'
      else
        print_error "$targetFile → $sourceFile"
      fi

    else
      print_success "$targetFile → $sourceFile"
    fi
  else
    execute 'cp --preserve "$sourceFile" "$targetFile"'
  fi
}

# Install the package given by $1 as long as it is available via apt and user accepts
install_conditional() {
  if not_installed ${1}; then
    ask_for_confirmation "Do you want to install ${1}?"
    if answer_is_yes; then
      if is_linux; then
        execute_su "apt-get --assume-yes install -qq ${1}"
      elif is_mac; then
        brew install $1
      fi
    fi
  fi
}

# Symlinks the files in the $1 directory to their respective locations
# as given by their directory structure. Optional: prepend ($HOME) with $2
# Ex: "symlink_files dir" with "dir" containing "dir/subdir/subsubdir/file"
# will do "symlink dir/subdir/subsubdir/file /subdir/subsubdir/file"
# NOTE! This function does not support any paths with spaces in them or rather symlink doesnt!
symlink_files_in_dir() {
  declare -a files
  while IFS= read -r -d '' n; do
    files+=( "$n" )
  done < <(find $1 -type f -not -iname '*.md' -print0)

  for file in "${files[@]}"; do
    realFile=$(fullpath "${file}")
    symFile="${2}/${file#$1/}"
    symlink "${realFile}" "${symFile}"
  done
}


# Returns true if package-name given by $1 is not installed
not_installed() {
  pkg=$1
  if is_linux; then
    if dpkg --get-selections | grep -q "^$pkg[[:space:]]*install$" >/dev/null; then
      return 1
    else
      return 0
    fi
  elif is_mac; then
    if brew ls --versions $1 > /dev/null; then
      false # because not_installed
    else
      true
    fi
  fi
}

fullpath() {
  dirname=`perl -e 'use Cwd "abs_path";print abs_path(shift)' "$1"`
  echo "$dirname"
}

install_powerline_fonts() {
  if ls $HOME/.fonts 2> /dev/null | grep -q Powerline.ttf ; then
    return
  else
    execute "./fonts/install.sh" "powerline fonts installed"
  fi
}

install_neovim() {
  if not_installed neovim; then
    print_info "Installing neovim..."
    platform=$(uname);
    if is_linux; then
      sudo apt-get install python-dev python-pip python3-dev python3-pip && \
        sudo apt-get install software-properties-common && \
        sudo add-apt-repository ppa:neovim-ppa/stable && \
        sudo apt-get update && \
        sudo apt-get install neovim && \
        sudo pip3 install neovim && \
        sudo pip2 install neovim
    elif is_mac; then
      brew install neovim
    fi
  fi
}

# Always set up zsh + prezto and vim w. Vundle plugins
install_zsh
print_info "Setting up prezto configuration framework"
symlink_files_in_dir dotfiles "$HOME"
install_neovim
execute "mkdir -p $HOME/.config/nvim"
symlink "$(fullpath dotfiles/.vimrc)" "$HOME/.config/nvim/init.vim"
symlink "$(fullpath .vim)" "$HOME/.vim"
execute "mkdir -p $HOME/.config/pgcli"
symlink "$(fullpath .config/pgcli/config)" "$HOME/.config/pgcli/config"
nvim +PluginInstall +qall

if is_linux; then
  install_conditional ripgrep
elif is_mac; then
  install_conditional ripgrep
fi
print_info "Do not forget to run :CheckHealth in neovim"

execute "mkdir -p ${HOME}/.npm-packages"
git config --global core.excludesfile "$HOME/.gitignore_global"
sleep 2

#---------- Show menu with tasks --------------------
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

    (1) Symlink files from "desktop"

    (*) Return to main menu
-----------------------------------------------
EOF
    read -n1 -s
    case "$REPLY" in
        "1")
            symlink_files_in_dir desktop
            git config --global core.excludesfile $HOME/.gitignore_global
        ;;

        * ) return
    esac
    sleep 1
done
}


print_info "Loading setup menu..."
sleep 1 # to give user a chance to see that previous task completed successfully
while :
do
    clear
    cat<<EOF
===============================================
    .dotfiles setup
-----------------------------------------------
    Common setup tasks:

    (1) Desktop setup
        - install mosh
        - take control of /usr/local/bin
        - powerline_fonts
        - symlink files from "desktop"
        - You will be asked if you want:
          * httpie
          * tree
          * wakeonlan
          * keepassx
          * openssh-server
          * transmission-cli
          * build-essential
    (2) List more possibilities

    (q) Quit
-----------------------------------------------
EOF
    read -n1 -s
    case "$REPLY" in
    "1")
        execute_su "apt-get --assume-yes install -qq mosh"
        execute_su "chown -R $USER /usr/local/bin"

        ask_for_confirmation "Do you want to install powerline fonts?"
        if answer_is_yes; then
            install_powerline_fonts
        fi

        ask_for_confirmation "Do you want to symlink files from \"desktop\"?"
        if answer_is_yes; then
            symlink_files_in_dir desktop
        fi

        install_conditional httpie
        install_conditional tree
        install_conditional wakeonlan
        install_conditional keepassx
        install_conditional openssh-server
        install_conditional transmission-cli
        install_conditional build-essential

    ;;

    "2")  submenu                   ;;
    "q")
        zsh
        exit                        ;;
     * )  echo "invalid option"     ;;
    esac
    sleep 1
done

