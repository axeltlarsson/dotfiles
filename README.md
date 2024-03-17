## Setup

- Install Nix with <https://github.com/DeterminateSystems/nix-installer>
- For home-manager setups: `build` and `switch`
- For NixOS (nixpi): `nixos-rebuild switch --flake '.#nixpi'`

## Performance tweaks

``` bash
for i in $(seq 1 10); do /usr/bin/time $SHELL -i -c exit; done
```

References:

- <https://carlosbecker.com/posts/speeding-up-zsh>
- <https://htr3n.github.io/2018/07/faster-zsh/>
- <https://blog.jonlu.ca/posts/speeding-up-zsh>
