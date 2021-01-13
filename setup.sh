#!/bin/bash

# usage: if is_mac; then ... else ... fi // do not use [[ is_mac ]] !!!
function is_mac {
  [[ "$OSTYPE" == darwin* ]]
}

function is_linux {
  [[ "$OSTYPE" == linux* ]]
}

answer_is_yes() {
  [[ "$REPLY" =~ ^[Yy]$ ]] \
    && return 0 \
    || return 1
}

ask_for_confirmation() {
  print_question "$1 (y/n) "
  read -n 1
  printf "\n"
}

execute() {
  e_msg=$($1 2>&1)
  code=$?
  print_result $code "${2:-$1} \t\t$e_msg" # ${2:-$1} prints $2 or if not given, $1
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
  if is_mac; then
    zsh_path=/usr/local/bin/zsh
    # Idempotently add /usr/local/bin/zsh to /etc/shells
    grep -qxF '/usr/local/bin/zsh' /etc/shells \
      || (print_info "/usr/local/bin/zsh >> /etc/shells" \
      && sudo sh -c 'echo "/usr/local/bin/zsh" >> /etc/shells')
  elif is_linux; then
    zsh_path=/usr/local/bin/zsh
  fi

  if [ ! -x $zsh_path ]; then
    # Install and recurse
    if is_mac; then
      brew install zsh
    elif is_linux; then
      execute_su "apt-get --assume-yes install -qq zsh"
    fi
    install_zsh
  elif [[ ! "$SHELL" == "$zsh_path" ]]; then
    # Set default shell
    print_info "Setting default shell to zsh, please enter your password"
    execute "chsh -s /usr/local/bin/zsh"
  fi

}

# Basically does ln -fs $sourceFile $targetFile with some fancy cli graphics
symlink() {
  local sourceFile=$1
  local targetFile=$2
  if [ -e "${targetFile}" ]; then
    if [ "$(fullpath "${targetFile}")" != "${sourceFile}" ]; then
      ask_for_confirmation "'${targetFile}' already exists, do you want to overwrite it?"
      if answer_is_yes; then
        rm -rf "${targetFile}"
        execute "ln -fs ${sourceFile} ${targetFile}" "${targetFile} → ${sourceFile}"
      else
        print_error "${targetFile} → ${sourceFile}"
      fi

    else
      print_success "${targetFile} → ${sourceFile}"
    fi
  else
    execute "ln -fs ${sourceFile} ${targetFile}" "${targetFile} → ${sourceFile}"
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
# as given by their directory structure with a dot prefix. Optional: prepend ($HOME) with $2
# Ex: "symlink_files dir" with "dir" containing "dir/subdir/subsubdir/file"
# will do "symlink dir/subdir/subsubdir/file /subdir/subsubdir/.file"
# NOTE! This function does not support any paths with spaces in them or rather symlink doesnt!
symlink_dotfiles_in_dir() {
  declare -a files
  while IFS= read -r -d '' n; do
    files+=( "$n" )
  done < <(find $1 -type f -not -iname '*.md' -print0)

  for file in "${files[@]}"; do
    sourceFile=$(fullpath "${file}")
    targetFile="${2}/.${file#$1/}"
    symlink "${sourceFile}" "${targetFile}"
  done
}


# Returns true if package-name given by $1 is not installed
not_installed() {
  pkg=$1
  if is_linux; then
    if dpkg --get-selections | grep -q "^${pkg[[:space:]]}*install$" >/dev/null; then
      return 1
    else
      return 0
    fi
  elif is_mac; then
    if brew ls --versions "$1" > /dev/null; then
      false # because not_installed
    else
      true
    fi
  fi
}

fullpath() {
  dirname=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' "$1")
  echo "$dirname"
}

install_neovim() {
  if not_installed neovim; then
    print_info "Installing neovim..."
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

# Always set up zsh + prezto and nvim w. with plugins
install_zsh
print_info "Setting up dotfiles"
symlink_dotfiles_in_dir dotfiles "$HOME"
install_neovim
execute "mkdir -p $HOME/.config/nvim"
symlink "$(fullpath config/nvim)" "$HOME/.config/nvim"

execute "mkdir -p $HOME/.config/pgcli"
symlink "$(fullpath config/pgcli/config)" "$HOME/.config/pgcli/config"

execute "mkdir -p $HOME/.config/alacritty"
symlink "$(fullpath config/alacritty)" "$HOME/.config/alacritty"

execute "mkdir -p ${HOME}/.npm-packages/lib"

execute "mkdir -p $HOME/.gnupg"
symlink "$(fullpath config/gpg-agent.conf)" "$HOME/.gnupg/gpg-agent.conf"

execute "touch $HOME/.local_envs"
execute "mkdir -p $HOME/notes"


# Other useful tooling
install_conditional ripgrep
