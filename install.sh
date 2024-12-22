#!/bin/sh

# if -f option is passed, force symlink
if [ "$1" = "-f" ]; then
  LN_OPTS="-f"
else
  LN_OPTS=""
fi

cd ~/.config

ln -s $LN_OPTS ../dotfiles/kitty/ kitty

ln -s $LN_OPTS ../dotfiles/atuin/ atuin

ln -s $LN_OPTS ../dotfiles/fish/ fish

ln -s $LN_OPTS ../dotfiles/helix/ helix

ln -s $LN_OPTS ../dotfiles/nvim/ nvim

mkdir direnv && ln -s $LN_OPTS ../dotfiles/direnv.toml direnv/direnv.toml

