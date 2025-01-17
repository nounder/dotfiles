#!/bin/sh

# if -f option is passed, force symlink
if [ "$1" = "-f" ]; then
  LN_OPTS="-f"
else
  LN_OPTS=""
fi

mkdir -p ~/.config

cd ~/.config

ln -s $LN_OPTS ../dotfiles/kitty/ kitty

ln -s $LN_OPTS ../dotfiles/atuin/ atuin

ln -s $LN_OPTS ../dotfiles/fish/ fish

ln -s $LN_OPTS ../dotfiles/helix/ helix

ln -s $LN_OPTS ../dotfiles/nvim/ nvim

ln -s $LN_OPTS ../dotfiles/ghostty/ ghostty

ln -s $LN_OPTS ../dotfiles/tmux.conf .tmux.conf

mkdir -p direnv; ln -s $LN_OPTS ../../dotfiles/direnv.toml direnv/direnv.toml

