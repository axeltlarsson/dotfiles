# Stuff I do with my Mac
### Homebrew (CLI apps)
* Install homebrew
```
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```
* Uninstall homebrew
```
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
```
* node.js
```
brew install node
```

* Install tree, useful for displaying directory tree, use the L option for depth:
```
brew install tree
```

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


* OSXFuse and SSHFS: simply download from http://osxfuse.github.io, brew does not behave well with OSXFuse


* [Docs](https://github.com/caskroom/homebrew-cask/blob/master/USAGE.md)

### zsh stuff
* Ctrl + R is pretty amazing

### Other stuff
* Make <code>subl</code> available in terminal: (check that /usr/local/bin is in path first: <code>echo $PATH</code>)
```
ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl
```



