## Setup homebrew
  ```
  # Installing homebrew
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  ```
* Uninstall homebrew:

  ```
  
  ```
  

* node.js:

  ```
  brew install node
  ```

* Install tree, useful for displaying directory tree, use the L option for depth:

  ```
  brew install tree
  ```

* Install Scala:

  ```
  brew install scala
  ```

* Install sbt:

  ```
  brew install sbt
  ```

* Replace default git with newer, more secure, homebrew managed git:
  
  ```
  brew install git
  zsh # the change does not take effect until next session
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


## Homebrew-cask (GUI apps)
* Install

  ```
  brew install caskroom/cask/brew-cask
  ```
* Installing gui apps with cask:

  ```
  brew cask install iterm2
  ```
* Installing alternative versions, i.e. Sublime Text 3 and not 2:

  ```
  brew tap caskroom/versions
  brew cask install sublime-text3
  ```

* OpenVPN client TunnelBlick:

  ```
  brew cask install tunnelblick
  ```
  
* Java, latest version, needed for Activator
  ```
  brew cask install java
  ```
  
* Typesafe Activator
  ```
  brew install typesafe activator
  ```


* OSXFuse and SSHFS: simply download from http://osxfuse.github.io, brew does not behave well with OSXFuse


* [Docs](https://github.com/caskroom/homebrew-cask/blob/master/USAGE.md)

### zsh stuff
* Ctrl + R is pretty amazing

### Other stuff
* Make <code>subl</code> available in terminal: (check that /usr/local/bin is in path first: <code>echo $PATH</code>)

  ```
  ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl
  ```



