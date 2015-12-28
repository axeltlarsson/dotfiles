#!/bin/bash
echo "() setting up zsh"

show_all() {
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
        "1") echo "Setting up zsh" ;;
        "2") echo "JS dev env"  ;;
         * ) return
    esac
    sleep 1
done
}

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
    "1")  echo "install sublime" ;;
    "2")  echo "you chose choice 2" ;;
    "3")  show_all ;;
    "q")  exit                      ;; 
     * )  echo "invalid option"     ;;
    esac
    sleep 1
done