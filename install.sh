#!/usr/bin/env bash

set -e

DOTFILES="$HOME/dotfiles"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

echo "==> Installing Homebrew packages"

brew install stow
brew install bat
brew install nvm

echo "==> Installing Oh My Zsh plugins/themes"

# powerlevel10k
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
  git clone --depth=1 \
    https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  git clone \
    https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  git clone \
    https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# you-should-use
if [ ! -d "$ZSH_CUSTOM/plugins/you-should-use" ]; then
  git clone \
    https://github.com/MichaelAquilina/zsh-you-should-use.git \
    "$ZSH_CUSTOM/plugins/you-should-use"
fi

echo "==> Creating symlinks with stow"

cd "$DOTFILES"

stow zsh

echo "==> Done"
