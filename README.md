## Setup

- Install Nix with <https://github.com/DeterminateSystems/nix-installer>
- For home-manager setups: `build` and `switch`
- For NixOS (nixpi): `nixos-rebuild switch --flake '.#nixpi'`

## Performance tweaks

``` bash
nix run nixpkgs#hyperfine -- --warmup 3 'zsh -lic exit'
```

References:

- <https://carlosbecker.com/posts/speeding-up-zsh>
- <https://htr3n.github.io/2018/07/faster-zsh/>
- <https://blog.jonlu.ca/posts/speeding-up-zsh>
