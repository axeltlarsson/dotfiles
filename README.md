## Setup
```shell
sudo apt-add-repository -y ppa:git-core/ppa && \
apt update && \
apt install -y git

git clone --recursive https://github.com/AxelTLarsson/dotfiles.git .zprezto
cd .zprezto
./setup.sh
```

iTerm2 theme: [https://github.com/sindresorhus/iterm2-snazzy](https://github.com/sindresorhus/iterm2-snazzy)

## Performance tweaks

```bash
for i in $(seq 1 10); do /usr/bin/time $SHELL -i -c exit; done
```

References:
- https://carlosbecker.com/posts/speeding-up-zsh
- https://htr3n.github.io/2018/07/faster-zsh/
- https://blog.jonlu.ca/posts/speeding-up-zsh


## Prezto information
This dotfiles repo uses zsh and prezto as a configuration framework.

Prezto is the configuration framework for zsh; it enriches the command line
interface environment with sane defaults, aliases, functions, auto completion,
and prompt themes.
=======
### Troubleshooting

If you are not able to find certain commands after switching to *Prezto*,
modify the `PATH` variable in *~/.zprofile* then open a new Zsh terminal
window or tab.

Updating
--------

Run `zprezto-update` to automatically check if there is an update to zprezto.
If there are no file conflicts, zprezto and its submodules will be
automatically updated. If there are conflicts you will instructed to go into
the `$ZPREZTODIR` directory and resolve them yourself.

To pull the latest changes and update submodules manually:

```console
cd $ZPREZTODIR
git pull
git submodule update --init --recursive
```

Usage
-----

Prezto has many features disabled by default. Read the source code and
accompanying README files to learn of what is available.

### Modules

  1. Browse */modules* to see what is available.
  2. Load the modules you need in *~/.zpreztorc* then open a new Zsh terminal
     window or tab.

### Themes

  1. For a list of themes, type `prompt -l`.
  2. To preview a theme, type `prompt -p name`.
  3. Load the theme you like in *~/.zpreztorc* then open a new Zsh terminal
     window or tab.

License
-------

This project is licensed under the MIT License.

[1]: http://www.zsh.org
[2]: http://i.imgur.com/nrGV6pg.png "sorin theme"
[3]: http://git-scm.com
[4]: https://github.com
[5]: http://gitimmersion.com
[6]: http://gitref.org
[7]: http://www.bash2zsh.com/zsh_refcard/refcard.pdf
[8]: http://grml.org/zsh/zsh-lovers.html
