# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

Enter the dev shell first: `nix develop`

- `build` - Build darwin configuration without switching (uses `nh darwin build` for nicer output)
- `switch` - Build and activate darwin configuration (uses `nh darwin switch`)
- `update` - Update flake inputs and commit lock file
- `ci` - Run linters (lua-language-server for nvim config, nixfmt for nix files)
- `nvim-local` - Test neovim config changes without switching

For NixOS (nixpi): `nixos-rebuild switch --flake '.#nixpi'`

## Architecture

This is a Nix flake managing dotfiles across multiple machines:

- **flake.nix** - Entry point defining all system configurations
- **darwin/** - nix-darwin (macOS) system configurations
  - `configuration.nix` - Shared darwin settings
  - `axel_mbp14.nix`, `axel_mbp14_ja.nix` - Machine-specific home-manager imports
  - `mbp.nix` - Additional darwin settings
- **config/** - Home-manager modules (shared across machines)
  - `home.nix` - Common packages and imports all other modules
  - Individual modules: `zsh.nix`, `tmux.nix`, `git.nix`, `ssh.nix`, `ghostty.nix`, `fzf.nix`, `alacritty.nix`
  - `nvim/` - Neovim configuration (Lua)
- **nixpi/** - NixOS configuration for Raspberry Pi
- **andrimner/** - Home-manager config for Linux server
- **overlays/** - Nixpkgs overlays

## Conventions

- Nix formatting: `nixfmt-rfc-style`
- Commit messages: emoji prefix + imperative description (e.g., "🐛 Fix touchIdAuth in tmux")
