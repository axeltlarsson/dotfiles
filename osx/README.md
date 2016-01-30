## Setup homebrew
  ```
  # Installing homebrew
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  
  # (Uninstall)
  #ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
  
  # Install a bunch of useful tools/apps
  brew install \
  git \                               # replace default git with newer, more secure, homebrew managed git
  tree \
  scala \
  sbt \
  typesafe-activator \
  node \
  httpie \
  wakeonlan \
  install caskroom/cask/brew-cask    # see: https://github.com/caskroom/homebrew-cask
  
  brew tap caskroom/versions          # enable alternate versions of apps (i.e. sublime-text3)
  brew cask install \
  sublime-text3 \
  tunnelblick \                       # OpenVPN client
  java \
  macpass
 ```
  
  
## Check that git is the newest version
  
  ```
  git --version
  ```
  If the last command does not show git version at least 2.4.5 then we need to also fix the path
  
  ```
  echo $PATH
  ```
  
  If /usr/bin is before /usr/local/bin which is where homebrew installs, then the default git will still prevail.
  Either change the order of the paths in $PATH:
  
  ```
  export PATH=/usr/local/git/bin/:$PATH
  ```
  
  or replace the old git:
  
  ```
  sudo mv /usr/bin/git /usr/bin/git-original
  sudo ln -s /usr/local/bin/git /usr/bin/git
  ```
  
  Now <code>git</code> will be the homebrew managed git and <code>git-original</code> will be the old Apple-shipped version.

## OSXFuse and SSHFS
Simply download from http://osxfuse.github.io, brew does not behave well with OSXFuse

## subl
* Make <code>subl</code> available in terminal: (check that /usr/local/bin is in path first: <code>echo $PATH</code>)

  ```
  ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl
  ```
  
## [httpie](http://radek.io/2015/10/20/httpie/)
