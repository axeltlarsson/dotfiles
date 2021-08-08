## Setup

Install Nix, Home Manager.

```sh
git clone https://github.com/AxelTLarsson/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
home-manager -j 16 switch
```

## Performance tweaks

```bash
for i in $(seq 1 10); do /usr/bin/time $SHELL -i -c exit; done
```

References:

- https://carlosbecker.com/posts/speeding-up-zsh
- https://htr3n.github.io/2018/07/faster-zsh/
- https://blog.jonlu.ca/posts/speeding-up-zsh

